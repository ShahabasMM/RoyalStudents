import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/student_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';

class AddonCoursesScreen extends StatefulWidget {
  const AddonCoursesScreen({super.key});

  @override
  State<AddonCoursesScreen> createState() => _AddonCoursesScreenState();
}

class _AddonCoursesScreenState extends State<AddonCoursesScreen> {
  static const Color primary = AppTheme.navy;
  static const Color background = AppTheme.background;
  static const Color border = AppTheme.outline;
  static const Color accent = AppTheme.purple;

  StudentProfile? student;
  List<Map<String, dynamic>> availableCourses = [];
  List<Map<String, dynamic>> enrollments = [];
  bool loading = true;
  bool refreshing = false;
  bool showingYourCourses = false;
  String joiningCourseId = '';
  String error = '';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = availableCourses.isEmpty && enrollments.isEmpty;
        error = '';
      });
    }

    try {
      final profile = student ?? await StudentDataService.currentStudent();
      final results = await Future.wait([
        StudentDataService.addonCourses(),
        StudentDataService.addonCourseEnrollments(profile),
      ]);
      if (!mounted) return;
      setState(() {
        student = profile;
        availableCourses = results[0];
        enrollments = results[1];
        loading = false;
      });
      _subscribe(profile.id);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  void _subscribe(String studentId) {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('student-addon-courses-$studentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'addon_course_enrollments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (_) => _refreshRealtime(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'addon_courses',
          callback: (_) => _refreshRealtime(),
        )
        .subscribe();
  }

  Future<void> _refreshRealtime() async {
    if (!mounted || refreshing) return;
    refreshing = true;
    try {
      final profile = student ?? await StudentDataService.currentStudent();
      final results = await Future.wait([
        StudentDataService.addonCourses(),
        StudentDataService.addonCourseEnrollments(profile),
      ]);
      if (mounted) {
        setState(() {
          availableCourses = results[0];
          enrollments = results[1];
        });
      }
    } catch (_) {
      // Keep the last successfully loaded list visible during a transient issue.
    } finally {
      refreshing = false;
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    super.dispose();
  }

  Map<String, dynamic> _course(Map<String, dynamic> row) {
    final raw = row['addon_courses'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return row;
  }

  Set<String> get _enrolledCourseIds => enrollments
      .map((row) => _text(row, 'addon_course_id'))
      .where((id) => id.isNotEmpty)
      .toSet();

  Future<void> _addToCourse(Map<String, dynamic> course) async {
    final profile = student;
    final id = _text(course, 'id');
    if (profile == null || id.isEmpty || joiningCourseId.isNotEmpty) return;

    setState(() {
      joiningCourseId = id;
      error = '';
    });
    try {
      await StudentDataService.enrollInAddonCourse(profile, id);
      final updatedEnrollments =
          await StudentDataService.addonCourseEnrollments(profile);
      if (!mounted) return;
      setState(() {
        enrollments = updatedEnrollments;
        showingYourCourses = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${_text(course, 'name', 'Course')} added to Your Courses.')),
      );
    } catch (exception) {
      if (!mounted) return;
      final message = exception.toString().replaceFirst('Exception: ', '');
      setState(() => error = message.contains('23505')
          ? 'You have already added this course.'
          : message);
    } finally {
      if (mounted) setState(() => joiningCourseId = '');
    }
  }

  String _text(Map<String, dynamic> row, String key, [String fallback = '']) {
    final value = row[key];
    return value == null ? fallback : value.toString().trim();
  }

  Widget _courseCard(Map<String, dynamic> course,
      {required bool enrolled, DateTime? enrolledAt}) {
    final name = _text(course, 'name', 'Add on Course');
    final description = _text(course, 'description');
    final duration = _text(course, 'duration');
    final mode = _text(course, 'mode');
    final fee = course['fee'];
    final courseId = _text(course, 'id');
    final joining = joiningCourseId == courseId;
    final modeIcon = mode.toLowerCase() == 'online'
        ? Icons.wifi_rounded
        : Icons.location_on_outlined;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0B082B6F), blurRadius: 18, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      enrolled ? const Color(0xFFEAF8F0) : AppTheme.softPurple,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  enrolled ? Icons.school_rounded : Icons.auto_stories_rounded,
                  color: enrolled ? AppTheme.green : accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 15,
                      height: 1.22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (fee is num) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5FA),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    fee == 0
                        ? 'Free'
                        : '₹${fee.toStringAsFixed(fee % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ],
          if (duration.isNotEmpty || mode.isNotEmpty || enrolledAt != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: border),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (duration.isNotEmpty) _tag(Icons.schedule_rounded, duration),
                if (mode.isNotEmpty) _tag(modeIcon, mode),
                if (enrolledAt != null)
                  _tag(
                    Icons.check_circle_outline_rounded,
                    'Joined ${enrolledAt.day}/${enrolledAt.month}/${enrolledAt.year}',
                    color: AppTheme.green,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: enrolled
                ? Container(
                    height: 43,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F0),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: AppTheme.green),
                        SizedBox(width: 8),
                        Text(
                          'You are enrolled',
                          style: TextStyle(
                            color: AppTheme.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    onPressed: joiningCourseId.isNotEmpty
                        ? null
                        : () => _addToCourse(course),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      disabledBackgroundColor: const Color(0xFF8B9AB5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: joining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 19),
                    label: Text(
                      joining ? 'Adding course...' : 'Add to Course',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String label, {Color color = primary}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _courseTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08082B6F), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _courseTab(
            selected: !showingYourCourses,
            label: 'All Courses',
            count: availableCourses.length,
            icon: Icons.grid_view_rounded,
            onTap: () => setState(() => showingYourCourses = false),
          ),
          _courseTab(
            selected: showingYourCourses,
            label: 'Your Courses',
            count: enrollments.length,
            icon: Icons.school_rounded,
            onTap: () => setState(() => showingYourCourses = true),
          ),
        ],
      ),
    );
  }

  Widget _courseTab({
    required bool selected,
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label, $count courses',
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x22082B6F),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 17, color: selected ? Colors.white : AppTheme.muted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 21),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0x33FFFFFF)
                        : AppTheme.softPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = student;
    return Scaffold(
      backgroundColor: background,
      appBar: const RoyalAppBar(title: 'Add on Courses'),
      body: RefreshIndicator(
        color: primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.navyDark, AppTheme.navy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(21),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26082B6F),
                      blurRadius: 18,
                      offset: Offset(0, 7)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .14)),
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expand your skills',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          profile == null
                              ? 'Find a course to grow your skills'
                              : '${profile.course}  ·  Semester ${profile.semester}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFFDCE5F6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _courseTabs(),
            const SizedBox(height: 17),
            if (error.isNotEmpty)
              _stateCard(error, Icons.error_outline_rounded,
                  const Color(0xFFB42318), const Color(0xFFFFF2F0)),
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(36),
                  child:
                      Center(child: CircularProgressIndicator(color: primary)))
            else if (showingYourCourses && enrollments.isEmpty)
              _stateCard('No Add on Courses have been added to your list yet.',
                  Icons.menu_book_rounded, primary, Colors.white)
            else if (!showingYourCourses && availableCourses.isEmpty)
              _stateCard('There are no Add on Courses available right now.',
                  Icons.menu_book_rounded, primary, Colors.white)
            else ...[
              Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Text(
                      showingYourCourses ? 'YOUR COURSES' : 'AVAILABLE COURSES',
                      style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1))),
              if (showingYourCourses)
                ...enrollments.map((row) => _courseCard(
                      _course(row),
                      enrolled: true,
                      enrolledAt: DateTime.tryParse(_text(row, 'created_at')),
                    ))
              else
                ...availableCourses.map((course) => _courseCard(
                      course,
                      enrolled:
                          _enrolledCourseIds.contains(_text(course, 'id')),
                    )),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _stateCard(String text, IconData icon, Color color, Color fill) =>
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: fill == Colors.white
                    ? border
                    : color.withValues(alpha: .18))),
        child: Row(children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)))
        ]),
      );
}
