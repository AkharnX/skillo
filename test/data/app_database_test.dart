import 'package:flutter_test/flutter_test.dart';
import 'package:reine/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => db.close());

  test('seeds exactly one admin account', () async {
    final admins = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
    );
    expect(admins.length, 1);
    expect(admins.single['email'], kAdminEmail);
    expect(admins.single['password_hash'], hashPassword(kAdminPassword));
  });

  test('seeds at least 5 questions for each of the 3 disciplines', () async {
    final rows = await db.rawQuery(
      'SELECT discipline, COUNT(*) AS n FROM questions GROUP BY discipline',
    );
    final counts = {for (final r in rows) r['discipline']: r['n'] as int};
    expect(counts.keys, containsAll(['java', 'algo', 'html_css']));
    expect(counts.length, 3);
    for (final n in counts.values) {
      expect(n, greaterThanOrEqualTo(5));
    }
  });

  test('every seeded question has at least 2 choices', () async {
    final rows = await db.rawQuery(
      'SELECT q.id, COUNT(c.id) AS n FROM questions q '
      'LEFT JOIN choices c ON c.question_id = q.id GROUP BY q.id',
    );
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect(
        r['n'] as int,
        greaterThanOrEqualTo(2),
        reason: 'question ${r['id']}',
      );
    }
  });

  test('loadDefaultQuestionsJson reads the bundled asset', () async {
    final json = await loadDefaultQuestionsJson('algo');
    expect(json['discipline'], 'algo');
    expect((json['questions'] as List).length, greaterThanOrEqualTo(5));
  });

  test('reopening the same database does not duplicate the seed', () async {
    // Seed runs only when tables are empty: simulate by calling the seed twice.
    await seedIfEmpty(db);
    final admins = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['admin'],
    );
    expect(admins.length, 1);
  });
}
