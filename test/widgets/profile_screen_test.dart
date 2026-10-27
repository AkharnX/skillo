import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/motivation.dart';
import 'package:skillo/models/test_result.dart';
import 'package:skillo/screens/candidate/profile_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await app.auth.register(
      lastName: 'Dupont',
      firstName: 'Jean',
      email: 'j@d.fr',
      password: 'x',
      age: 20,
      address: '1 rue A',
      motivation: Motivation.reconversion,
    );
  });
  tearDown(() => app.close());

  testWidgets(
    'shows identity, scores and lets the candidate edit address and motivation',
    (tester) async {
      await app.results.save(
        TestResult(
          userId: app.auth.user!.id,
          discipline: Discipline.htmlCss,
          score: 1,
          total: 4,
          percent: 25,
          passed: false,
          schoolYear: '2026-2027',
          takenAt: DateTime(2026, 10, 1),
        ),
      );
      await tester.pumpWidget(app.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Jean Dupont'), findsOneWidget);
      expect(find.text('j@d.fr'), findsOneWidget);
      expect(find.text('1 / 4 (25 %)'), findsOneWidget);
      expect(find.text('Non passé'), findsNWidgets(2));

      await tester.enterText(
        find.byKey(const Key('profile-address')),
        '2 rue B',
      );
      await tester.tap(find.byKey(const Key('profile-motivation')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Poursuite d'études").last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('profile-save')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      final reloaded = await app.users.byId(app.auth.user!.id);
      expect(reloaded!.address, '2 rue B');
      expect(reloaded.motivation, Motivation.poursuiteEtudes);
      expect(app.auth.user!.address, '2 rue B');
    },
  );
}
