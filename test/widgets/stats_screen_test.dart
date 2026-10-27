import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/screens/admin/stats_screen.dart';

import 'admin_helpers.dart';
import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await seedResults(app);
  });
  tearDown(() => app.close());

  testWidgets(
    'shows one pie per discipline plus the global pie for the selected year',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app.wrap(const StatsScreen()));
      await tester.pumpAndSettle();
      // 3 disciplines + 1 global
      expect(find.byType(PieChart), findsNWidgets(4));
      // Année la plus récente sélectionnée par défaut : Java 1 réussi / 1 échoué.
      expect(find.text('Java : 50 % de réussite (1 / 2)'), findsOneWidget);
      expect(
        find.text('Global 2026-2027 : 50 % de réussite (1 / 2)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('stats-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-2026').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Global 2025-2026 : 100 % de réussite (1 / 1)'),
        findsOneWidget,
      );
    },
  );
}
