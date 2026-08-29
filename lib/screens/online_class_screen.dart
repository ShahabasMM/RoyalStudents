import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class OnlineClassScreen extends StatefulWidget {
  const OnlineClassScreen({super.key});

  @override
  State<OnlineClassScreen> createState() => _OnlineClassScreenState();
}

class _OnlineClassScreenState extends State<OnlineClassScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0F5C55);
  static const Color lightGreen = Color(0xFFDDF7F3);
  static const Color background = Color(0xFFF5FBFA);
  static const Color textDark = Color(0xFF172033);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFDCEDEB);

  // ============================================================
  // STATE
  // ============================================================

  StudentProfile? student;

  List<Map<String, dynamic>> classes = [];

  bool loading = true;
  bool refreshingRealtime = false;

  String error = '';
  String success = '';

  RealtimeChannel? _onlineClassesChannel;

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
    final channel = _onlineClassesChannel;
    _onlineClassesChannel = null;

    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }

    super.dispose();
  }

  // ============================================================
  // INITIAL / MANUAL LOAD
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

      final data = await StudentDataService.onlineClasses(s);

      if (!mounted) return;

      setState(() {
        student = s;
        classes = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = _cleanError(e);
        loading = false;
      });
    }
  }

  // ============================================================
  // REALTIME
  //
  // Admin can:
  //   scheduled -> live
  //   live      -> completed
  //   edit class
  //   delete class
  //
  // Student app reloads automatically.
  // ============================================================

  void _setupRealtime() {
    final client = Supabase.instance.client;

    _onlineClassesChannel = client.channel(
      'student-online-classes-${DateTime.now().microsecondsSinceEpoch}',
    );

    _onlineClassesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'online_classes',
          callback: (payload) {
            if (!mounted || refreshingRealtime) {
              return;
            }

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
  // JOIN
  //
  // IMPORTANT:
  // Student can ONLY join when admin has changed status
  // to "live".
  // ============================================================

  Future<void> _join(
    Map<String, dynamic> row,
  ) async {
    final status = _status(row);

    if (status != 'LIVE') {
      _showError(
        'This class has not started yet.',
      );
      return;
    }

    final link = _value(
      row,
      [
        'meeting_url',
        'meeting_link',
        'meetingLink',
        'link',
        'url',
      ],
    ).trim();

    if (link.isEmpty) {
      _showError(
        'Meeting link is not available yet.',
      );
      return;
    }

    final uri = Uri.tryParse(link);

    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showError(
        'Invalid meeting link.',
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showError(
          'Unable to open the meeting link.',
        );
      }
    } catch (e) {
      _showError(
        'Unable to open the meeting.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _value(
    Map<String, dynamic> row,
    List<String> keys, [
    String fallback = '',
  ]) {
    return StudentDataService.value(
      row,
      keys,
      fallback,
    );
  }

  String _status(
    Map<String, dynamic> row,
  ) {
    return _value(
      row,
      ['status'],
      'scheduled',
    ).trim().toUpperCase();
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst(
          'PostgrestException(message: ',
          '',
        )
        .replaceAll(
          RegExp(r', code:.*'),
          '',
        )
        .replaceAll(
          RegExp(r'\)$'),
          '',
        );
  }

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
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Online Classes',
          style: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primary,
        onRefresh: () => _load(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            30,
          ),
          children: [
            _header(),
            const SizedBox(height: 20),
            if (error.isNotEmpty)
              _alert(
                error,
                isError: true,
              ),
            if (success.isNotEmpty)
              _alert(
                success,
                isError: false,
              ),
            _sectionHeader(),
            const SizedBox(height: 13),
            if (loading)
              _loading()
            else if (classes.isEmpty)
              _empty()
            else
              ...classes.map(_card),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryDark,
            primary,
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F766E),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.video_camera_front_outlined,
            color: Colors.white,
            size: 33,
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Online Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Join your scheduled virtual classes.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
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
    final course = student?.course ?? 'Loading...';

    final semester = student == null ? '' : ' • Semester ${student!.semester}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Classes',
                style: TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$course$semester',
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (refreshingRealtime)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: primary,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card(
    Map<String, dynamic> row,
  ) {
    final title = _value(
      row,
      ['title', 'subject', 'name'],
      'Online Class',
    );

    final subject = _value(
      row,
      ['subject', 'subject_name'],
    );

    final faculty = _value(
      row,
      [
        'teacher_name',
        'faculty',
        'faculty_name',
        'teacher',
      ],
      'Faculty',
    );

    final date = _value(
      row,
      ['scheduled_date', 'date', 'class_date'],
    );

    final start = _value(
      row,
      ['start_time', 'startTime'],
    );

    final end = _value(
      row,
      ['end_time', 'endTime'],
    );

    final description = _value(
      row,
      ['description', 'details'],
    );

    final status = _status(row);

    final isLive = status == 'LIVE';
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isLive ? const Color(0xFF8BD8CE) : border,
          width: isLive ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive ? const Color(0x120F766E) : const Color(0x08000000),
            blurRadius: isLive ? 13 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // STATUS + DATE
          // ------------------------------------------------------

          Row(
            children: [
              _statusBadge(
                status,
                isLive: isLive,
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 11),

          // ------------------------------------------------------
          // TITLE
          // ------------------------------------------------------

          Text(
            title,
            style: const TextStyle(
              color: textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),

          if (subject.isNotEmpty &&
              subject.toLowerCase() != title.toLowerCase()) ...[
            const SizedBox(height: 4),
            Text(
              subject,
              style: const TextStyle(
                color: textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 7),

          // ------------------------------------------------------
          // FACULTY
          // ------------------------------------------------------

          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  faculty,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          // ------------------------------------------------------
          // TIME
          // ------------------------------------------------------

          if (start.isNotEmpty || end.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: primary,
                ),
                const SizedBox(width: 5),
                Text(
                  _formatTimeRange(
                    start,
                    end,
                  ),
                  style: const TextStyle(
                    color: primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],

          // ------------------------------------------------------
          // DESCRIPTION
          // ------------------------------------------------------

          if (description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              description,
              style: const TextStyle(
                color: textMuted,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],

          // ------------------------------------------------------
          // JOIN AREA
          //
          // ONLY LIVE => Join button
          // SCHEDULED => Waiting message
          // COMPLETED => Finished
          // CANCELLED => Cancelled
          // ------------------------------------------------------

          const SizedBox(height: 13),

          if (isLive)
            _joinButton(row)
          else if (isCompleted)
            _infoButton(
              icon: Icons.check_circle_outline_rounded,
              text: 'Class Completed',
            )
          else if (isCancelled)
            _infoButton(
              icon: Icons.cancel_outlined,
              text: 'Class Cancelled',
            )
          else
            _waitingButton(),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String status, {
    required bool isLive,
  }) {
    String label;

    Color backgroundColor;
    Color foregroundColor;

    switch (status) {
      case 'LIVE':
        label = 'LIVE NOW';
        backgroundColor = const Color(0xFFDDF7F3);
        foregroundColor = primary;
        break;

      case 'COMPLETED':
        label = 'COMPLETED';
        backgroundColor = const Color(0xFFEFF6FF);
        foregroundColor = const Color(0xFF2563EB);
        break;

      case 'CANCELLED':
        label = 'CANCELLED';
        backgroundColor = const Color(0xFFFFF1F2);
        foregroundColor = const Color(0xFFBE123C);
        break;

      default:
        label = 'UPCOMING';
        backgroundColor = const Color(0xFFF1F5F9);
        foregroundColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // JOIN BUTTON
  // ============================================================

  Widget _joinButton(
    Map<String, dynamic> row,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () => _join(row),
        icon: const Icon(
          Icons.video_call_rounded,
          size: 18,
        ),
        label: const Text(
          'Join Google Meet',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x400F766E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WAITING BUTTON
  // ============================================================

  Widget _waitingButton() {
    return Container(
      width: double.infinity,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: textMuted,
          ),
          SizedBox(width: 7),
          Text(
            'Waiting for class to start',
            style: TextStyle(
              color: textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO BUTTON
  // ============================================================

  Widget _infoButton({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: textMuted,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALERT
  // ============================================================

  Widget _alert(
    String text, {
    required bool isError,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFE7F8F1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: isError ? const Color(0xFFBE123C) : const Color(0xFF047857),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    isError ? const Color(0xFFBE123C) : const Color(0xFF047857),
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
              size: 15,
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

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 42,
        horizontal: 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFF111827),
          width: 1.05,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.video_camera_front_outlined,
            size: 38,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 11),
          Text(
            'No online classes',
            style: TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Your scheduled classes will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
    String value,
  ) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
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
  // TIME
  // ============================================================

  String _formatTimeRange(
    String start,
    String end,
  ) {
    final startText = _formatTime(start);

    if (end.trim().isEmpty) {
      return startText;
    }

    return '$startText — ${_formatTime(end)}';
  }

  String _formatTime(
    String value,
  ) {
    final parts = value.split(':');

    if (parts.length < 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final date = DateTime(
      2026,
      1,
      1,
      hour,
      minute,
    );

    return TimeOfDay.fromDateTime(date).format(context);
  }
}
