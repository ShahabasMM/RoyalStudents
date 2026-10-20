import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/student_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar.dart';

class FeeStatsScreen extends StatefulWidget {
  const FeeStatsScreen({super.key});

  @override
  State<FeeStatsScreen> createState() => _FeeStatsScreenState();
}

class _FeeStatsScreenState extends State<FeeStatsScreen> {
  static const navy = AppTheme.navy;
  static const border = AppTheme.outline;

  StudentProfile? student;
  List<Map<String, dynamic>> payments = [];
  bool loading = true;
  bool examTab = false;
  String error = '';
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = student == null;
        error = '';
      });
    }
    try {
      final profile = student ?? await StudentDataService.currentStudent();
      final rows = await StudentDataService.feePaymentsForSemester(profile);
      if (!mounted) return;
      setState(() {
        student = profile;
        payments = rows;
        loading = false;
      });
      if (channel == null) {
        channel = Supabase.instance.client
            .channel('student-fee-stats-' + profile.id)
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'fee_payments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'student_id',
                value: profile.id,
              ),
              callback: (_) => _refresh(),
            )
            .subscribe();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final profile = student;
    if (profile == null) return;
    try {
      final rows = await StudentDataService.feePaymentsForSemester(profile);
      if (mounted) setState(() => payments = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (channel != null) Supabase.instance.client.removeChannel(channel!);
    super.dispose();
  }

  String _field(Map<String, dynamic> row, String key, [String fallback = '']) {
    final value = row[key];
    return value == null || value.toString().trim().isEmpty
        ? fallback
        : value.toString().trim();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  String _money(double amount) {
    final shown = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '₹' + shown;
  }

  List<Map<String, dynamic>> get _coursePayments => payments
      .where((p) => _field(p, 'fee_type').toLowerCase() == 'course fee')
      .toList();

  List<Map<String, dynamic>> get _examPayments => payments
      .where((p) => _field(p, 'fee_type').toLowerCase().contains('exam'))
      .toList();

  double _sum(List<Map<String, dynamic>> list) =>
      list.fold(0, (sum, row) => sum + _number(row['amount']));

  double? _courseTotal() {
    final profile = student;
    if (profile == null || profile.semester < 1) return null;
    final values = profile.feeStructure['total'];
    final index = profile.semester - 1;
    dynamic value;
    if (values is List && index < values.length) {
      value = values[index];
    } else if (values is Map) {
      value = values[profile.semester.toString()];
    }
    return value == null || value.toString().trim().isEmpty
        ? null
        : _number(value);
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FB),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );

  Widget _summary(bool course, double paid, double? total) {
    final balance =
        total == null ? null : (total - paid).clamp(0, double.infinity);
    final progress = total == null || total <= 0
        ? 0.0
        : (paid / total).clamp(0, 1).toDouble();
    final semester = student?.semester ?? 1;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0B082B6F), blurRadius: 18, offset: Offset(0, 7))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: course ? AppTheme.softPurple : const Color(0xFFFFF2E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    course ? Icons.school_rounded : Icons.assignment_rounded,
                    color: course ? AppTheme.purple : const Color(0xFFB66A10),
                    size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                  child: Text(
                (course ? 'Course Fee' : 'Exam Fee') +
                    ' · Semester ' +
                    semester.toString(),
                style: const TextStyle(
                    color: navy, fontSize: 14, fontWeight: FontWeight.w800),
              )),
            ],
          ),
          const SizedBox(height: 17),
          if (course)
            Row(children: [
              _stat('SEMESTER FEE', total == null ? '—' : _money(total), navy),
              const SizedBox(width: 8),
              _stat('PAID', _money(paid), AppTheme.green),
              const SizedBox(width: 8),
              _stat(
                  'BALANCE',
                  balance == null ? '—' : _money(balance.toDouble()),
                  AppTheme.red),
            ])
          else
            Row(children: [
              _stat('EXAM FEE PAID', _money(paid), AppTheme.green),
              const SizedBox(width: 9),
              _stat('PAYMENTS', _examPayments.length.toString(), navy),
            ]),
          const SizedBox(height: 14),
          if (course && total != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: const Color(0xFFECEFF5),
                valueColor: const AlwaysStoppedAnimation(AppTheme.green),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total <= 0
                  ? 'Course fee is fully waived'
                  : (progress * 100).round().toString() +
                      '% paid this semester',
              style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ] else if (course)
            const Text('Semester fee has not been configured in ERP.',
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600))
          else
            const Text('Exam payments recorded by ERP for this semester.',
                style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _payment(Map<String, dynamic> row) {
    final dateValue = _field(row, 'payment_date');
    final date = DateTime.tryParse(dateValue);
    final dateText = date == null
        ? dateValue
        : date.day.toString().padLeft(2, '0') +
            '/' +
            date.month.toString().padLeft(2, '0') +
            '/' +
            date.year.toString();
    final details = [
      _field(row, 'fee_type'),
      dateText,
      _field(row, 'payment_type'),
    ].where((value) => value.isNotEmpty).join('  ·  ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFEAF8F0),
                borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.check_rounded,
                color: AppTheme.green, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_field(row, 'receipt_no', 'Fee Payment'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                        height: 1.4,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_money(_number(row['amount'])),
              style: const TextStyle(
                  color: navy, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _empty(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: border)),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppTheme.muted, size: 22),
          const SizedBox(width: 11),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final course = !examTab;
    final rows = course ? _coursePayments : _examPayments;
    final paid = _sum(rows);
    final total = _courseTotal();
    final profile = student;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const RoyalAppBar(title: 'Fee Stats'),
      body: RefreshIndicator(
        color: navy,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
          children: [
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.navyDark, AppTheme.navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(21),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26082B6F),
                      blurRadius: 18,
                      offset: Offset(0, 7))
                ],
              ),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Fee Overview',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      profile == null
                          ? 'Course and exam payments'
                          : profile.course +
                              ' · Semester ' +
                              profile.semester.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFDCE5F6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: border)),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Course Fee'),
                      icon: Icon(Icons.school_rounded)),
                  ButtonSegment(
                      value: true,
                      label: Text('Exam Fee'),
                      icon: Icon(Icons.assignment_rounded)),
                ],
                selected: {examTab},
                onSelectionChanged: (value) =>
                    setState(() => examTab = value.first),
                style: ButtonStyle(
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : navy,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? navy
                        : Colors.white,
                  ),
                  side: const WidgetStatePropertyAll(BorderSide(color: border)),
                ),
              ),
            ),
            const SizedBox(height: 17),
            if (error.isNotEmpty) ...[
              _empty(error),
              const SizedBox(height: 12)
            ],
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator(color: navy)))
            else ...[
              _summary(course, paid, course ? total : null),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(
                    child: Text('Payment History',
                        style: TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppTheme.softPurple,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(rows.length.toString(),
                      style: const TextStyle(
                          color: AppTheme.purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 11),
              if (rows.isEmpty)
                _empty(course
                    ? 'No course fee payments are recorded for this semester.'
                    : 'No exam fee payments are recorded for this semester.')
              else
                ...rows.map(_payment),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}
