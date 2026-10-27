import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/data/app_database.dart';
import 'package:skillo/data/question_repository.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late QuestionRepository repo;

  setUp(() async {
    db = await openAppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = QuestionRepository(db);
  });
  tearDown(() => db.close());

  Question newQuestion() => const Question(
    discipline: Discipline.algo,
    text: 'Nouvelle ?',
    type: QuestionType.checkbox,
    timeLimitS: 42,
    choices: [
      Choice(text: 'x', correct: true),
      Choice(text: 'y'),
      Choice(text: 'z', correct: true),
    ],
  );

  test('forDiscipline returns seeded questions with their choices', () async {
    final qs = await repo.forDiscipline(Discipline.java);
    expect(qs.length, greaterThanOrEqualTo(5));
    expect(qs.first.choices.length, greaterThanOrEqualTo(2));
    expect(qs.every((q) => q.discipline == Discipline.java), isTrue);
  });

  test('save inserts a new question and its choices', () async {
    final before = (await repo.forDiscipline(Discipline.algo)).length;
    final saved = await repo.save(newQuestion());
    expect(saved.id, isNotNull);
    final after = await repo.forDiscipline(Discipline.algo);
    expect(after.length, before + 1);
    final reloaded = after.firstWhere((q) => q.id == saved.id);
    expect(reloaded.text, 'Nouvelle ?');
    expect(reloaded.timeLimitS, 42);
    expect(reloaded.choices.map((c) => c.text), ['x', 'y', 'z']);
    expect(reloaded.correctIndexes, {0, 2});
  });

  test(
    'save with an id updates the question and replaces its choices',
    () async {
      final saved = await repo.save(newQuestion());
      await repo.save(
        saved.copyWith(
          text: 'Modifiée',
          type: QuestionType.radio,
          choices: const [
            Choice(text: 'seule', correct: true),
            Choice(text: 'autre'),
          ],
        ),
      );
      final reloaded = (await repo.forDiscipline(Discipline.algo))
          .firstWhere((q) => q.id == saved.id);
      expect(reloaded.text, 'Modifiée');
      expect(reloaded.type, QuestionType.radio);
      expect(reloaded.choices.length, 2);
      final orphans = await db.query(
        'choices',
        where: 'question_id = ?',
        whereArgs: [saved.id],
      );
      expect(orphans.length, 2);
    },
  );

  test('delete removes the question and its choices', () async {
    final saved = await repo.save(newQuestion());
    await repo.delete(saved.id!);
    final ids = (await repo.forDiscipline(Discipline.algo)).map((q) => q.id);
    expect(ids, isNot(contains(saved.id)));
    expect(
      await db.query(
        'choices',
        where: 'question_id = ?',
        whereArgs: [saved.id],
      ),
      isEmpty,
    );
  });

  test(
    'replaceDiscipline replaces one discipline and leaves the others',
    () async {
      final javaBefore = (await repo.forDiscipline(Discipline.java)).length;
      await repo.replaceDiscipline(Discipline.algo, [newQuestion()]);
      expect((await repo.forDiscipline(Discipline.algo)).length, 1);
      expect((await repo.forDiscipline(Discipline.java)).length, javaBefore);
    },
  );

  test(
    'replaceDiscipline inserts copies even when questions carry ids',
    () async {
      final existing = await repo.forDiscipline(Discipline.java);
      await repo.replaceDiscipline(Discipline.algo, existing.take(2).toList());
      final algo = await repo.forDiscipline(Discipline.algo);
      expect(algo.length, 2);
      expect(algo.map((q) => q.discipline).toSet(), {Discipline.algo});
      expect(
        (await repo.forDiscipline(Discipline.java)).length,
        existing.length,
      );
    },
  );

  test('resetFromDefaults reloads the bundled questions', () async {
    await repo.replaceDiscipline(Discipline.htmlCss, [
      newQuestion().copyWith(discipline: Discipline.htmlCss),
    ]);
    await repo.resetFromDefaults(Discipline.htmlCss);
    final qs = await repo.forDiscipline(Discipline.htmlCss);
    expect(qs.length, greaterThanOrEqualTo(5));
    expect(qs.any((q) => q.text == 'Nouvelle ?'), isFalse);
  });
}
