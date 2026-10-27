import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/data/app_database.dart';
import 'package:skillo/screens/admin/admin_shell.dart';
import 'package:skillo/screens/admin/dashboard_screen.dart';
import 'package:skillo/screens/admin/questions_screen.dart';
import 'package:skillo/screens/admin/stats_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await app.auth.login(kAdminEmail, kAdminPassword);
  });
  tearDown(() => app.close());

  testWidgets('navigation bar switches between the three admin screens', (
    tester,
  ) async {
    await tester.pumpWidget(app.wrap(const AdminShell()));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.quiz));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionsScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pie_chart));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(app.auth.user, isNull);
  });
}
