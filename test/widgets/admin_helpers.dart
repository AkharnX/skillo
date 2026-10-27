import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/motivation.dart';
import 'package:skillo/models/test_result.dart';
import 'package:skillo/models/user.dart';

import 'test_app.dart';

/// Deux candidats avec des résultats, pour les tests admin.
Future<void> seedResults(TestApp app) async {
  final dupont = await app.users.register(
    lastName: 'DUPONT',
    firstName: 'Jean',
    email: 'j@d.fr',
    password: 'x',
    age: 20,
    address: 'a',
    motivation: Motivation.reconversion,
  );
  final martin = await app.users.register(
    lastName: 'Martin',
    firstName: 'Alice',
    email: 'a@m.fr',
    password: 'x',
    age: 21,
    address: 'a',
    motivation: Motivation.reorientation,
  );
  TestResult r(AppUser u, Discipline d, int score, DateTime at, String year) =>
      TestResult(
        userId: u.id,
        discipline: d,
        score: score,
        total: 4,
        percent: score * 25.0,
        passed: score >= 2,
        schoolYear: year,
        takenAt: at,
      );
  await app.results.save(
    r(dupont, Discipline.java, 3, DateTime(2026, 10, 5), '2026-2027'),
  );
  await app.results.save(
    r(martin, Discipline.java, 1, DateTime(2026, 10, 6), '2026-2027'),
  );
  await app.results.save(
    r(martin, Discipline.algo, 4, DateTime(2026, 3, 6), '2025-2026'),
  );
}
