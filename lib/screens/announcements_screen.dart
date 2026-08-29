import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Map<String, dynamic>> items = [];

  StudentProfile? student;

  bool loading = true;
  bool realtimeRefreshing = false;

  String error = '';

  RealtimeChannel? _announcementsChannel;

  static const primary = Color(0xFF9F2424);
  static const primaryDark = Color(0xFF711717);
  static const background = Color(0xFFFAF8F8);
  static const textDark = Color(0xFF202020);
  static const textMuted = Color(0xFF737373);
  static const border = Color(0xFFE7DDDD);

  @override
  void initState() {
    super.initState();

    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    final channel = _announcementsChannel;

    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD ANNOUNCEMENTS
  // ============================================================

  Future<void> _load({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final s = student ?? await StudentDataService.currentStudent();

      final data = await StudentDataService.announcements();

      if (!mounted) return;

      final visible = data.where((r) {
        // ------------------------------------------------------
        // PUBLISHED CHECK
        // ------------------------------------------------------

        final status = StudentDataService.value(
          r,
          ['status'],
        ).trim().toLowerCase();

        final publishedValue = r['published'];

        final isPublished = status.isEmpty ||
            status == 'published' ||
            status == 'active' ||
            publishedValue == true ||
            publishedValue == null;

        if (!isPublished) {
          return false;
        }

        // ------------------------------------------------------
        // AUDIENCE CHECK
        // ------------------------------------------------------

        final audienceType = StudentDataService.value(
          r,
          ['audience_type'],
          'all',
        ).trim().toLowerCase();

        // All students
        if (audienceType.isEmpty || audienceType == 'all') {
          return true;
        }

        // Course + semester targeting
        if (audienceType == 'course_semester') {
          final targetCourse = StudentDataService.value(
            r,
            ['target_course'],
          ).trim().toLowerCase();

          final targetSemester = _toInt(
            r['target_semester'],
          );

          final studentCourse = s.course.trim().toLowerCase();

          final studentSemester = _toInt(s.semester);

          final courseMatches =
              targetCourse.isNotEmpty && targetCourse == studentCourse;

          final semesterMatches = targetSemester != null &&
              studentSemester != null &&
              targetSemester == studentSemester;

          return courseMatches && semesterMatches;
        }

        // Unknown audience type:
        // don't accidentally expose it.
        return false;
      }).toList();

      setState(() {
        student = s;
        items = visible;
        loading = false;
        error = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
        loading = false;
      });
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    final client = Supabase.instance.client;

    _announcementsChannel = client
        .channel(
          'student-announcements-${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            if (!mounted) return;

            debugPrint(
              'ANNOUNCEMENT REALTIME: ${payload.eventType}',
            );

            _refreshRealtime();
          },
        )
        .subscribe();
  }

  Future<void> _refreshRealtime() async {
    if (!mounted || realtimeRefreshing) {
      return;
    }

    setState(() {
      realtimeRefreshing = true;
    });

    try {
      await _load(
        showLoader: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          realtimeRefreshing = false;
        });
      }
    }
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: const Text(
          'Announcements',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (realtimeRefreshing)
            const Padding(
              padding: EdgeInsets.only(
                right: 18,
              ),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () => _load(
          showLoader: false,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            32,
          ),
          children: [
            _hero(),
            const SizedBox(height: 17),
            if (error.isNotEmpty) _alert(error),
            _sectionHeader(),
            const SizedBox(height: 11),
            if (loading)
              _loading()
            else if (items.isEmpty)
              _empty()
            else
              ...items.map(_card),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(
        currentIndex: 3,
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryDark,
            primary,
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241D0000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: .16),
              ),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay Updated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Official announcements from Royal College.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    height: 1.35,
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
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest Updates',
                style: TextStyle(
                  color: textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Important updates from your college',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7EAEA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${items.length}',
              style: const TextStyle(
                color: primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ANNOUNCEMENT CARD
  // ============================================================

  Widget _card(
    Map<String, dynamic> item,
  ) {
    final title = StudentDataService.value(
      item,
      ['title'],
      'Announcement',
    );

    final message = StudentDataService.value(
      item,
      [
        'message',
        'description',
      ],
    );

    final category = StudentDataService.value(
      item,
      [
        'category',
        'audience',
      ],
      'General',
    );

    final priority = StudentDataService.value(
      item,
      ['priority'],
      'Normal',
    );

    final date = StudentDataService.value(
      item,
      [
        'published_at',
        'created_at',
        'date',
      ],
    );

    final audience = StudentDataService.value(
      item,
      ['audience_type'],
      'all',
    );

    final isUrgent = priority.toLowerCase() == 'urgent';

    final isImportant = priority.toLowerCase() == 'important';

    final priorityColor = isUrgent
        ? const Color(0xFFDC2626)
        : isImportant
            ? const Color(0xFFD97706)
            : primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () {
          _showDetails(
            item,
            title: title,
            message: message,
            category: category,
            priority: priority,
            date: date,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(
            bottom: 11,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isUrgent
                  ? const Color(
                      0xFFF4CACA,
                    )
                  : border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PRIORITY BAR
              Container(
                width: 4,
                height: 92,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP ROW
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? const Color(
                                    0xFFFFE4E6,
                                  )
                                : const Color(
                                    0xFFF7EAEA,
                                  ),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: priorityColor,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isUrgent || isImportant)
                          Text(
                            priority.toUpperCase(),
                            style: TextStyle(
                              color: priorityColor,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        const Spacer(),
                        if (date.isNotEmpty)
                          Text(
                            _shortDate(date),
                            style: const TextStyle(
                              color: Color(
                                0xFF94A3B8,
                              ),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // TITLE
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 15,
                        height: 1.28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 9.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (audience == 'course_semester')
                          const Icon(
                            Icons.school_outlined,
                            size: 11,
                            color: primary,
                          ),
                        if (audience == 'course_semester')
                          const SizedBox(
                            width: 4,
                          ),
                        Text(
                          audience == 'course_semester'
                              ? 'For your course & semester'
                              : 'For all students',
                          style: const TextStyle(
                            color: primary,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Read',
                          style: TextStyle(
                            color: primary,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: primary,
                          size: 11,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FULL ANNOUNCEMENT POPUP
  // ============================================================

  void _showDetails(
    Map<String, dynamic> item, {
    required String title,
    required String message,
    required String category,
    required String priority,
    required String date,
  }) {
    final isUrgent = priority.toLowerCase() == 'urgent';

    final audience = StudentDataService.value(
      item,
      ['audience_type'],
      'all',
    );

    final targetCourse = StudentDataService.value(
      item,
      ['target_course'],
    );

    final targetSemester = _toInt(
      item['target_semester'],
    );

    final priorityColor = isUrgent
        ? const Color(0xFFDC2626)
        : priority.toLowerCase() == 'important'
            ? const Color(
                0xFFD97706,
              )
            : primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 700,
            ),
            padding: const EdgeInsets.fromLTRB(
              18,
              10,
              18,
              20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HANDLE
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFE2E8F0,
                        ),
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // HEADER
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? const Color(
                                  0xFFFFE4E6,
                                )
                              : const Color(
                                  0xFFF7EAEA,
                                ),
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: Icon(
                          isUrgent
                              ? Icons.priority_high_rounded
                              : Icons.campaign_rounded,
                          color: priorityColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: const TextStyle(
                                color: primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              priority,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(
                          context,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // FULL TITLE
                  Text(
                    title,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      _fullDate(date),
                      style: const TextStyle(
                        color: Color(
                          0xFF94A3B8,
                        ),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // AUDIENCE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF8FAFC,
                      ),
                      borderRadius: BorderRadius.circular(
                        11,
                      ),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: primary,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            audience == 'course_semester'
                                ? 'For ${targetCourse.isEmpty ? "selected course" : targetCourse}'
                                    ' • Semester ${targetSemester ?? "-"}'
                                : 'For all students',
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // MESSAGE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFAF8F8,
                      ),
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: Text(
                      message.isEmpty ? 'No message provided.' : message,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontSize: 15,
                        height: 1.7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // CLOSE
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            11,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text(
                        'Close',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  String _shortDate(String raw) {
    final d = DateTime.tryParse(raw);

    if (d == null) return raw;

    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)}';
  }

  String _fullDate(String raw) {
    final d = DateTime.tryParse(raw);

    if (d == null) return raw;

    final local = d.toLocal();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day.toString().padLeft(2, '0')} '
        '${_month(local.month)} '
        '${local.year} • '
        '$hour:$minute $period';
  }

  String _month(int m) => const [
        '',
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
      ][m];

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

  Widget _empty() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: Color(0xFFC7A7A7),
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'No announcements available.',
            style: TextStyle(
              color: textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'New college updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _alert(String text) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 15,
            color: Color(0xFFBE123C),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontSize: 9,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
