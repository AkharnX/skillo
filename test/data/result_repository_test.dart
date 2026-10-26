import 'package:flutter_test/flutter_test.dart';
import 'package:reine/data/app_database.dart';
import 'package:reine/data/result_repository.dart';
import 'package:reine/data/user_repository.dart';
import 'package:reine/models/discipline.dart';
import 'package:reine/models/motivation.dart';
import 'package:reine/models/test_result.dart';
import 'package:reine/models/user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late ResultRepository results;
  late UserRepository users;
  late AppUser dupont;
  late AppUser martin;

  setUp(() async {
    db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    results = ResultRepository(db);
    users = UserRepository(db);
    dupont = await users.register(
      lastName: 'DUPONT',
      firstName: 'Jean',
      email: 'j@d.fr',
      password: 'x',
      age: 20,
      address: '',
      motivation: Motivation.reconversion,
    );
    martin = await users.register(
      lastName: 'Martin',
      firstName: 'Alice',
      email: 'a@m.fr',
      password: 'x',
      age: 21,
      address: '',
      motivation: Motivation.reorientation,
    );
  });
  tearDown(() => db.close());

  TestResult result(AppUser u, Discipline d, int score, DateTime at) =>
      TestResult(
        userId: u.id,
        discipline: d,
        score: score,
        total: 4,
        percent: score * 25.0,
        passed: score >= 2,
        schoolYear: at.month >= 9
            ? '${at.year}-${at.year + 1}'
            : '${at.year - 1}-${at.year}',
        takenAt: at,
      );

  final oct2026 = DateTime(2026, 10, 10);
  final mar2026 = DateTime(2026, 3, 10);

  test('save returns the result with an id and forUser lists it', () async {
    final saved = await results.save(
      result(dupont, Discipline.java, 3, oct2026),
    );
    expect(saved.id, isNotNull);
    final mine = await results.forUser(dupont.id);
    expect(mine.length, 1);
    expect(mine.single.discipline, Discipline.java);
    expect(mine.single.percent, 75.0);
    expect(mine.single.passed, isTrue);
    expect(mine.single.takenAt, oct2026);
    expect(await results.forUser(martin.id), isEmpty);
  });

  test('a candidate cannot take the same test twice', () async {
    await results.save(result(dupont, Discipline.java, 3, oct2026));
    expect(
      () => results.save(result(dupont, Discipline.java, 1, oct2026)),
      throwsA(isA<AlreadyTakenException>()),
    );
    expect(await results.hasTaken(dupont.id, Discipline.java), isTrue);
    expect(await results.hasTaken(dupont.id, Discipline.algo), isFalse);
  });

  test('recent lists newest first with the candidate name', () async {
    await results.save(result(dupont, Discipline.java, 3, mar2026));
    await results.save(result(martin, Discipline.algo, 1, oct2026));
    final recent = await results.recent();
    expect(recent.map((r) => r.candidateName), ['Alice Martin', 'Jean DUPONT']);
  });

  test(
    'recent search is case-insensitive on last name or first name',
    () async {
      await results.save(result(dupont, Discipline.java, 3, oct2026));
      await results.save(result(martin, Discipline.java, 1, oct2026));
      expect((await results.recent(search: 'dupont')).length, 1);
      expect(
        (await results.recent(search: 'ALI')).single.candidateName,
        'Alice Martin',
      );
      expect((await results.recent(search: 'zzz')), isEmpty);
    },
  );

  test('recent can be filtered by school year', () async {
    await results.save(result(dupont, Discipline.java, 3, mar2026));
    await results.save(result(martin, Discipline.java, 1, oct2026));
    final filtered = await results.recent(schoolYear: '2025-2026');
    expect(filtered.single.candidateName, 'Jean DUPONT');
    expect(await results.schoolYears(), ['2026-2027', '2025-2026']);
  });

  test('statsByDiscipline counts passed and failed per discipline', () async {
    await results.save(result(dupont, Discipline.java, 3, oct2026));
    await results.save(result(martin, Discipline.java, 2, oct2026));
    await results.save(result(dupont, Discipline.algo, 0, oct2026));
    final stats = await results.statsByDiscipline();
    expect(stats[Discipline.java]!.passed, 2);
    expect(stats[Discipline.java]!.failed, 0);
    expect(stats[Discipline.java]!.rate, 1.0);
    expect(stats[Discipline.algo]!.failed, 1);
    expect(stats[Discipline.htmlCss]!.total, 0);
    expect(stats[Discipline.htmlCss]!.rate, 0.0);
  });

  test('globalStats aggregates all disciplines for one school year', () async {
    await results.save(result(dupont, Discipline.java, 3, oct2026));
    await results.save(result(martin, Discipline.java, 2, oct2026));
    await results.save(result(dupont, Discipline.algo, 0, oct2026));
    await results.save(result(martin, Discipline.algo, 4, mar2026));
    final g = await results.globalStats('2026-2027');
    expect(g.passed, 2);
    expect(g.failed, 1);
    expect(g.rate, closeTo(0.667, 0.001));
  });
}
