import 'package:flutter_test/flutter_test.dart';
import 'package:royal_college_student_app/main.dart';

void main() {
  testWidgets('Royal College app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const RoyalCollegeApp());

    expect(find.text('Welcome Back'), findsOneWidget);
  });
}