import 'package:flutter/material.dart';

import '../services/student_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static const Color primary = Color(0xFF5B3CC4);
  static const Color background = Color(0xFFF7F8FC);
  static const Color border = Color(0xFFE4E7F0);

  StudentProfile? student;
  List<Map<String, dynamic>> results = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final profile = await StudentDataService.currentStudent();
      final rows = await StudentDataService.results(profile);
      if (!mounted) return;
      setState(() {
        student = profile;
        results = rows;
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

  double? _number(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _format(double? value) =>
      value == null ? '—' : (value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2));

  Map<String, dynamic> _subject(Map<String, dynamic> row) {
    final value = row['syllabus_subjects'];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5FF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE8E1FA)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 9, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.navy, fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> row) {
    final subject = _subject(row);
    final name = '${subject['subject_name'] ?? 'Subject'}';
    final code = '${subject['subject_code'] ?? ''}'.trim();
    final grade = '${row['grade'] ?? '—'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x080D2850), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.navy, fontSize: 13, fontWeight: FontWeight.w800)),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(code, style: const TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 51),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(11)),
            child: Text(grade, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, {bool isError = false}) {
    final color = isError ? const Color(0xFFB42318) : primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF2F0) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isError ? const Color(0xFFF4C7C2) : border),
      ),
      child: Row(children: [Icon(isError ? Icons.error_outline_rounded : Icons.school_rounded, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = student;
    final firstResult = results.isEmpty ? null : results.first;
    return Scaffold(
      backgroundColor: background,
      appBar: const RoyalAppBar(title: 'Results'),
      body: RefreshIndicator(
        color: primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x245B3CC4), blurRadius: 18, offset: Offset(0, 7))]),
              child: Row(children: [
                Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.workspace_premium_rounded, color: primary, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Your semester result', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(profile == null ? 'Loading your academic details…' : '${profile.course}  •  Semester ${profile.semester}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFECE7FF), fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
            const SizedBox(height: 13),
            if (firstResult != null)
              Row(children: [
                _stat('SEMESTER GPA', _format(_number(firstResult, 'sgpa')), Icons.auto_graph_rounded),
                const SizedBox(width: 9),
                _stat('CUMULATIVE GPA', _format(_number(firstResult, 'cgpa')), Icons.stacked_line_chart_rounded),
              ]),
            const SizedBox(height: 18),
            if (error.isNotEmpty) _message(error, isError: true),
            if (loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: primary)))
            else if (results.isEmpty)
              _message('Your result for this semester has not been published yet.')
            else ...[
              const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('SUBJECT RESULTS', style: TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              ...results.map(_resultCard),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
