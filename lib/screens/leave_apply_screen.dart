import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class LeaveApplyScreen extends StatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  static const Color primary = Color.fromARGB(255, 99, 10, 91);

  static const Color darkPurple = Color.fromARGB(255, 94, 13, 83);

  static const Color accentPurple = Color.fromARGB(255, 154, 24, 158);

  static const Color background = Color(0xFFF8FAFC);

  static const Color textDark = Color.fromARGB(255, 51, 23, 50);

  static const Color textMuted = Color(0xFF64748B);

  static const Color border = Color(0xFFE2E8F0);

  final TextEditingController reasonController = TextEditingController();

  StudentProfile? student;

  List<Map<String, dynamic>> myLeaves = [];

  DateTime? fromDate;
  DateTime? toDate;

  String? selectedFaculty;

  bool loading = true;
  bool submitting = false;
  bool refreshingRealtime = false;

  String error = '';
  String success = '';

  RealtimeChannel? _leaveChannel;

  final List<String> faculties = [
    'Computer Science',
    'Commerce',
    'Management Studies',
    'English',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    reasonController.dispose();

    final channel = _leaveChannel;
    _leaveChannel = null;

    if (channel != null) {
      Supabase.instance.client.removeChannel(
        channel,
      );
    }

    super.dispose();
  }

  // ============================================================
  // LOAD
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

      final leaves = await StudentDataService.leaves(s);

      if (!mounted) return;

      setState(() {
        student = s;
        myLeaves = List<Map<String, dynamic>>.from(
          leaves,
        );
        loading = false;
        error = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = _cleanError(e);
      });
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    final client = Supabase.instance.client;

    _leaveChannel = client.channel(
      'student-leaves-${DateTime.now().microsecondsSinceEpoch}',
    );

    _leaveChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leave_requests',
          callback: (_) {
            if (!mounted || refreshingRealtime) {
              return;
            }

            _refreshRealtime();
          },
        )
        .subscribe();
  }

  Future<void> _refreshRealtime() async {
    if (!mounted || refreshingRealtime) {
      return;
    }

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
  // SUBMIT LEAVE
  // ============================================================

  Future<void> _submitLeave() async {
    if (submitting) return;

    if (student == null) {
      try {
        final s = await StudentDataService.currentStudent();

        if (!mounted) return;

        setState(() {
          student = s;
        });
      } catch (e) {
        _showError(_cleanError(e));
        return;
      }
    }

    final s = student;

    if (s == null) {
      _showError(
        'Student profile not found. Please login again.',
      );
      return;
    }

    if (fromDate == null || toDate == null) {
      _showError(
        'Please select both dates.',
      );
      return;
    }

    if (toDate!.isBefore(fromDate!)) {
      _showError(
        'To date cannot be before from date.',
      );
      return;
    }

    final reason = reasonController.text.trim();

    if (reason.isEmpty) {
      _showError(
        'Please enter the reason for leave.',
      );
      return;
    }

    if (reason.length < 3) {
      _showError(
        'Please enter a valid reason.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      submitting = true;
      error = '';
      success = '';
    });

    try {
      await StudentDataService.createLeave(
        student: s,
        from: _dateOnly(fromDate!),
        to: _dateOnly(toDate!),
        reason: reason,
      );

      if (!mounted) return;

      setState(() {
        selectedFaculty = null;
        fromDate = null;
        toDate = null;
        reasonController.clear();
        success = 'Leave request submitted successfully.';
      });

      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _selectFromDate() async {
    final today = _dateOnly(
      DateTime.now(),
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? today,
      firstDate: today,
      lastDate: DateTime(2030, 12, 31),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      fromDate = picked;

      if (toDate != null && toDate!.isBefore(picked)) {
        toDate = null;
      }
    });
  }

  Future<void> _selectToDate() async {
    final minimumDate = fromDate ??
        _dateOnly(
          DateTime.now(),
        );

    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? minimumDate,
      firstDate: minimumDate,
      lastDate: DateTime(2030, 12, 31),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      toDate = picked;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: const Text(
          'Leave Apply',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(
          color: textDark,
        ),
        actions: [
          if (refreshingRealtime)
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
            35,
          ),
          children: [
            _headerCard(),
            const SizedBox(height: 18),
            if (error.isNotEmpty)
              _messageCard(
                error,
                true,
              ),
            if (success.isNotEmpty)
              _messageCard(
                success,
                false,
              ),
            _sectionTitle(
              'Apply for Leave',
              'Fill in the details below',
            ),
            const SizedBox(height: 12),
            _leaveForm(),
            const SizedBox(height: 22),
            _myLeavesSection(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(
        currentIndex: 0,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkPurple,
            accentPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x301F102D),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(
                14,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .16),
              ),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a leave?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Submit your leave request easily.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
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
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: textMuted,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }

  // ============================================================
  // FORM
  // ============================================================

  Widget _leaveForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 11,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('LEAVE DATES'),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  label: 'From Date',
                  date: fromDate,
                  onTap: _selectFromDate,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _dateField(
                  label: 'To Date',
                  date: toDate,
                  onTap: _selectToDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _fieldLabel('REASON'),
          const SizedBox(height: 7),
          TextField(
            controller: reasonController,
            maxLines: 5,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: textDark,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Enter the reason for your leave...',
              hintStyle: const TextStyle(
                color: Color(0xFFA0A9B5),
                fontSize: 10.5,
              ),
              filled: true,
              fillColor: const Color(0xFFFAFBFD),
              contentPadding: const EdgeInsets.all(13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: accentPurple,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 51,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : _submitLeave,
              icon: submitting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 17,
                    ),
              label: Text(
                submitting ? 'Submitting...' : 'Submit Leave Request',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: submitting ? 0 : 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FACULTY DROPDOWN
  // ============================================================

  Widget _facultyDropdown() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFaculty,
          isExpanded: true,
          hint: const Text(
            'Select faculty',
            style: TextStyle(
              color: textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: primary,
          ),
          items: faculties.map(
            (faculty) {
              return DropdownMenuItem<String>(
                value: faculty,
                child: Text(
                  faculty,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: submitting
              ? null
              : (value) {
                  setState(() {
                    selectedFaculty = value;
                  });
                },
        ),
      ),
    );
  }

  // ============================================================
  // DATE FIELD
  // ============================================================

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: submitting ? null : onTap,
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(
          12,
          9,
          10,
          8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select date'
                        : _formatDate(
                            date,
                          ),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: date == null
                          ? const Color(
                              0xFF94A3B8,
                            )
                          : textDark,
                      fontSize: 10,
                      fontWeight:
                          date == null ? FontWeight.w500 : FontWeight.w800,
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

  // ============================================================
  // MY LEAVES
  // ============================================================

  Widget _myLeavesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Leave Requests',
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Track the status of your requests.',
          style: TextStyle(
            color: textMuted,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 11),
        if (loading)
          _loading()
        else if (myLeaves.isEmpty)
          _emptyLeaves()
        else
          ...myLeaves.map(
            _leaveRequestCard,
          ),
      ],
    );
  }

  Widget _leaveRequestCard(
    Map<String, dynamic> row,
  ) {
    final status = StudentDataService.value(
      row,
      ['status'],
      'Pending',
    );

    final reason = StudentDataService.value(
      row,
      ['reason'],
      'No reason provided.',
    );

    final faculty = StudentDataService.value(
      row,
      [
        'faculty_name',
        'faculty',
        'faculty_id',
      ],
      'Faculty',
    );

    final from = row['from_date'];

    final to = row['to_date'];

    final normalized = status.toLowerCase();

    final isApproved = normalized == 'approved' || normalized == 'accepted';

    final isRejected = normalized == 'rejected' || normalized == 'declined';

    final statusColor = isApproved
        ? const Color(
            0xFF15803D,
          )
        : isRejected
            ? const Color(
                0xFFDC2626,
              )
            : const Color(
                0xFFB45309,
              );

    final statusBackground = isApproved
        ? const Color(
            0xFFEAF8EE,
          )
        : isRejected
            ? const Color(
                0xFFFFEEEE,
              )
            : const Color(
                0xFFFFF6E5,
              );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatRange(
                  from,
                  to,
                ),
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: primary,
                size: 14,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  faculty,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            reason,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textMuted,
              fontSize: 9.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLeaves() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            color: Color(
              0xFFB8A3B8,
            ),
            size: 32,
          ),
          SizedBox(height: 8),
          Text(
            'No leave requests yet',
            style: TextStyle(
              color: textDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Your submitted requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 30,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.3,
          color: primary,
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Widget _messageCard(
    String text,
    bool isError,
  ) {
    final color = isError ? const Color(0xFFBE123C) : const Color(0xFF15803D);

    final bg = isError ? const Color(0xFFFFF1F2) : const Color(0xFFEFFAF2);

    final borderColor =
        isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
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
              color: textMuted,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'PostgrestException(message: ',
          '',
        )
        .replaceFirst(
          RegExp(r', code:.*'),
          '',
        )
        .replaceAll(
          RegExp(r'\)$'),
          '',
        );
  }

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    setState(() {
      error = message;
      success = '';
    });
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
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

  String _formatRange(
    dynamic from,
    dynamic to,
  ) {
    final f = DateTime.tryParse('$from');

    final t = DateTime.tryParse('$to');

    if (f == null && t == null) {
      return 'Date not set';
    }

    if (t == null) {
      return _formatDate(f!);
    }

    return '${_formatDate(f!)} – '
        '${_formatDate(t)}';
  }
}
