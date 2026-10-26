import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reine/screens/admin/dashboard_screen.dart';

import 'admin_helpers.dart';
import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await seedResults(app);
  });
  tearDown(() => app.close());

  testWidgets('lists recent results, newest first', (tester) async {
    await tester.pumpWidget(app.wrap(const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Alice Martin'), findsNWidgets(2));
    expect(find.text('Jean DUPONT'), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.length, 3);
  });

  testWidgets('search filters by name, case-insensitively', (tester) async {
    await tester.pumpWidget(app.wrap(const DashboardScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dashboard-search')), 'dupont');
    await tester.pumpAndSettle();
    expect(find.text('Jean DUPONT'), findsOneWidget);
    expect(find.text('Alice Martin'), findsNothing);
  });

  testWidgets('school year filter keeps only that year', (tester) async {
    await tester.pumpWidget(app.wrap(const DashboardScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025-2026').last);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Alice Martin'), findsOneWidget);
  });
}
