import 'package:flutter/material.dart';

import '../widgets/app_bar.dart';
import '../services/student_data_service.dart';

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({
    super.key,
  });

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  // ============================================================
  // THEME
  // ============================================================

  static const Color primary = Color(0xFF2563EB);

  static const Color primaryDark = Color(0xFF1E3A8A);

  static const Color blue = Color(0xFF3B82F6);

  static const Color primarySoft = Color(0xFFEFF6FF);

  static const Color background = Color(0xFFF7F9FC);

  static const Color navy = Color(0xFF172033);

  static const Color muted = Color(0xFF64748B);

  static const Color border = Color(0xFFE5EAF1);

  // ============================================================
  // STATE
  // ============================================================

  StudentProfile? student;

  List<Map<String, dynamic>> subjects = [];

  bool loading = true;

  String error = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = '';
      });
    }

    try {
      final currentStudent = await StudentDataService.currentStudent();

      final data = await StudentDataService.syllabus(
        currentStudent,
      );

      if (!mounted) return;

      setState(() {
        student = currentStudent;

        subjects = List<Map<String, dynamic>>.from(
          data,
        );

        loading = false;
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
  // VALUE
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,
      appBar: const RoyalAppBar(
        title: 'Subjects',
      ),
      body: RefreshIndicator(
        color: primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            6,
            16,
            30,
          ),
          children: [
            _hero(),
            const SizedBox(
              height: 18,
            ),
            if (error.isNotEmpty) _errorCard(),
            if (loading)
              _loadingState()
            else if (subjects.isEmpty)
              _emptyState()
            else ...[
              _subjectHeader(),
              const SizedBox(
                height: 12,
              ),
              ...subjects.asMap().entries.map(
                    (entry) => _subjectCard(
                      entry.key,
                      entry.value,
                    ),
                  ),
            ],
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
            blue,
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(
                16,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .12),
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Subjects',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  student == null
                      ? 'Loading...'
                      : '${student!.course}  •  '
                          'Semester ${student!.semester}',
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
  // SUBJECT HEADER
  // ============================================================

  Widget _subjectHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subjects',
                style: TextStyle(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(
                height: 3,
              ),
              Text(
                'Your semester subjects',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: primarySoft,
            borderRadius: BorderRadius.circular(
              10,
            ),
          ),
          child: Text(
            '${subjects.length} '
            '${subjects.length == 1 ? 'Subject' : 'Subjects'}',
            style: const TextStyle(
              color: primary,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUBJECT CARD
  // ============================================================

  Widget _subjectCard(
    int index,
    Map<String, dynamic> row,
  ) {
    final code = _value(
      row,
      [
        'subject_code',
      ],
      'SUBJECT',
    );

    final name = _value(
      row,
      [
        'subject_name',
      ],
      'Subject',
    );

    final description = _value(
      row,
      [
        'description',
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          19,
        ),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // NUMBER
            // ==================================================

            Container(
              width: 45,
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEFF6FF),
                    Color(0xFFDBEAFE),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  13,
                ),
              ),
              child: Text(
                '${index + 1}'.padLeft(
                  2,
                  '0',
                ),
                style: const TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primarySoft,
                      borderRadius: BorderRadius.circular(
                        6,
                      ),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: primary,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(
                      height: 9,
                    ),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 9,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingState() {
    return Column(
      children: List.generate(
        4,
        (index) {
          return Container(
            height: 91,
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                19,
              ),
              border: Border.all(
                color: border,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFBE123C),
            size: 19,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Color(0xFFBE123C),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          21,
        ),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: primary,
              size: 31,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          const Text(
            'No Subjects Available',
            style: TextStyle(
              color: navy,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            student == null
                ? 'No subject data available.'
                : 'No subjects found for '
                    '${student!.course}, '
                    'Semester ${student!.semester}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
