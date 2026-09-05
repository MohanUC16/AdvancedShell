import 'package:flutter_test/flutter_test.dart';

import 'package:advanced_shell_simulator/main.dart';

void main() {
  testWidgets('shows integrated shell tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const AdvancedShellApp());

    expect(find.text('Advanced Shell Simulator'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Scheduling'), findsOneWidget);
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Synchronization'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
  });

  testWidgets('login prompt is visible', (WidgetTester tester) async {
    await tester.pumpWidget(const AdvancedShellApp());

    expect(find.textContaining('Login required'), findsOneWidget);
    expect(find.textContaining('guest@sim'), findsOneWidget);
  });
}
