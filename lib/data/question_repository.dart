import 'package:sqflite_common/sqlite_api.dart';

import '../logic/question_json.dart';
import '../models/discipline.dart';
import '../models/question.dart';
import 'app_database.dart' show loadDefaultQuestionsJson;

/// Accès aux tables `questions` et `choices` (US2, US5).
class QuestionRepository {
  QuestionRepository(this._db);

  final Database _db;

  /// Toutes les questions d'une discipline, avec leurs choix, par id croissant.
  Future<List<Question>> forDiscipline(Discipline discipline) async {
    final qRows = await _db.query(
      'questions',
      where: 'discipline = ?',
      whereArgs: [discipline.code],
      orderBy: 'id',
    );
    if (qRows.isEmpty) return [];
    final ids = qRows.map((r) => r['id'] as int).toList();
    final cRows = await _db.query(
      'choices',
      where: 'question_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    final choicesByQuestion = <int, List<Choice>>{};
    for (final c in cRows) {
      choicesByQuestion.putIfAbsent(c['question_id'] as int, () => []).add(
            Choice(id: c['id'] as int, text: c['text'] as String, correct: c['is_correct'] == 1),
          );
    }
    return [
      for (final r in qRows)
        Question(
          id: r['id'] as int,
          discipline: discipline,
          text: r['text'] as String,
          type: QuestionType.fromCode(r['type'] as String),
          timeLimitS: r['time_limit_s'] as int,
          choices: choicesByQuestion[r['id'] as int] ?? const [],
        ),
    ];
  }

  /// Insère (id null) ou met à jour une question ; les choix sont réécrits.
  Future<Question> save(Question q) async {
    final id = await _db.transaction((txn) => _saveIn(txn, q));
    return q.copyWith(id: id);
  }

  Future<int> _saveIn(DatabaseExecutor txn, Question q, {bool forceInsert = false}) async {
    final row = {
      'discipline': q.discipline.code,
      'text': q.text.trim(),
      'type': q.type.code,
      'time_limit_s': q.timeLimitS,
    };
    final int id;
    if (q.id == null || forceInsert) {
      id = await txn.insert('questions', row);
    } else {
      id = q.id!;
      await txn.update('questions', row, where: 'id = ?', whereArgs: [id]);
      await txn.delete('choices', where: 'question_id = ?', whereArgs: [id]);
    }
    for (final c in q.choices) {
      await txn.insert('choices', {
        'question_id': id,
        'text': c.text.trim(),
        'is_correct': c.correct ? 1 : 0,
      });
    }
    return id;
  }

  Future<void> delete(int id) =>
      _db.delete('questions', where: 'id = ?', whereArgs: [id]);

  /// Remplace toutes les questions d'une discipline (import JSON, US5).
  Future<void> replaceDiscipline(Discipline discipline, List<Question> questions) =>
      _db.transaction((txn) async {
        await txn.delete('questions', where: 'discipline = ?', whereArgs: [discipline.code]);
        for (final q in questions) {
          await _saveIn(txn, q.copyWith(discipline: discipline), forceInsert: true);
        }
      });

  /// Recharge les questions par défaut livrées dans les assets.
  Future<void> resetFromDefaults(Discipline discipline) async {
    final doc = await loadDefaultQuestionsJson(discipline.code);
    final parsed = parseQuestionsMap(doc, expected: discipline);
    await replaceDiscipline(discipline, parsed.questions);
  }
}
