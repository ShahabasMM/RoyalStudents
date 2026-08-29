import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const Color primary = Color(0xFF059669);
  static const Color primaryDark = Color(0xFF075B47);
  static const Color lightGreen = Color(0xFFE7F8F1);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF172033);
  static const Color textMuted = Color(0xFF64748B);

  StudentProfile? student;

  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> reservations = [];

  RealtimeChannel? _libraryChannel;

  bool loading = true;
  bool busy = false;

  String query = '';
  String category = 'All';
  String error = '';
  String success = '';

  int selectedTab = 0;

  @override
  void initState() {
    super.initState();

    _load();
    _setupRealtime();
  }

  // ============================================================
  // REALTIME
  //
  // The screen keeps the existing UI/data-loading logic.
  // Supabase only tells us that a library table changed;
  // then we reload the normal queries.
  // ============================================================

  void _setupRealtime() {
    final client = Supabase.instance.client;

    _libraryChannel = client.channel(
      'student-library-${DateTime.now().microsecondsSinceEpoch}',
    );

    _libraryChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_books',
          callback: (_) {
            if (!mounted) return;
            _loadRealtime();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_reservations',
          callback: (_) {
            if (!mounted) return;
            _loadRealtime();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'library_staff_loans',
          callback: (_) {
            if (!mounted) return;
            _loadRealtime();
          },
        )
        .subscribe();
  }

  Future<void> _loadRealtime() async {
    try {
      final s = student ?? await StudentDataService.currentStudent();

      final result = await Future.wait([
        StudentDataService.libraryBooks(),
        StudentDataService.myLibraryReservations(s),
      ]);

      if (!mounted) return;

      setState(() {
        student = s;
        books = List<Map<String, dynamic>>.from(result[0]);
        reservations = List<Map<String, dynamic>>.from(result[1]);
      });
    } catch (e) {
      // Do not replace the existing UI with a loading/error state
      // for a background realtime refresh.
      debugPrint(
        'LIBRARY REALTIME REFRESH ERROR: $e',
      );
    }
  }

  @override
  void dispose() {
    final channel = _libraryChannel;

    _libraryChannel = null;

    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final s = await StudentDataService.currentStudent();

      final result = await Future.wait([
        StudentDataService.libraryBooks(),
        StudentDataService.myLibraryReservations(s),
      ]);

      if (!mounted) return;

      setState(() {
        student = s;
        books = List<Map<String, dynamic>>.from(result[0]);
        reservations = List<Map<String, dynamic>>.from(result[1]);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('PostgrestException(message: ', '')
        .replaceFirst(RegExp(r', code:.*'), '')
        .replaceAll(RegExp(r'\)$'), '');
  }

  // ============================================================
  // ACTIVE STUDENT BOOK
  //
  // RESERVED + ISSUED count as one active book.
  // RETURNED does not count.
  // ============================================================

  List<Map<String, dynamic>> get activeMyBooks {
    return reservations.where((row) {
      final status =
          StudentDataService.value(row, ['status']).trim().toUpperCase();

      return status == 'RESERVED' || status == 'ISSUED';
    }).toList();
  }

  bool get hasActiveBook => activeMyBooks.isNotEmpty;

  int get activeBookCount => activeMyBooks.length;

  // ============================================================
  // BOOK ALREADY RESERVED / ISSUED
  // ============================================================

  bool _hasThisBook(String bookId) {
    return reservations.any((row) {
      final reservationBookId = '${row['book_id'] ?? ''}';

      final status =
          StudentDataService.value(row, ['status']).trim().toUpperCase();

      return reservationBookId == bookId &&
          (status == 'RESERVED' || status == 'ISSUED');
    });
  }

  // ============================================================
  // FILTERED BOOKS
  // ============================================================

  List<Map<String, dynamic>> get filteredBooks {
    final q = query.trim().toLowerCase();

    final result = books.where((book) {
      final title = StudentDataService.value(book, ['title']).toLowerCase();

      final author = StudentDataService.value(book, ['author']).toLowerCase();

      final code = StudentDataService.value(book, ['book_code', 'bookCode'])
          .toLowerCase();

      final cat = StudentDataService.value(
        book,
        ['category'],
      );

      final course = StudentDataService.value(book, ['course', 'course_name'])
          .toLowerCase();

      final matchesSearch = q.isEmpty ||
          title.contains(q) ||
          author.contains(q) ||
          code.contains(q) ||
          course.contains(q);

      final matchesCategory = category == 'All' || cat == category;

      return matchesSearch && matchesCategory;
    }).toList();

    return result;
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  List<String> get categories {
    final values = <String>{};

    for (final book in books) {
      final value = StudentDataService.value(
        book,
        ['category'],
      );

      if (value.isNotEmpty) {
        values.add(value);
      }
    }

    final list = values.toList()..sort();

    return ['All', ...list];
  }

  // ============================================================
  // RESERVE
  // ============================================================

  Future<void> _reserve(
    Map<String, dynamic> book,
  ) async {
    if (student == null) {
      _showError('Student profile not found.');
      return;
    }

    if (busy) return;

    final bookId = '${book['id'] ?? ''}';

    if (bookId.isEmpty) {
      _showError('Book ID is missing.');
      return;
    }

    if (_hasThisBook(bookId)) {
      _showError(
        'You already have this book reserved or issued.',
      );
      return;
    }

    // ==========================================================
    // HARD UI LIMIT
    //
    // Student can have only ONE active book.
    // ==========================================================

    if (hasActiveBook) {
      _showError(
        'Library limit reached. You can have only 1 active book at a time.',
      );
      return;
    }

    final available = StudentDataService.number(
      book,
      ['available_copies', 'availableCopies'],
      0,
    );

    if (available <= 0) {
      _showError(
        'This book is currently unavailable.',
      );
      return;
    }

    setState(() {
      busy = true;
      error = '';
      success = '';
    });

    try {
      await StudentDataService.reserveBook(
        student: student!,
        bookId: bookId,
      );

      await _load();

      if (!mounted) return;

      setState(() {
        selectedTab = 1;
        success =
            'Book reserved successfully. Please collect it from the library within 1 hour.';
      });
    } catch (e) {
      if (!mounted) return;

      final message = _cleanError(e);

      // Friendly message for the DB unique limit.
      if (message.toLowerCase().contains('unique') ||
          message.toLowerCase().contains('duplicate') ||
          message.toLowerCase().contains('library_one_active')) {
        setState(() {
          error =
              'You already have an active library book. Return it before reserving another one.';
        });
      } else {
        setState(() {
          error = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      error = message;
      success = '';
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Library',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            30,
          ),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _limitCard(),
            const SizedBox(height: 14),
            if (error.isNotEmpty)
              _message(
                error,
                true,
              ),
            if (success.isNotEmpty)
              _message(
                success,
                false,
              ),
            if (error.isNotEmpty || success.isNotEmpty)
              const SizedBox(height: 10),
            _tabs(),
            const SizedBox(height: 16),
            if (selectedTab == 0) _booksTab() else _myBooksTab(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(
        currentIndex: 0,
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryDark,
            primary,
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22059669),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: .15),
              ),
            ),
            child: const Icon(
              Icons.local_library_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'College Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student == null
                      ? 'Books & resources'
                      : '${student!.course} • Semester ${student!.semester}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIMIT CARD
  // ============================================================

  Widget _limitCard() {
    final reached = hasActiveBook;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: reached ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: reached ? const Color(0xFFFED7AA) : border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: reached ? const Color(0xFFFFEDD5) : lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              reached
                  ? Icons.bookmark_added_rounded
                  : Icons.library_books_outlined,
              size: 19,
              color: reached ? const Color(0xFFC2410C) : primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reached ? '1 / 1 book borrowed' : '0 / 1 book borrowed',
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reached
                      ? 'Return your current book before reserving another.'
                      : 'You can reserve one book at a time.',
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _tabs() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color.fromARGB(255, 0, 0, 0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              index: 0,
              icon: Icons.menu_book_rounded,
              title: 'Books',
              count: books.length,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _tabButton(
              index: 1,
              icon: Icons.bookmark_rounded,
              title: 'My Books',
              count: activeBookCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String title,
    required int count,
  }) {
    final active = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
          query = '';
          category = 'All';
          error = '';
          success = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color.fromARGB(255, 0, 0, 0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : const Color.fromARGB(255, 0, 17, 3),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.white : const Color.fromARGB(255, 1, 20, 0),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(
                minWidth: 18,
              ),
              height: 18,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: .18)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF64748B),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOOKS TAB
  // ============================================================

  Widget _booksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Books',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Browse available books and reserve one from the library.',
          style: TextStyle(
            color: textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 12),
        _search(),
        const SizedBox(height: 9),
        _categoryBar(),
        const SizedBox(height: 15),
        if (loading)
          _loading()
        else if (filteredBooks.isEmpty)
          _empty(
            Icons.menu_book_outlined,
            'No books found',
            'No books match your search or category.',
          )
        else
          ...filteredBooks.map(_bookCard),
      ],
    );
  }

  // ============================================================
  // MY BOOKS TAB
  // ============================================================

  Widget _myBooksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Books',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your currently reserved or issued library book.',
          style: TextStyle(
            color: textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 15),
        if (loading)
          _loading()
        else if (activeMyBooks.isEmpty)
          _empty(
            Icons.bookmark_border_rounded,
            'No books yet',
            'A book you reserve or receive will appear here.',
          )
        else
          ...activeMyBooks.map(_myBookCard),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _search() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 19,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search books, authors or book code...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                ),
              ),
              style: const TextStyle(
                color: textDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Widget _categoryBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final item = categories[index];

          final active = item == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                category = item;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? primary : Colors.white,
                borderRadius: BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  color: active ? primary : border,
                ),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : const Color(
                          0xFF475569,
                        ),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BOOK CARD
  // ============================================================

  Widget _bookCard(
    Map<String, dynamic> book,
  ) {
    final id = '${book['id'] ?? ''}';

    final title = StudentDataService.value(
      book,
      ['title'],
      'Untitled Book',
    );

    final author = StudentDataService.value(
      book,
      ['author'],
      'Unknown author',
    );

    final code = StudentDataService.value(
      book,
      ['book_code', 'bookCode'],
    );

    final cat = StudentDataService.value(
      book,
      ['category'],
      'General',
    );

    final course = StudentDataService.value(
      book,
      ['course', 'course_name'],
    );

    final available = StudentDataService.number(
      book,
      ['available_copies', 'availableCopies'],
      0,
    );

    final total = StudentDataService.number(
      book,
      ['total_copies', 'totalCopies'],
      0,
    );

    final alreadyMine = _hasThisBook(id);
    final limitReached = hasActiveBook && !alreadyMine;

    final canReserve = available > 0 && !alreadyMine && !limitReached && !busy;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF111827),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 11, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Availability
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: available > 0
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    available > 0 ? '$available / $total' : 'OUT',
                    style: TextStyle(
                      color: available > 0
                          ? const Color(0xFF047857)
                          : const Color(0xFFBE123C),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            // Metadata row
            Row(
              children: [
                _bookMeta(
                  Icons.category_outlined,
                  cat,
                ),
                if (course.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _bookMeta(
                    Icons.school_outlined,
                    course,
                  ),
                ],
                if (code.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _bookMeta(
                    Icons.tag_rounded,
                    code,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Divider
            const Divider(
              height: 1,
              color: Color(0xFFE5E7EB),
            ),

            const SizedBox(height: 11),

            // Bottom row
            Row(
              children: [
                Expanded(
                  child: Text(
                    alreadyMine
                        ? 'This book is already in My Books'
                        : limitReached
                            ? 'You already have an active book'
                            : available > 0
                                ? 'Available for reservation'
                                : 'Currently unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: alreadyMine
                          ? const Color(0xFF0F766E)
                          : limitReached
                              ? const Color(0xFF92400E)
                              : const Color(0xFF64748B),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Elevated reserve button
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: canReserve ? () => _reserve(book) : null,
                    icon: Icon(
                      alreadyMine
                          ? Icons.check_rounded
                          : Icons.bookmark_add_rounded,
                      size: 14,
                    ),
                    label: Text(
                      alreadyMine
                          ? 'Reserved'
                          : limitReached
                              ? 'Limit 1/1'
                              : available <= 0
                                  ? 'Unavailable'
                                  : busy
                                      ? 'Please wait'
                                      : 'Reserve',
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: canReserve ? 5 : 0,
                      shadowColor: const Color(0x550F766E),
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF1F5F9),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookMeta(
    IconData icon,
    String text,
  ) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 10,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MY BOOK CARD
  // ============================================================

  Widget _myBookCard(
    Map<String, dynamic> reservation,
  ) {
    final status = StudentDataService.value(
      reservation,
      ['status'],
      'RESERVED',
    ).toUpperCase();

    final issued = status == 'ISSUED';

    final title = StudentDataService.value(
      reservation,
      [
        'book_title',
        'title',
      ],
      'Library Book',
    );

    final code = StudentDataService.value(
      reservation,
      [
        'book_code',
        'bookCode',
      ],
    );

    final reservedAt = reservation['reserved_at'];

    final pickupDeadline = reservation['pickup_deadline'];

    final issuedAt = reservation['issued_at'];

    final dueDate = reservation['due_date'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: const Color(
            0xFF111827,
          ),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 49,
                height: 54,
                decoration: BoxDecoration(
                  color: issued
                      ? const Color(
                          0xFFEFF6FF,
                        )
                      : const Color(
                          0xFFFFF7ED,
                        ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  issued
                      ? Icons.menu_book_rounded
                      : Icons.bookmark_added_rounded,
                  color: issued
                      ? const Color(
                          0xFF2563EB,
                        )
                      : const Color(
                          0xFFD97706,
                        ),
                  size: 25,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        code,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _statusBadge(
                status,
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(
              12,
            ),
            decoration: BoxDecoration(
              color: const Color(
                0xFFF8FAFC,
              ),
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            child: Column(
              children: [
                _detailRow(
                  Icons.event_outlined,
                  issued ? 'Issued' : 'Reserved',
                  _formatDateTime(
                    issued ? issuedAt : reservedAt,
                  ),
                ),
                if (!issued && pickupDeadline != null) ...[
                  const SizedBox(
                    height: 9,
                  ),
                  _detailRow(
                    Icons.access_time_rounded,
                    'Pickup before',
                    _formatDateTime(
                      pickupDeadline,
                    ),
                  ),
                ],
                if (issued && dueDate != null) ...[
                  const SizedBox(
                    height: 9,
                  ),
                  _detailRow(
                    Icons.event_available_outlined,
                    'Return by',
                    _formatDate(
                      dueDate,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            children: [
              Icon(
                issued
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 15,
                color: issued
                    ? primary
                    : const Color(
                        0xFFD97706,
                      ),
              ),
              const SizedBox(
                width: 7,
              ),
              Expanded(
                child: Text(
                  issued
                      ? 'This book is currently issued to you.'
                      : 'Your reservation is waiting for pickup at the library.',
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PILL
  // ============================================================

  Widget _pill(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(
          8,
        ),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: textMuted,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    final issued = status == 'ISSUED';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: issued ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(
          9,
        ),
      ),
      child: Text(
        issued ? 'ISSUED' : 'RESERVED',
        style: TextStyle(
          color: issued
              ? const Color(
                  0xFF2563EB,
                )
              : const Color(
                  0xFFD97706,
                ),
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: textMuted,
        ),
        const SizedBox(
          width: 8,
        ),
        Text(
          label,
          style: const TextStyle(
            color: textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: textDark,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget _message(
    String text,
    bool isError,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 2,
      ),
      padding: const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFEFFDF5),
        borderRadius: BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: isError
                ? const Color(
                    0xFFBE123C,
                  )
                : primary,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError
                    ? const Color(
                        0xFFBE123C,
                      )
                    : const Color(
                        0xFF047857,
                      ),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                error = '';
                success = '';
              });
            },
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 55,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: primary,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _empty(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 25,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: const Color(
            0xFF111827,
          ),
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: const Color(
              0xFF94A3B8,
            ),
          ),
          const SizedBox(
            height: 11,
          ),
          Text(
            title,
            style: const TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '—';
    }

    final date = DateTime.tryParse('$value');

    if (date == null) {
      return '—';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // ============================================================
  // DATE + TIME
  // ============================================================

  String _formatDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '—';
    }

    final date = DateTime.tryParse('$value');

    if (date == null) {
      return '—';
    }

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day.toString().padLeft(2, '0')} '
        '${_monthName(date.month)} '
        '${date.year} • '
        '$hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}
