import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const Color attendancePrimary = Color.fromARGB(255, 3, 88, 84);

  static const Color attendanceDark = Color.fromARGB(255, 3, 90, 71);

  static const Color attendanceLight = Color(0xFFE7F7F4);

  static const Color attendanceAccent = Color.fromARGB(255, 9, 99, 61);

  String view = 'Day';

  DateTime selectedDate = DateTime.now();

  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  StudentProfile? student;

  List<Map<String, dynamic>> allAttendance = [];

  List<Map<String, dynamic>> timetableRows = [];

  List<Map<String, dynamic>> dayClasses = [];

  bool loading = true;

  String errorMessage = '';

  RealtimeChannel? _attendanceChannel;

  bool _refreshingRealtime = false;

  Timer? _realtimeDebounce;

  int presentCount = 0;
  int halfCount = 0;
  int absentCount = 0;
  int totalCount = 0;
  int attendancePercentage = 0;
  int monthlyWorkingDays = 0;
  bool loadingMonthlyWorkingDays = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _loadAttendance(
      showLoading: true,
    );

    if (!mounted) return;

    _startAttendanceRealtime();
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _startAttendanceRealtime() {
    final client = Supabase.instance.client;

    final user = client.auth.currentUser;

    final currentStudent = student;

    if (user == null) {
      debugPrint(
        'ATTENDANCE REALTIME: No authenticated user.',
      );
      return;
    }

    if (currentStudent == null) {
      debugPrint(
        'ATTENDANCE REALTIME: Student not loaded.',
      );
      return;
    }

    // Remove old channel if one exists.
    if (_attendanceChannel != null) {
      client.removeChannel(
        _attendanceChannel!,
      );
      _attendanceChannel = null;
    }

    final studentId = '${currentStudent.id}';

    debugPrint(
      'ATTENDANCE REALTIME START',
    );

    debugPrint(
      'USER ID: ${user.id}',
    );

    debugPrint(
      'STUDENT ID: $studentId',
    );

    // ==========================================================
    // CHANNEL
    // ==========================================================

    final channelName = 'student-attendance-${user.id}';

    _attendanceChannel = client
        .channel(channelName)

        // ========================================================
        // ATTENDANCE RECORDS
        // ========================================================

        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) {
            debugPrint(
              'ATTENDANCE RECORD REALTIME EVENT: '
              '${payload.eventType}',
            );

            _scheduleRealtimeRefresh();
          },
        )

        // ========================================================
        // ATTENDANCE SESSIONS
        // ========================================================

        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_sessions',
          callback: (payload) {
            debugPrint(
              'ATTENDANCE SESSION REALTIME EVENT: '
              '${payload.eventType}',
            );

            _scheduleRealtimeRefresh();
          },
        )

        // ========================================================
        // SUBSCRIBE
        // ========================================================

        .subscribe(
      (status, error) {
        debugPrint(
          'ATTENDANCE REALTIME STATUS: $status',
        );

        if (error != null) {
          debugPrint(
            'ATTENDANCE REALTIME ERROR: $error',
          );
        }
      },
    );
  }

  // ============================================================
  // REALTIME DEBOUNCE
  // ============================================================

  void _scheduleRealtimeRefresh() {
    if (!mounted) return;

    _realtimeDebounce?.cancel();

    _realtimeDebounce = Timer(
      const Duration(
        milliseconds: 300,
      ),
      () {
        _reloadAfterRealtime();
      },
    );
  }

  // ============================================================
  // SILENT REALTIME REFRESH
  // ============================================================

  Future<void> _reloadAfterRealtime() async {
    if (!mounted) return;

    if (_refreshingRealtime) {
      return;
    }

    _refreshingRealtime = true;

    try {
      // Give the database transaction a moment to settle.
      await Future<void>.delayed(
        const Duration(
          milliseconds: 150,
        ),
      );

      if (!mounted) return;

      debugPrint(
        'ATTENDANCE REALTIME: Refreshing data...',
      );

      // IMPORTANT:
      // No full-screen loading spinner during realtime update.
      await _loadAttendance(
        showLoading: false,
      );

      debugPrint(
        'ATTENDANCE REALTIME: Refresh complete.',
      );
    } catch (e) {
      debugPrint(
        'ATTENDANCE REALTIME REFRESH ERROR: $e',
      );
    } finally {
      _refreshingRealtime = false;
    }
  }

  // ============================================================
  // DISPOSE REALTIME
  // ============================================================

  @override
  void dispose() {
    _realtimeDebounce?.cancel();

    if (_attendanceChannel != null) {
      Supabase.instance.client.removeChannel(
        _attendanceChannel!,
      );

      _attendanceChannel = null;
    }

    super.dispose();
  }

  // ============================================================
  // LOAD ATTENDANCE
  // ============================================================

  Future<void> _loadAttendance({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        errorMessage = '';
      });
    }

    try {
      final currentStudent = await StudentDataService.currentStudent();

      final attendance = await StudentDataService.attendance(
        currentStudent,
      );
      int? selectedMonthDays;
      try {
        selectedMonthDays = await StudentDataService.attendanceWorkingDays(
          currentStudent,
          selectedMonth,
        );
      } catch (workingDaysError) {
        debugPrint('MONTHLY WORKING DAYS LOAD ERROR: $workingDaysError');
      }
      var timetable = <Map<String, dynamic>>[];
      try {
        timetable = await StudentDataService.timetable(currentStudent);
      } catch (timetableError) {
        debugPrint('ATTENDANCE TIMETABLE LOAD ERROR: $timetableError');
      }

      if (!mounted) return;

      setState(() {
        student = currentStudent;
        allAttendance = attendance;
        timetableRows = timetable;
        monthlyWorkingDays = selectedMonthDays ??
            _workingDayCount(
              attendance.where((row) {
                final date = _attendanceDate(row);
                return date != null && _sameMonth(date, selectedMonth);
              }).toList(),
            );
        loadingMonthlyWorkingDays = false;
        loading = false;
        errorMessage = '';
      });

      _refreshCalculations();

      // If realtime channel doesn't exist yet,
      // start it after student data is available.
      if (_attendanceChannel == null) {
        _startAttendanceRealtime();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;

        errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );

        allAttendance = [];
        timetableRows = [];
        dayClasses = [];

        presentCount = 0;
        halfCount = 0;
        absentCount = 0;
        totalCount = 0;
        attendancePercentage = 0;
        monthlyWorkingDays = 0;
        loadingMonthlyWorkingDays = false;
      });

      debugPrint(
        'ATTENDANCE LOAD ERROR: $e',
      );
    }
  }

  // ============================================================
  // REFRESH CALCULATIONS
  // ============================================================

  void _refreshCalculations() {
    _calculateDay();
    _calculateOverall();
  }

  // ============================================================
  // STATUS
  // ============================================================

  bool _isPresent(
    Map<String, dynamic> row,
  ) {
    final status = StudentDataService.value(
      row,
      ['status'],
    ).trim().toLowerCase();

    return status == 'present';
  }

  bool _isAbsent(
    Map<String, dynamic> row,
  ) {
    final status = StudentDataService.value(
      row,
      ['status'],
    ).trim().toLowerCase();

    return status == 'absent';
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _attendanceDate(
    Map<String, dynamic> row,
  ) {
    final raw = row['attendance_date'];

    if (raw == null) return null;

    return DateTime.tryParse(
      '$raw',
    );
  }

  // ============================================================
  // SAME DAY
  // ============================================================

  bool _sameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ============================================================
  // SAME MONTH
  // ============================================================

  bool _sameMonth(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month;
  }

  String _normalizedDay(String value) {
    final raw = value.trim().toLowerCase();
    const days = {
      'mon': 'monday',
      'monday': 'monday',
      'tue': 'tuesday',
      'tues': 'tuesday',
      'tuesday': 'tuesday',
      'wed': 'wednesday',
      'wednesday': 'wednesday',
      'thu': 'thursday',
      'thur': 'thursday',
      'thurs': 'thursday',
      'thursday': 'thursday',
      'fri': 'friday',
      'friday': 'friday',
    };
    return days[raw] ?? raw;
  }

  String _weekdayName(int weekday) => const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ][weekday - 1];

  int _periodNumber(dynamic value) {
    final match = RegExp(r'\d+').firstMatch('$value');
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }

  Map<String, dynamic> _timetableEntryFor(DateTime date, int hour) {
    for (final row in timetableRows) {
      final day = StudentDataService.value(row, [
        'day',
        'day_name',
        'weekday',
        'day_of_week',
      ]);
      final period = StudentDataService.value(row, ['hour', 'period']);
      if (_normalizedDay(day) == _weekdayName(date.weekday) &&
          _periodNumber(period) == hour) {
        return row;
      }
    }
    return const {};
  }

  Map<String, int> _attendanceSummary(
    List<Map<String, dynamic>> rows,
  ) {
    final byDate = <String, Map<String, int>>{};
    for (final row in rows) {
      final date = _attendanceDate(row);
      if (date == null) continue;
      final key = '${date.year}-${date.month}-${date.day}';
      final day = byDate.putIfAbsent(key, () => {'present': 0, 'absent': 0});
      if (_isPresent(row)) {
        day['present'] = (day['present'] ?? 0) + 1;
      } else if (_isAbsent(row)) {
        day['absent'] = (day['absent'] ?? 0) + 1;
      }
    }

    var present = 0;
    var half = 0;
    var absent = 0;
    for (final day in byDate.values) {
      final p = day['present'] ?? 0;
      final a = day['absent'] ?? 0;
      if (p > 0 && a == 0) {
        present++;
      } else if (a > 0 && p == 0) {
        absent++;
      } else if (p > 0 && a > 0) {
        half++;
      }
    }

    // Working days come from scheduled attendance sessions, never from
    // adding the student's present/half-day/absent totals.
    final total = _workingDayCount(rows);
    final percentage =
        total == 0 ? 0 : (((present + half * 0.5) / total) * 100).round();
    return {
      'present': present,
      'half': half,
      'absent': absent,
      'total': total,
      'percentage': percentage,
    };
  }

  int _workingDayCount(List<Map<String, dynamic>> scheduledSessions) {
    return scheduledSessions
        .map(_attendanceDate)
        .whereType<DateTime>()
        .map((date) => '${date.year}-${date.month}-${date.day}')
        .toSet()
        .length;
  }

  // ============================================================
  // DAY CALCULATION
  // ============================================================

  void _calculateDay() {
    final records = allAttendance.where(
      (row) {
        final date = _attendanceDate(row);

        if (date == null) return false;

        return _sameDay(
          date,
          selectedDate,
        );
      },
    ).toList();

    records.sort(
      (a, b) {
        final ah = int.tryParse(
              '${a['hour'] ?? 0}',
            ) ??
            0;

        final bh = int.tryParse(
              '${b['hour'] ?? 0}',
            ) ??
            0;

        return ah.compareTo(bh);
      },
    );

    final mapped = <Map<String, dynamic>>[];

    for (final record in records) {
      final hour = StudentDataService.number(
        record,
        [
          'hour',
          'period',
        ],
        0,
      );

      final status = StudentDataService.value(
        record,
        ['status'],
      ).toLowerCase();

      final date = _attendanceDate(record) ?? selectedDate;
      final timetableEntry = _timetableEntryFor(date, hour);

      mapped.add({
        'hour': hour == 0 ? 'Hour ${mapped.length + 1}' : 'Hour $hour',
        'subject': StudentDataService.value(
          timetableEntry,
          ['subject', 'subject_name', 'course_subject'],
          'Class',
        ),
        'faculty': StudentDataService.value(
          timetableEntry,
          ['faculty', 'faculty_name', 'teacher', 'teacher_name'],
          'Faculty not assigned',
        ),
        'time': StudentDataService.value(
          timetableEntry,
          ['time', 'time_slot', 'start_time'],
          '—',
        ),
        'status': status,
        'present': status == 'present',
      });
    }

    if (!mounted) return;

    setState(() {
      dayClasses = mapped;
    });
  }

  // ============================================================
  // OVERALL
  // ============================================================

  void _calculateOverall() {
    final summary = _attendanceSummary(allAttendance);

    if (!mounted) return;

    setState(() {
      presentCount = summary['present'] ?? 0;
      halfCount = summary['half'] ?? 0;
      absentCount = summary['absent'] ?? 0;
      totalCount = summary['total'] ?? 0;
      attendancePercentage = summary['percentage'] ?? 0;
    });
  }

  // ============================================================
  // MONTH RECORDS
  // ============================================================

  List<Map<String, dynamic>> _recordsForMonth(
    DateTime month,
  ) {
    return allAttendance.where(
      (row) {
        final date = _attendanceDate(row);

        if (date == null) return false;

        return _sameMonth(
          date,
          month,
        );
      },
    ).toList();
  }

  // ============================================================
  // MONTH STATS
  // ============================================================

  Map<String, int> _monthStats(
    DateTime month,
  ) {
    final records = _recordsForMonth(month);
    return _attendanceSummary(records);
  }

  // ============================================================
  // MONTH NAME
  // ============================================================

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formattedDate() {
    return '${_monthName(selectedDate.month)} '
        '${selectedDate.day}, '
        '${selectedDate.year}';
  }

  // ============================================================
  // MONTH NAVIGATION
  // ============================================================

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month - 1,
        1,
      );
    });
    _loadMonthlyWorkingDays();
  }

  void _nextMonth() {
    final next = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    final now = DateTime.now();

    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }

    setState(() {
      selectedMonth = next;
    });
    _loadMonthlyWorkingDays();
  }

  Future<void> _loadMonthlyWorkingDays() async {
    final currentStudent = student;
    if (currentStudent == null) return;
    final requestedMonth = selectedMonth;
    setState(() {
      loadingMonthlyWorkingDays = true;
    });

    try {
      final count = await StudentDataService.attendanceWorkingDays(
        currentStudent,
        requestedMonth,
      );
      if (!mounted ||
          selectedMonth.year != requestedMonth.year ||
          selectedMonth.month != requestedMonth.month) {
        return;
      }
      setState(() {
        monthlyWorkingDays = count;
        loadingMonthlyWorkingDays = false;
      });
    } catch (e) {
      debugPrint('MONTHLY WORKING DAYS LOAD ERROR: $e');
      if (!mounted ||
          selectedMonth.year != requestedMonth.year ||
          selectedMonth.month != requestedMonth.month) {
        return;
      }
      setState(() {
        monthlyWorkingDays = _workingDayCount(
          _recordsForMonth(requestedMonth),
        );
        loadingMonthlyWorkingDays = false;
      });
    }
  }

  // ============================================================
  // MONTH PICKER
  // ============================================================

  Future<void> _pickMonth() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      selectedMonth = DateTime(
        picked.year,
        picked.month,
        1,
      );
    });
    _loadMonthlyWorkingDays();
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: attendancePrimary,
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
      selectedDate = picked;
    });

    _calculateDay();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadAttendance(
      showLoading: false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: const RoyalAppBar(
        title: 'Attendance',
      ),
      body: RefreshIndicator(
        color: attendancePrimary,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _attendanceHeader(),
              const SizedBox(height: 18),
              _viewSelector(),
              const SizedBox(height: 18),
              if (errorMessage.isNotEmpty) _errorCard(),
              if (loading) _loadingCard(),
              if (!loading && view == 'Day') _dayView(),
              if (!loading && view == 'Month') _monthView(),
              if (!loading && view == 'Semester') _semesterView(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(
        currentIndex: 1,
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD2D2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.red,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppTheme.red,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outline,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: attendancePrimary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Loading attendance...',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _attendanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            attendancePrimary,
            attendanceDark,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22087F73),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your current attendance performance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _attendanceStatus(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _percentageCircle(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _headerStat(
                      icon: Icons.check_circle_rounded,
                      title: 'Present',
                      value: '$presentCount',
                    ),
                    const SizedBox(height: 9),
                    _headerStat(
                      icon: Icons.cancel_rounded,
                      title: 'Absent',
                      value: '$absentCount',
                    ),
                    const SizedBox(height: 9),
                    _headerStat(
                      icon: Icons.calendar_month_rounded,
                      title: 'Working Days',
                      value: '$totalCount',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE STATUS
  // ============================================================

  Widget _attendanceStatus() {
    final good = attendancePercentage >= 75;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: .12,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.trending_up_rounded : Icons.warning_amber_rounded,
            color: good ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            good ? 'Good' : 'Low',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN PERCENTAGE
  // ============================================================

  Widget _percentageCircle() {
    final double progress = (attendancePercentage / 100).clamp(
      0.0,
      1.0,
    );

    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.12,
                ),
                width: 1,
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: 112,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(
                alpha: 0.14,
              ),
              color: const Color(
                0xFF86EFAC,
              ),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.10,
                  ),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$attendancePercentage%',
                  style: const TextStyle(
                    color: attendancePrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Attendance',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
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
  // SMALL PERCENTAGE CIRCLE
  // ============================================================

  Widget _smallPercentageCircle({
    required int percentage,
    required bool darkBackground,
  }) {
    final double progress = (percentage / 100).clamp(0.0, 1.0);

    final Color backgroundRing = darkBackground
        ? Colors.white.withValues(
            alpha: .16,
          )
        : const Color(
            0xFFE4E7EB,
          );

    final Color progressColor = darkBackground
        ? const Color(
            0xFF86EFAC,
          )
        : attendancePrimary;

    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: backgroundRing,
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              color: progressColor,
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: darkBackground ? .12 : .06,
                  ),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$percentage%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: attendancePrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER STAT
  // ============================================================

  Widget _headerStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: .09,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIEW SELECTOR
  // ============================================================

  Widget _viewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.outline,
        ),
      ),
      child: Row(
        children: [
          _selectorButton('Day'),
          _selectorButton('Month'),
          _selectorButton('Semester'),
        ],
      ),
    );
  }

  Widget _selectorButton(
    String value,
  ) {
    final selected = view == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            view = value;
          });

          if (value == 'Day') {
            _calculateDay();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected ? attendancePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(
              11,
            ),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DAY VIEW
  // ============================================================

  Widget _dayView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Attendance',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Hour-wise attendance record',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(
                Icons.calendar_today_outlined,
                size: 15,
              ),
              label: const Text(
                'Date',
                style: TextStyle(
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _formattedDate(),
          style: const TextStyle(
            color: attendancePrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (dayClasses.isEmpty)
          _emptyCard(
            icon: Icons.event_busy_rounded,
            title: 'No attendance shahabas',
            message: 'No attendance has been recorded for ${_formattedDate()}.',
          )
        else
          ...dayClasses.asMap().entries.map(
                (entry) => _hourCard(
                  entry.key,
                  entry.value,
                ),
              ),
      ],
    );
  }

  // ============================================================
  // MONTH VIEW
  // ============================================================

  Widget _monthView() {
    final stats = _monthStats(
      selectedMonth,
    );

    final present = stats['present'] ?? 0;

    final half = stats['half'] ?? 0;

    final absent = stats['absent'] ?? 0;

    final total = monthlyWorkingDays;

    final percentage =
        total == 0 ? 0 : (((present + half * 0.5) / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Attendance',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Check your attendance month by month.',
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: AppTheme.outline,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                ),
                color: attendancePrimary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickMonth,
                  child: Column(
                    children: [
                      Text(
                        _monthName(
                          selectedMonth.month,
                        ),
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        '${selectedMonth.year}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
                color: attendancePrimary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (loadingMonthlyWorkingDays)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: attendancePrimary,
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (total == 0)
          _emptyCard(
            icon: Icons.calendar_month_rounded,
            title: 'No attendance recorded',
            message:
                'There are no attendance records for ${_monthName(selectedMonth.month)} ${selectedMonth.year}.',
          )
        else ...[
          _monthPercentageCard(
            percentage: percentage,
            present: present,
            half: half,
            absent: absent,
            total: total,
          ),
          const SizedBox(height: 16),
          const Text(
            'Monthly Summary',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Present',
            '$present',
            AppTheme.green,
          ),
          _summaryRow(
            'Half days',
            '$half',
            const Color(0xFFD18B16),
          ),
          _summaryRow(
            'Absent',
            '$absent',
            AppTheme.red,
          ),
          _summaryRow(
            'Working Days',
            '$total',
            attendancePrimary,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // MONTH PERCENTAGE CARD
  // ============================================================

  Widget _monthPercentageCard({
    required int percentage,
    required int present,
    required int half,
    required int absent,
    required int total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: AppTheme.outline,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _smallPercentageCircle(
            percentage: percentage,
            darkBackground: false,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthName(
                    selectedMonth.month,
                  ),
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${selectedMonth.year}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$present present • '
                  '$absent absent • '
                  '$total working days',
                  style: const TextStyle(
                    color: AppTheme.muted,
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
  // SEMESTER VIEW
  // ============================================================

  Widget _semesterView() {
    final percentage = attendancePercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Semester Attendance',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          student == null
              ? 'Current semester'
              : '${student!.course} • '
                  'Semester ${student!.semester}',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 14),
        if (totalCount == 0)
          _emptyCard(
            icon: Icons.school_outlined,
            title: 'No semester attendance',
            message:
                'No attendance has been recorded for your current semester yet.',
          )
        else ...[
          _semesterPercentageCard(
            percentage: percentage,
          ),
          const SizedBox(height: 16),
          const Text(
            'Semester Summary',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Present',
            '$presentCount',
            AppTheme.green,
          ),
          _summaryRow(
            'Half days',
            '$halfCount',
            const Color(0xFFD18B16),
          ),
          _summaryRow(
            'Absent',
            '$absentCount',
            AppTheme.red,
          ),
          _summaryRow(
            'Working Days',
            '$totalCount',
            attendancePrimary,
          ),
          const SizedBox(height: 18),
          const Text(
            'Month-wise Attendance',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _semesterMonthBreakdown(),
        ],
      ],
    );
  }

  // ============================================================
  // SEMESTER PERCENTAGE CARD
  // ============================================================

  Widget _semesterPercentageCard({
    required int percentage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            attendancePrimary,
            attendanceDark,
          ],
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: Row(
        children: [
          _smallPercentageCircle(
            percentage: percentage,
            darkBackground: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Semester Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  student == null
                      ? 'Current semester'
                      : 'Semester ${student!.semester}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$presentCount present • '
                  '$halfCount half • '
                  '$absentCount absent',
                  style: const TextStyle(
                    color: Colors.white70,
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
  // SEMESTER MONTH BREAKDOWN
  // ============================================================

  Widget _semesterMonthBreakdown() {
    final months = <String, List<Map<String, dynamic>>>{};
    for (final row in allAttendance) {
      final date = _attendanceDate(row);
      if (date == null) continue;
      final key = '${date.year}-${date.month}';
      months.putIfAbsent(key, () => []).add(row);
    }

    final monthList = months.entries.toList()
      ..sort((a, b) {
        final left = a.key.split('-').map(int.parse).toList();
        final right = b.key.split('-').map(int.parse).toList();
        return right[0] != left[0]
            ? right[0].compareTo(left[0])
            : right[1].compareTo(left[1]);
      });

    if (monthList.isEmpty) {
      return _emptyCard(
        icon: Icons.calendar_month_outlined,
        title: 'No monthly data',
        message:
            'Month-wise attendance will appear here once classes are recorded.',
      );
    }

    return Column(
      children: monthList.map((entry) {
        final parts = entry.key.split('-').map(int.parse).toList();
        final summary = _attendanceSummary(entry.value);
        return _semesterMonthCard(
          year: parts[0],
          month: parts[1],
          present: summary['present'] ?? 0,
          half: summary['half'] ?? 0,
          absent: summary['absent'] ?? 0,
          total: summary['total'] ?? 0,
          percentage: summary['percentage'] ?? 0,
        );
      }).toList(),
    );
  }

  // ============================================================
  // SEMESTER MONTH CARD
  // ============================================================

  Widget _semesterMonthCard({
    required int year,
    required int month,
    required int present,
    required int half,
    required int absent,
    required int total,
    required int percentage,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 9,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: AppTheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: attendanceLight,
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _monthName(
                    month,
                  ).substring(
                    0,
                    3,
                  ),
                  style: const TextStyle(
                    color: attendanceDark,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$year',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthName(
                    month,
                  ),
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$present present • '
                  '$half half • '
                  '$absent absent • '
                  '$total working days',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              color: percentage >= 75 ? AppTheme.green : AppTheme.red,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: AppTheme.outline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.muted,
            size: 30,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOUR CARD
  // ============================================================

  Widget _hourCard(
    int index,
    Map<String, dynamic> data,
  ) {
    final present = data['present'] == true;
    final status = '${data['status'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: present
              ? const Color(
                  0xFFD9F3E2,
                )
              : status == 'absent'
                  ? const Color(
                      0xFFFFDCDC,
                    )
                  : AppTheme.outline,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: attendanceLight,
              borderRadius: BorderRadius.circular(
                13,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data['hour'] ?? 'Hour',
                  style: const TextStyle(
                    color: attendanceDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: attendancePrimary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['subject'] ?? 'Class',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['faculty'] ?? 'Faculty',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data['time'] ?? '—',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(
            status,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    final present = status == 'present';
    final absent = status == 'absent';
    final color = present
        ? AppTheme.green
        : absent
            ? AppTheme.red
            : AppTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: present
            ? const Color(
                0xFFE8F8EE,
              )
            : absent
                ? const Color(
                    0xFFFFEAEA,
                  )
                : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            present
                ? Icons.check_circle_rounded
                : absent
                    ? Icons.cancel_rounded
                    : Icons.hourglass_empty_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            present
                ? 'Present'
                : absent
                    ? 'Absent'
                    : 'Not marked',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String title,
    String value,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color: AppTheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
