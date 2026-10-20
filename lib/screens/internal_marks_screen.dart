import 'package:flutter/material.dart';

import '../services/student_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';

class InternalMarksScreen extends StatefulWidget {
  const InternalMarksScreen({super.key});

  @override
  State<InternalMarksScreen> createState() => _InternalMarksScreenState();
}

class _InternalMarksScreenState extends State<InternalMarksScreen> {
  static const Color primary = Color(0xFF1456A0);
  static const Color background = Color(0xFFF5F8FC);
  static const Color border = Color(0xFFE1E8F0);

  StudentProfile? student;
  List<Map<String, dynamic>> marks = [];
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
      final rows = await StudentDataService.internalMarks(profile);
      if (!mounted) return;
      setState(() {
        student = profile;
        marks = rows;
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

  double _number(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _format(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

  Map<String, dynamic> _subject(Map<String, dynamic> row) {
    final value = row['syllabus_subjects'];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  Widget _component(String label, double value, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFEAF2FB) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: emphasize ? const Color(0xFFD6E5F5) : border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(_format(value), style: TextStyle(color: emphasize ? primary : AppTheme.navy, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _markCard(Map<String, dynamic> row) {
    final subject = _subject(row);
    final name = '${subject['subject_name'] ?? 'Subject'}';
    final code = '${subject['subject_code'] ?? ''}'.trim();
    final score = _number(row, 'mark');
    final total = _number(row, 'total_mark');
    final practical = _number(row, 'internal_practical_mark');
    final openEnded = _number(row, 'open_ended_mark');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x090D2850), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.navy, fontSize: 14, fontWeight: FontWeight.w800)),
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(code, style: const TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(_format(score == 0 ? total : score), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    const Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .7)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider(height: 1, color: border)),
          Row(
            children: [
              Expanded(child: _component('Assignment', _number(row, 'assignment_mark'))),
              const SizedBox(width: 8),
              Expanded(child: _component('Seminar', _number(row, 'seminar_mark'))),
              const SizedBox(width: 8),
              Expanded(child: _component('Test', _number(row, 'test_paper_mark'))),
            ],
          ),
          if (practical > 0 || openEnded > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (practical > 0) Expanded(child: _component('Practical', practical)),
                if (practical > 0 && openEnded > 0) const SizedBox(width: 8),
                if (openEnded > 0) Expanded(child: _component('Open-ended', openEnded)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = student;

    return Scaffold(
      backgroundColor: background,
      appBar: const RoyalAppBar(title: 'Internal Marks'),
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
                color: primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x241456A0), blurRadius: 18, offset: Offset(0, 7))],
              ),
              child: Row(
                children: [
                  Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.assessment_rounded, color: primary, size: 23)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your internal marks', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(profile == null ? 'Loading your academic details…' : '${profile.course}  •  Semester ${profile.semester}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE7F0FA), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF0D467F), borderRadius: BorderRadius.circular(11)), child: Text('${marks.length} subjects', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (error.isNotEmpty) _messageCard(error, Icons.error_outline_rounded, const Color(0xFFB42318), const Color(0xFFFFF2F0)),
            if (loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: primary)))
            else if (marks.isEmpty)
              _messageCard('Internal marks for your current semester have not been added yet.', Icons.menu_book_rounded, primary, Colors.white)
            else ...[
              const Padding(padding: EdgeInsets.only(bottom: 11), child: Text('SUBJECT BREAKDOWN', style: TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              ...marks.map(_markCard),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _messageCard(String message, IconData icon, Color color, Color fill) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: fill == Colors.white ? border : color.withValues(alpha: .18))),
      child: Row(children: [Icon(icon, color: color, size: 21), const SizedBox(width: 11), Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)))]),
    );
  }
}
