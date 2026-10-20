import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/doubts_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/library_screen.dart';
import 'screens/syllabus_screen.dart';
import 'screens/leave_apply_screen.dart';
import 'screens/online_class_screen.dart';
import 'screens/internal_marks_screen.dart';
import 'screens/results_screen.dart';
import 'screens/addon_courses_screen.dart';
import 'screens/fee_stats_screen.dart';
import 'theme/app_theme.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // SUPABASE INITIALIZATION
  // ============================================================

  await Supabase.initialize(
    url: 'https://mjkyncdqagdhgfzwqkko.supabase.co',
    publishableKey: 'sb_publishable_8kSWCn8IXEFIfuJ8CKwEiw_uEsLehgP',
  );

  runApp(const RoyalCollegeApp());
}

// ============================================================
// GLOBAL SUPABASE CLIENT
// ============================================================

final supabase = Supabase.instance.client;

// ============================================================
// ROYAL COLLEGE APP
// ============================================================

class RoyalCollegeApp extends StatelessWidget {
  const RoyalCollegeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Royal College Student',

      // ========================================================
      // GLOBAL THEME + POPPINS
      // ========================================================

      theme: AppTheme.theme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          AppTheme.theme.textTheme,
        ),
      ),

      // ========================================================
      // AUTH INITIAL ROUTE
      // ========================================================

      home: const SplashScreen(),

      // ========================================================
      // ROUTES
      // ========================================================

      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/attendance': (_) => const AttendanceScreen(),
        '/timetable': (_) => const TimetableScreen(),
        '/doubts': (_) => const DoubtsScreen(),
        '/announcements': (_) => const AnnouncementsScreen(),
        '/library': (_) => const LibraryScreen(),
        '/syllabus': (_) => const SyllabusScreen(),
        '/leave': (_) => const LeaveApplyScreen(),
        '/online-class': (_) => const OnlineClassScreen(),
        '/internal-marks': (_) => const InternalMarksScreen(),
        '/results': (_) => const ResultsScreen(),
        '/addon-courses': (_) => const AddonCoursesScreen(),
        '/fee-stats': (_) => const FeeStatsScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // ------------------------------------------------------
        // Check current session
        // ------------------------------------------------------

        final session = supabase.auth.currentSession;

        // ------------------------------------------------------
        // User is logged in
        // ------------------------------------------------------

        if (session != null) {
          return const HomeScreen();
        }

        // ------------------------------------------------------
        // User is not logged in
        // ------------------------------------------------------

        return const LoginScreen();
      },
    );
  }
}
