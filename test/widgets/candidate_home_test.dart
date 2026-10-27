import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/motivation.dart';
import 'package:skillo/models/test_result.dart';
import 'package:skillo/screens/candidate/candidate_home_screen.dart';
import 'package:skillo/screens/candidate/test_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await app.auth.register(
      lastName: 'D',
      firstName: 'J',
      email: 'j@d.fr',
      password: 'x',
      age: 20,
      address: 'a',
      motivation: Motivation.reconversion,
    );
  });
  tearDown(() => app.close());

  testWidgets('lists the 3 disciplines, with the score when already taken', (
    tester,
  ) async {
    await app.results.save(
      TestResult(
        userId: app.auth.user!.id,
        discipline: Discipline.algo,
        score: 3,
        total: 4,
        percent: 75,
        passed: true,
        schoolYear: '2026-2027',
        takenAt: DateTime(2026, 10, 1),
      ),
    );
    await tester.pumpWidget(app.wrap(const CandidateHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Java'), findsOneWidget);
    expect(find.text('Algorithmes'), findsOneWidget);
    expect(find.text('HTML/CSS'), findsOneWidget);
    expect(find.text('Passer le test'), findsNWidgets(2));
    expect(find.text('Score : 3 / 4 (75 %)'), findsOneWidget);
  });

  testWidgets(
    'starting a test opens the TestScreen with the seeded questions',
    (tester) async {
      await tester.pumpWidget(app.wrap(const CandidateHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-java')));
      await tester.pumpAndSettle();

      expect(find.byType(TestScreen), findsOneWidget);
      expect(find.textContaining('Question 1 /'), findsOneWidget);
    },
  );

  testWidgets('starting a test immediately counts it as taken (reload-proof)', (
    tester,
  ) async {
    await tester.pumpWidget(app.wrap(const CandidateHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-java')));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen), findsOneWidget);
    expect(
      await app.results.hasTaken(app.auth.user!.id, Discipline.java),
      isTrue,
    );
  });

  testWidgets('a double tap on "Passer le test" opens a single TestScreen', (
    tester,
  ) async {
    await tester.pumpWidget(app.wrap(const CandidateHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-java')));
    await tester.tap(find.byKey(const Key('start-java')));
    await tester.pumpAndSettle();
    expect(find.byType(TestScreen, skipOffstage: false), findsOneWidget);
  });
}
