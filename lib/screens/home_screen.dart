import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/student_data_service.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StudentProfile? student;

  RealtimeChannel? _studentChannel;

  int _avatarVersion = 0;

  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();

    _initialize();

    // Keep the greeting updated while the app
    // remains open.
    _greetingTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // =============================================================
  // INITIALIZE
  // =============================================================

  Future<void> _initialize() async {
    await _loadStudent();

    if (!mounted) return;

    _startRealtime();
  }

  // =============================================================
  // LOAD STUDENT
  // =============================================================

  Future<void> _loadStudent() async {
    try {
      final profile = await StudentDataService.currentStudent();

      if (!mounted) return;

      debugPrint(
        'HOME DB AVATAR: "${profile.avatarUrl}"',
      );

      setState(() {
        student = profile;
        _avatarVersion++;
      });
    } catch (e) {
      debugPrint(
        'HOME LOAD ERROR: $e',
      );
    }
  }

  // =============================================================
  // REALTIME
  // =============================================================

  void _startRealtime() {
    final client = Supabase.instance.client;

    final user = client.auth.currentUser;

    if (user == null) return;

    if (_studentChannel != null) {
      client.removeChannel(
        _studentChannel!,
      );
    }

    _studentChannel = client
        .channel(
          'home-student-${user.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'students',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'auth_user_id',
            value: user.id,
          ),
          callback: (
            payload,
          ) async {
            if (!mounted) return;

            debugPrint(
              'HOME STUDENT REALTIME UPDATE',
            );

            try {
              final refreshed = await StudentDataService.currentStudent();

              if (!mounted) return;

              debugPrint(
                'HOME FRESH AVATAR: "${refreshed.avatarUrl}"',
              );

              setState(() {
                student = refreshed;
                _avatarVersion++;
              });
            } catch (e) {
              debugPrint(
                'HOME REALTIME ERROR: $e',
              );
            }
          },
        )
        .subscribe(
      (status, error) {
        debugPrint(
          'HOME REALTIME STATUS: $status',
        );

        if (error != null) {
          debugPrint(
            'HOME REALTIME ERROR: $error',
          );
        }
      },
    );
  }

  // =============================================================
  // DYNAMIC GREETING
  // =============================================================

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    }

    if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    }

    if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    }

    return 'Good Night';
  }

  // =============================================================
  // DISPOSE
  // =============================================================

  @override
  void dispose() {
    _greetingTimer?.cancel();

    if (_studentChannel != null) {
      Supabase.instance.client.removeChannel(
        _studentChannel!,
      );

      _studentChannel = null;
    }

    super.dispose();
  }

  // =============================================================
  // WEBSITE
  // =============================================================

  Future<void> _openWebsite() async {
    final Uri url = Uri.parse(
      'https://www.myroyalcollege.com/',
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception(
        'Could not open website',
      );
    }
  }

  // =============================================================
  // NAVIGATION
  // =============================================================

  void _open(
    BuildContext context,
    String route,
  ) {
    Navigator.pushNamed(
      context,
      route,
    );
  }

  // =============================================================
  // INITIAL
  // =============================================================

  String get _studentInitial {
    final name = student?.name.trim() ?? '';

    if (name.isEmpty) {
      return 'S';
    }

    return name.substring(0, 1).toUpperCase();
  }

  // =============================================================
  // AVATAR URL
  // =============================================================

  String get _avatarUrl => '';

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // =========================================================
      // APP BAR
      // =========================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/RoyalLogo.png',
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Center(
                    child: Text(
                      'RC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Royal College',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    '$_greeting, ${student?.name ?? 'Student'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(
                        0xFF424757,
                      ),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.navy,
              ),
            ),

            const SizedBox(
              width: 2,
            ),

            // =====================================================
            // HOME PROFILE AVATAR
            // =====================================================

            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/profile',
                );
              },
              child: CircleAvatar(
                key: ValueKey(
                  'home-avatar-$_avatarVersion-$_avatarUrl',
                ),
                radius: 18,
                backgroundColor: AppTheme.softPurple,
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(
                        _avatarUrl,
                      )
                    : null,
                child: _avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        _studentInitial,
                        style: const TextStyle(
                          color: AppTheme.purple,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),

      // =========================================================
      // BODY
      // =========================================================

      body: RefreshIndicator(
        onRefresh: _loadStudent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _studentIdCard(),
              const SizedBox(
                height: 16,
              ),
              Row(
                children: [
                  Expanded(
                    child: _bigActionCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Pay Fee',
                      subtitle: 'Manage your fees',
                      cardColor: const Color.fromARGB(
                        255,
                        120,
                        18,
                        18,
                      ),
                      iconBackground: const Color(
                        0xFFE8F0FF,
                      ),
                      iconColor: const Color.fromARGB(
                        255,
                        120,
                        18,
                        18,
                      ),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: _bigActionCard(
                      icon: Icons.language_rounded,
                      title: 'Website',
                      subtitle: 'Visit college website',
                      cardColor: const Color.fromARGB(255, 252, 248, 231),
                      iconBackground: const Color(
                        0xFFD8F3E5,
                      ),
                      iconColor: const Color(
                        0xFF16845B,
                      ),
                      onTap: _openWebsite,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(
                          height: 4,
                        ),
                        Text(
                          'Everything you need in one place',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFFE2E8F0,
                        ),
                      ),
                    ),
                    child: const Text(
                      '8 Modules',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 11,
              ),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 11,
                childAspectRatio: 1.18,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _dashboardCard(
                    title: 'Attendance',
                    subtitle: 'Track your attendance',
                    icon: Icons.fact_check_rounded,
                    iconColor: const Color(
                      0xFF2563EB,
                    ),
                    backgroundColor: const Color(
                      0xFFEAF2FF,
                    ),
                    borderColor: const Color(
                      0xFFBFDBFE,
                    ),
                    onTap: () => _open(
                      context,
                      '/attendance',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Timetable',
                    subtitle: 'View daily schedule',
                    icon: Icons.calendar_month_rounded,
                    iconColor: const Color(
                      0xFF7C3AED,
                    ),
                    backgroundColor: const Color(
                      0xFFF1E9FF,
                    ),
                    borderColor: const Color(
                      0xFFDDD0FF,
                    ),
                    onTap: () => _open(
                      context,
                      '/timetable',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Syllabus',
                    subtitle: 'Course curriculum',
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(
                      0xFFB45309,
                    ),
                    backgroundColor: const Color(
                      0xFFFFF3DC,
                    ),
                    borderColor: const Color(
                      0xFFF6DFA9,
                    ),
                    onTap: () => _open(
                      context,
                      '/syllabus',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Library',
                    subtitle: 'Books & resources',
                    icon: Icons.local_library_rounded,
                    iconColor: const Color(
                      0xFF059669,
                    ),
                    backgroundColor: const Color(
                      0xFFE7F8F1,
                    ),
                    borderColor: const Color(
                      0xFFBCE8D5,
                    ),
                    onTap: () => _open(
                      context,
                      '/library',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Ask Doubts',
                    subtitle: 'Ask your questions',
                    icon: Icons.question_answer_rounded,
                    iconColor: const Color(
                      0xFFDB2777,
                    ),
                    backgroundColor: const Color(
                      0xFFFFEAF4,
                    ),
                    borderColor: const Color(
                      0xFFFBCFE3,
                    ),
                    onTap: () => _open(
                      context,
                      '/doubts',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Announcements',
                    subtitle: 'Latest updates',
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(
                      0xFFBE3A3A,
                    ),
                    backgroundColor: const Color(
                      0xFFFFEEEE,
                    ),
                    borderColor: const Color(
                      0xFFF5C2C2,
                    ),
                    onTap: () => _open(
                      context,
                      '/announcements',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Leave Apply',
                    subtitle: 'Request your leave',
                    icon: Icons.event_note_rounded,
                    iconColor: const Color(
                      0xFF0891B2,
                    ),
                    backgroundColor: const Color(
                      0xFFE5F8FB,
                    ),
                    borderColor: const Color(
                      0xFFBCEBF2,
                    ),
                    onTap: () => _open(
                      context,
                      '/leave',
                    ),
                  ),
                  _dashboardCard(
                    title: 'Online Class',
                    subtitle: 'Join virtual classes',
                    icon: Icons.video_camera_front_rounded,
                    iconColor: const Color(
                      0xFF0F766E,
                    ),
                    backgroundColor: const Color(
                      0xFFE5F7F4,
                    ),
                    borderColor: const Color(
                      0xFFB9E9E2,
                    ),
                    onTap: () => _open(
                      context,
                      '/online-class',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const BottomNav(
        currentIndex: 0,
      ),
    );
  }

  // =============================================================
  // STUDENT ID CARD
  // =============================================================

  Widget _studentIdCard() {
    final name = student?.name.trim().isNotEmpty == true
        ? student!.name.trim()
        : 'Student Name';

    final regNo =
        student?.regNo.trim().isNotEmpty == true ? student!.regNo.trim() : '—';

    final admissionNo = student?.admissionNo.trim().isNotEmpty == true
        ? student!.admissionNo.trim()
        : '—';

    final course = student?.course.trim().isNotEmpty == true
        ? student!.course.trim()
        : '—';

    final semester = student != null ? 'Semester ${student!.semester}' : '—';

    final capId =
        student?.capId.trim().isNotEmpty == true ? student!.capId.trim() : '—';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(
          0xFFF7F5EC,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFF1F2937,
          ),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x22000000,
            ),
            blurRadius: 12,
            offset: Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          18,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -35,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF7A1F2B,
                    ).withValues(
                      alpha: .08,
                    ),
                    width: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -45,
              bottom: -55,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF7A1F2B,
                    ).withValues(
                      alpha: .06,
                    ),
                    width: 20,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 13,
                  ),
                  Container(
                    height: 1,
                    color: const Color(
                      0xFFD8D3C6,
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Center(
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.righteous(
                        color: const Color(
                          0xFF111827,
                        ),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  const Center(
                    child: Text(
                      'STUDENT',
                      style: TextStyle(
                        color: Color(
                          0xFF7A1F2B,
                        ),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _idCardDetail(
                          'REG. NO',
                          regNo,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: _idCardDetail(
                          'ADMISSION NO',
                          admissionNo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _idCardDetail(
                          'COURSE',
                          course,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: _idCardDetail(
                          'SEMESTER',
                          semester,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _idCardDetail(
                    'CAP ID',
                    capId,
                    fullWidth: true,
                  ),
                  const SizedBox(
                    height: 13,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF7A1F2B,
                            ),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(
                            0xFF7A1F2B,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF7A1F2B,
                            ),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // ID DETAIL
  // =============================================================

  Widget _idCardDetail(
    String label,
    String value, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFEFEDE4,
        ),
        borderRadius: BorderRadius.circular(
          9,
        ),
        border: Border.all(
          color: const Color(
            0xFFD8D3C6,
          ),
          width: .9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(
                0xFF737373,
              ),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .45,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(
                0xFF172033,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // BIG ACTION CARD
  // =============================================================

  Widget _bigActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required Color iconBackground,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final darkCard = cardColor.computeLuminance() < .35;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            17,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(
                0xFF6B7280,
              ),
              blurRadius: 0,
              offset: Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(
              17,
            ),
            border: Border.all(
              color: const Color(
                0xFF1F2937,
              ),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 19,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: darkCard ? Colors.white : AppTheme.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: darkCard ? Colors.white70 : AppTheme.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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

  // =============================================================
  // DASHBOARD CARD
  // =============================================================

  Widget _dashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return _PressableDashboardCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      onTap: onTap,
    );
  }
}

// =================================================================
// PRESSABLE CARD
// =================================================================

class _PressableDashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _PressableDashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_PressableDashboardCard> createState() =>
      _PressableDashboardCardState();
}

class _PressableDashboardCardState extends State<_PressableDashboardCard> {
  bool _pressed = false;

  Future<void> _handleTap() async {
    if (_pressed) return;

    setState(() {
      _pressed = true;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    if (!mounted) return;

    setState(() {
      _pressed = false;
    });

    widget.onTap();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 100,
        ),
        transform: Matrix4.translationValues(
          0,
          _pressed ? 4 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            16,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF6B7280,
              ),
              blurRadius: 0,
              offset: Offset(
                0,
                _pressed ? 1 : 4,
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: const Color(
                0xFF1F2937,
              ),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                    border: Border.all(
                      color: widget.borderColor,
                      width: 1.1,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 34,
                    color: widget.iconColor,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
