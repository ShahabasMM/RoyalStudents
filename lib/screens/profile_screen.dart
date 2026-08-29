import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentProfile? student;

  bool loading = true;

  String error = '';

  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    await _loadProfile();

    if (!mounted) return;

    _startRealtime();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final data =
          await StudentDataService.currentStudent();

      if (!mounted) return;

      setState(() {
        student = data;
        loading = false;
        error = '';
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint(
        'PROFILE LOAD ERROR: $e',
      );

      setState(() {
        student = null;
        loading = false;
        error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // REALTIME STUDENT DATA
  // ============================================================

  void _startRealtime() {
    final client =
        Supabase.instance.client;

    final user =
        client.auth.currentUser;

    if (user == null) {
      debugPrint(
        'PROFILE REALTIME: No authenticated user',
      );
      return;
    }

    // Remove previous channel if any.
    if (_profileChannel != null) {
      client.removeChannel(
        _profileChannel!,
      );
    }

    _profileChannel = client
        .channel(
          'profile-student-${user.id}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'students',
          filter: PostgresChangeFilter(
            type:
                PostgresChangeFilterType.eq,
            column: 'auth_user_id',
            value: user.id,
          ),
          callback: (
            payload,
          ) async {
            if (!mounted) return;

            debugPrint(
              'PROFILE REALTIME EVENT: ${payload.eventType}',
            );

            try {
              final fresh =
                  await StudentDataService
                      .currentStudent();

              if (!mounted) return;

              setState(() {
                student = fresh;
                error = '';
              });

              debugPrint(
                'PROFILE REALTIME: Profile refreshed',
              );
            } catch (e) {
              if (!mounted) return;

              debugPrint(
                'PROFILE REALTIME ERROR: $e',
              );

              // If the student row has been deleted,
              // keep the screen usable and show the
              // missing-profile state.
              setState(() {
                student = null;
                error = '';
              });
            }
          },
        )
        .subscribe(
          (status, error) {
            debugPrint(
              'PROFILE REALTIME STATUS: $status',
            );

            if (error != null) {
              debugPrint(
                'PROFILE REALTIME SUBSCRIBE ERROR: $error',
              );
            }
          },
        );
  }

  // ============================================================
  // STUDENT INITIAL
  // ============================================================

  String get _initial {
    final name =
        student?.name.trim() ?? '';

    if (name.isEmpty) {
      return 'S';
    }

    return name
        .substring(0, 1)
        .toUpperCase();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF8F2020,
                ),
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await StudentDataService
          .signOut();
    } catch (e) {
      debugPrint(
        'LOGOUT ERROR: $e',
      );
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
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
      backgroundColor:
          const Color(0xFFFCF8F8),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFFCF8F8),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color:
                Color(0xFF252525),
            fontSize: 20,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFF8F2020),
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  _loadProfile(
                showLoader: false,
              ),
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                children: [
                  // ==================================================
                  // ERROR
                  // ==================================================

                  if (error.isNotEmpty)
                    _errorCard(),

                  // ==================================================
                  // PROFILE FOUND
                  // ==================================================

                  if (student != null) ...[
                    _profileHeader(),

                    const SizedBox(
                      height: 18,
                    ),

                    _detailsCard(),

                    const SizedBox(
                      height: 22,
                    ),
                  ],

                  // ==================================================
                  // PROFILE NOT FOUND
                  // ==================================================

                  if (student == null)
                    _profileNotFoundCard(),

                  // ==================================================
                  // LOGOUT
                  //
                  // IMPORTANT:
                  // This is OUTSIDE student != null.
                  // So logout ALWAYS appears.
                  // ==================================================

                  const SizedBox(
                    height: 18,
                  ),

                  _logoutButton(),

                  const SizedBox(
                    height: 12,
                  ),
                ],
              ),
            ),

      // ========================================================
      // BOTTOM NAV
      // ========================================================

      bottomNavigationBar:
          const BottomNav(
        currentIndex: 4,
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _profileHeader() {
    final name =
        student!.name.trim().isEmpty
            ? 'Student'
            : student!.name.trim();

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        22,
      ),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF8F2020),
            Color(0xFFB43A3A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(0x22000000),
            blurRadius: 14,
            offset:
                Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ======================================================
          // LETTER AVATAR
          // ======================================================

          Container(
            width: 94,
            height: 94,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Colors.white,
              border:
                  Border.all(
                color:
                    Colors.white,
                width: 4,
              ),
              boxShadow:
                  const [
                BoxShadow(
                  color:
                      Color(0x30000000),
                  blurRadius: 12,
                  offset:
                      Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initial,
                style:
                    GoogleFonts.roboto(
                  color:
                      const Color(
                    0xFF8F2020,
                  ),
                  fontSize: 40,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          // ======================================================
          // STUDENT NAME
          // ======================================================

          Text(
            name,
            textAlign:
                TextAlign.center,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.roboto(
              color:
                  Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w900,
              height: 1.05,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          // ======================================================
          // COURSE
          // ======================================================

          Text(
            student!.course.isEmpty
                ? 'Student'
                : student!.course,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white70,
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ======================================================
          // PROFILE LABEL
          // ======================================================

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: .14,
              ),
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              border:
                  Border.all(
                color:
                    Colors.white24,
              ),
            ),
            child: const Text(
              'STUDENT PROFILE',
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAILS CARD
  // ============================================================

  Widget _detailsCard() {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE8DADA,
          ),
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(0x0D000000),
            blurRadius: 10,
            offset:
                Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Details',
            style:
                TextStyle(
              color:
                  Color(0xFF252525),
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          _detail(
            'Student Name',
            student!.name,
            Icons
                .person_outline_rounded,
          ),

          _detail(
            'Registration Number',
            student!.regNo,
            Icons
                .confirmation_number_outlined,
          ),

          _detail(
            'Admission Number',
            student!.admissionNo,
            Icons
                .badge_outlined,
          ),

          _detail(
            'CAP ID',
            student!.capId,
            Icons
                .fingerprint_rounded,
          ),

          _detail(
            'Course',
            student!.course,
            Icons
                .school_outlined,
          ),

          _detail(
            'Semester',
            'Semester ${student!.semester}',
            Icons
                .menu_book_outlined,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detail(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFAFAFA),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border:
            Border.all(
          color:
              const Color(0xFFF0E8E8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFFFEEEE,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  const Color(
                0xFF8F2020,
              ),
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF94A3B8,
                    ),
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value.isEmpty
                      ? 'Not available'
                      : value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF252525,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
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
  // PROFILE NOT FOUND
  // ============================================================

  Widget _profileNotFoundCard() {
    return Container(
      padding:
          const EdgeInsets.all(
        24,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE8DADA,
          ),
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(0x0D000000),
            blurRadius: 10,
            offset:
                Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ======================================================
          // ICON
          // ======================================================

          Container(
            width: 64,
            height: 64,
            decoration:
                const BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  Color(0xFFFFEEEE),
            ),
            child: const Icon(
              Icons
                  .person_off_outlined,
              size: 30,
              color:
                  Color(0xFF8F2020),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'Student Profile Not Found',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Color(0xFF252525),
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Your student profile is not available right now. Please contact the college administrator.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Color(0xFF7A7A7A),
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // ======================================================
          // RETRY
          // ======================================================

          SizedBox(
            height: 44,
            child:
                OutlinedButton.icon(
              onPressed: () =>
                  _loadProfile(
                showLoader: false,
              ),
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
                size: 17,
              ),
              label:
                  const Text(
                'Refresh Profile',
                style:
                    TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF8F2020,
                ),
                side:
                    const BorderSide(
                  color:
                      Color(0xFF8F2020),
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _logoutButton() {
    return SizedBox(
      width:
          double.infinity,
      height: 50,
      child:
          OutlinedButton.icon(
        onPressed: _logout,
        icon:
            const Icon(
          Icons.logout_rounded,
          size: 18,
        ),
        label:
            const Text(
          'Logout',
          style:
              TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              const Color(
            0xFF8F2020,
          ),
          side:
              const BorderSide(
            color:
                Color(0xFF8F2020),
            width: 1.2,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _errorCard() {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 15,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF1F2),
        borderRadius:
            BorderRadius.circular(
          11,
        ),
        border:
            Border.all(
          color:
              const Color(0xFFFECACA),
        ),
      ),
      child: Text(
        error,
        style:
            const TextStyle(
          color:
              Color(0xFFBE123C),
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_profileChannel != null) {
      Supabase.instance.client
          .removeChannel(
        _profileChannel!,
      );

      _profileChannel = null;
    }

    super.dispose();
  }
}