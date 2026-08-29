import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key});

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  // ============================================================
  // STATE
  // ============================================================

  StudentProfile? student;
  List<Map<String, dynamic>> doubts = [];

  bool loading = true;
  bool submitting = false;
  bool refreshingRealtime = false;

  int filter = 0;

  final filters = const [
    'All',
    'Pending',
    'Answered',
  ];

  final subjectController = TextEditingController();
  final questionController = TextEditingController();

  String error = '';
  String success = '';

  RealtimeChannel? _doubtsChannel;

  static const primary = Color(0xFF1D4ED8);
  static const primaryDark = Color(0xFF1E3A8A);
  static const background = Color(0xFFF7F9FC);
  static const textDark = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    subjectController.dispose();
    questionController.dispose();

    final channel = _doubtsChannel;
    _doubtsChannel = null;

    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }

    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final s = student ?? await StudentDataService.currentStudent();

      final data = await StudentDataService.doubts(s);

      if (!mounted) return;

      setState(() {
        student = s;
        doubts = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    final client = Supabase.instance.client;

    _doubtsChannel = client.channel(
      'student-doubts-${DateTime.now().microsecondsSinceEpoch}',
    );

    _doubtsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'doubts',
          callback: (payload) {
            if (!mounted || refreshingRealtime) return;

            _refreshRealtime();
          },
        )
        .subscribe();
  }

  Future<void> _refreshRealtime() async {
    if (!mounted || refreshingRealtime) return;

    setState(() {
      refreshingRealtime = true;
    });

    try {
      await _load(showLoader: false);
    } finally {
      if (mounted) {
        setState(() {
          refreshingRealtime = false;
        });
      }
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (student == null) {
      await _load();
      if (student == null) return;
    }

    final subject = subjectController.text.trim();
    final question = questionController.text.trim();

    if (subject.isEmpty) {
      setState(() {
        error = 'Please enter the subject.';
        success = '';
      });
      return;
    }

    if (question.isEmpty) {
      setState(() {
        error = 'Please enter your question.';
        success = '';
      });
      return;
    }

    if (question.length < 5) {
      setState(() {
        error = 'Please enter a little more detail.';
        success = '';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      submitting = true;
      error = '';
      success = '';
    });

    try {
      await StudentDataService.createDoubt(
        student: student!,
        subject: subject,
        question: question,
      );

      subjectController.clear();
      questionController.clear();

      await _load(showLoader: false);

      if (!mounted) return;

      setState(() {
        success = 'Doubt submitted successfully.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  // ============================================================
  // FILTERING
  // ============================================================

  List<Map<String, dynamic>> get filtered {
    if (filter == 0) {
      return doubts;
    }

    final wanted = filters[filter].toLowerCase();

    return doubts.where((d) {
      final status = StudentDataService.value(
        d,
        ['status'],
        'Pending',
      ).trim().toLowerCase();

      return status == wanted;
    }).toList();
  }

  // ============================================================
  // UI
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
          'Doubts',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (refreshingRealtime)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () => _load(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            2,
            16,
            32,
          ),
          children: [
            _hero(),
            const SizedBox(height: 13),
            if (error.isNotEmpty)
              _alert(
                text: error,
                danger: true,
              ),
            if (success.isNotEmpty)
              _alert(
                text: success,
                danger: false,
              ),
            _askCard(),
            const SizedBox(height: 17),
            _sectionHeader(),
            const SizedBox(height: 9),
            _filters(),
            const SizedBox(height: 11),
            if (loading)
              _loading()
            else if (filtered.isEmpty)
              _empty()
            else
              ...filtered.map(_doubtCard),
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
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        17,
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
            color: Color(0x221D4ED8),
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
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: .16),
              ),
            ),
            child: const Icon(
              Icons.forum_rounded,
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
                  'Ask your faculty',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Send a question and track the response here.',
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
  // ASK CARD
  // ============================================================

  Widget _askCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 19,
                color: primary,
              ),
              SizedBox(width: 7),
              Text(
                'Ask a new doubt',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _input(
            controller: subjectController,
            label: 'Subject',
            hint: 'e.g. Computer Networks',
            icon: Icons.menu_book_outlined,
            maxLines: 1,
          ),
          const SizedBox(height: 9),
          _input(
            controller: questionController,
            label: 'Your question',
            hint: 'Explain what you need help with...',
            icon: Icons.help_outline_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : _submit,
              icon: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 16,
                    ),
              label: Text(
                submitting ? 'Submitting...' : 'Submit Doubt',
              ),
              style: ElevatedButton.styleFrom(
                elevation: submitting ? 0 : 4,
                shadowColor: const Color(0x441D4ED8),
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      style: const TextStyle(
        color: textDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: 11,
            right: 7,
          ),
          child: Icon(
            icon,
            size: 17,
            color: const Color(0xFF64748B),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: primary,
            width: 1.3,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LIST HEADER + FILTER
  // ============================================================

  Widget _sectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Doubts',
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Questions you have submitted.',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${filtered.length} shown',
          style: const TextStyle(
            color: textMuted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    return Container(
      height: 43,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: List.generate(
          filters.length,
          (i) {
            final active = i == filter;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    filter = i;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    filters[i],
                    style: TextStyle(
                      color: active ? Colors.white : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // DOUBT CARD
  // ============================================================

  Widget _doubtCard(
    Map<String, dynamic> doubt,
  ) {
    final status = StudentDataService.value(
      doubt,
      ['status'],
      'Pending',
    );

    final answered = status.toLowerCase() == 'answered';

    final subject = StudentDataService.value(
      doubt,
      ['subject'],
      'General',
    );

    final question = StudentDataService.value(
      doubt,
      ['question', 'message'],
      'No question',
    );

    final answer = StudentDataService.value(
      doubt,
      ['answer', 'faculty_answer'],
    );

    final faculty = StudentDataService.value(
      doubt,
      [
        'faculty',
        'faculty_name',
        'teacher',
      ],
    );

    final createdAt = StudentDataService.date(
      doubt,
      [
        'created_at',
        'asked_at',
        'createdAt',
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: answered ? const Color(0xFFDDEFE2) : border,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: answered
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  answered ? Icons.check_rounded : Icons.help_outline_rounded,
                  size: 17,
                  color: answered ? const Color(0xFF15803D) : primary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 7),
              _statusBadge(
                status,
                answered,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              question,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 10.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (answer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color(0xFFDCFCE7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          faculty.isEmpty ? 'Faculty Answer' : faculty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    answer,
                    style: const TextStyle(
                      
                      color: Color.fromARGB(255, 15, 15, 15),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(
    String status,
    bool answered,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: answered ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: answered ? const Color(0xFF15803D) : const Color(0xFFD97706),
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // STATES
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

  Widget _empty() {
    final message = filter == 0
        ? 'No doubts yet.'
        : filter == 1
            ? 'No pending doubts.'
            : 'No answered doubts.';

    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: primary,
              size: 23,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask your first question using the form above.',
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

  Widget _alert({
    required String text,
    required bool danger,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 11,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: danger ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            danger
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 15,
            color: danger ? const Color(0xFFBE123C) : const Color(0xFF047857),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    danger ? const Color(0xFFBE123C) : const Color(0xFF047857),
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

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${local.year} • '
        '$hour:$minute $period';
  }
}
