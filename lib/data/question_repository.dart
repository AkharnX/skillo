/// Accès aux tables `questions` et `choices`.
///
/// Toutes les requêtes SQL qui touchent aux questions passent par ici :
/// lecture par discipline (pour passer un test, US2), création / modification /
/// suppression depuis l'éditeur admin (US5), import JSON et retour aux
/// questions par défaut.
library;

import 'package:sqflite_common/sqlite_api.dart';

import '../logic/question_json.dart';
import '../models/discipline.dart';
import '../models/question.dart';
import 'app_database.dart' show loadDefaultQuestionsJson;

/// Accès aux tables `questions` et `choices` (US2, US5).
class QuestionRepository {
  /// Reçoit la base déjà ouverte par `openAppDatabase`.
  QuestionRepository(this._db);

  final Database _db;

  /// Toutes les questions d'une discipline, avec leurs choix, par id croissant.
  ///
  /// Deux requêtes seulement (une pour les questions, une pour tous leurs
  /// choix), puis on assemble en mémoire : c'est plus rapide qu'une requête
  /// de choix par question.
  Future<List<Question>> forDiscipline(Discipline discipline) async {
    // 1. Les lignes de `questions` de cette discipline, triées par id.
    final questionRows = await _db.query(
      'questions',
      where: 'discipline = ?',
      whereArgs: [discipline.code],
      orderBy: 'id',
    );
    if (questionRows.isEmpty) return [];

    // 2. Liste des ids de ces questions.
    // Boucle sur les lignes de questions ; on accumule l'id de chacune.
    // Résultat : [12, 13, 14, …].
    final questionIds = <int>[];
    for (final row in questionRows) {
      questionIds.add(row['id'] as int);
    }

    // 3. Un '?' par id pour écrire « question_id IN (?,?,?) ».
    // Boucle sur les ids ; on accumule un '?' par id. Résultat : "?,?,?".
    final placeholders = <String>[];
    for (var i = 0; i < questionIds.length; i++) {
      placeholders.add('?');
    }

    // 4. Tous les choix de toutes ces questions en une seule requête.
    final choiceRows = await _db.query(
      'choices',
      where: 'question_id IN (${placeholders.join(',')})',
      whereArgs: questionIds,
      orderBy: 'id',
    );

    // 5. Regroupement des choix par question.
    // Boucle sur les lignes de choix ; on accumule dans une Map
    // « id de question -> liste de ses choix ». Résultat : pour chaque
    // question, la liste de ses Choice dans l'ordre des ids.
    final choicesByQuestion = <int, List<Choice>>{};
    for (final row in choiceRows) {
      final questionId = row['question_id'] as int;
      final choice = Choice(
        id: row['id'] as int,
        text: row['text'] as String,
        correct: row['is_correct'] == 1,
      );
      // Première fois qu'on voit cette question : on crée sa liste vide.
      if (!choicesByQuestion.containsKey(questionId)) {
        choicesByQuestion[questionId] = <Choice>[];
      }
      choicesByQuestion[questionId]!.add(choice);
    }

    // 6. Construction des objets Question.
    // Boucle sur les lignes de questions ; on accumule un Question par ligne,
    // en lui attachant ses choix (liste vide si la question n'en a aucun).
    // Résultat : la liste finale, dans le même ordre que la requête.
    final questions = <Question>[];
    for (final row in questionRows) {
      final questionId = row['id'] as int;
      questions.add(
        Question(
          id: questionId,
          discipline: discipline,
          text: row['text'] as String,
          type: QuestionType.fromCode(row['type'] as String),
          timeLimitS: row['time_limit_s'] as int,
          choices: choicesByQuestion[questionId] ?? const [],
        ),
      );
    }
    return questions;
  }

  /// Insère (si `q.id` est null) ou met à jour une question ; les choix sont
  /// entièrement réécrits. Retourne la question avec son id définitif.
  ///
  /// Tout se passe dans une transaction : si l'insertion d'un choix échoue,
  /// la question n'est pas enregistrée à moitié.
  Future<Question> save(Question q) async {
    final id = await _db.transaction((txn) => _saveIn(txn, q));
    return q.copyWith(id: id);
  }

  /// Écrit une question et ses choix dans la transaction [txn].
  ///
  /// [forceInsert] = true force une **nouvelle** ligne même si `q.id` n'est
  /// pas null : utilisé par [replaceDiscipline] pour copier des questions
  /// existantes sans écraser les originales.
  Future<int> _saveIn(
    DatabaseExecutor txn,
    Question q, {
    bool forceInsert = false,
  }) async {
    // 1. Colonnes de la table `questions` (textes nettoyés des espaces).
    final row = {
      'discipline': q.discipline.code,
      'text': q.text.trim(),
      'type': q.type.code,
      'time_limit_s': q.timeLimitS,
    };

    // 2. Insertion ou mise à jour.
    //    - nouvelle question : INSERT, l'id est généré par la base ;
    //    - question existante : UPDATE, puis on supprime ses anciens choix
    //      pour les réécrire tous à l'étape 3 (plus simple que de comparer
    //      ancien et nouveau).
    final int id;
    if (q.id == null || forceInsert) {
      id = await txn.insert('questions', row);
    } else {
      id = q.id!;
      await txn.update('questions', row, where: 'id = ?', whereArgs: [id]);
      await txn.delete('choices', where: 'question_id = ?', whereArgs: [id]);
    }

    // 3. Boucle sur les choix de la question : chacun devient une ligne de
    //    `choices` rattachée à `id`. À la fin, la question a exactement les
    //    choix fournis.
    for (final c in q.choices) {
      await txn.insert('choices', {
        'question_id': id,
        'text': c.text.trim(),
        'is_correct': c.correct ? 1 : 0,
      });
    }
    return id;
  }

  /// Supprime une question. Ses choix partent avec elle grâce au
  /// `ON DELETE CASCADE` de la table `choices`.
  Future<void> delete(int id) =>
      _db.delete('questions', where: 'id = ?', whereArgs: [id]);

  /// Remplace toutes les questions d'une discipline (import JSON, US5).
  ///
  /// Dans une seule transaction : on supprime les anciennes questions de la
  /// discipline, puis on insère les nouvelles. Si l'import échoue en cours de
  /// route, la base revient à l'état d'avant.
  Future<void> replaceDiscipline(
    Discipline discipline,
    List<Question> questions,
  ) => _db.transaction((txn) async {
    // 1. Suppression des anciennes questions (et de leurs choix, en cascade).
    await txn.delete(
      'questions',
      where: 'discipline = ?',
      whereArgs: [discipline.code],
    );

    // 2. Boucle sur les nouvelles questions : chacune est insérée comme une
    //    nouvelle ligne (forceInsert) dans la discipline cible, quel que soit
    //    l'id ou la discipline qu'elle portait. À la fin, la discipline
    //    contient exactement les questions de la liste.
    for (final q in questions) {
      await _saveIn(txn, q.copyWith(discipline: discipline), forceInsert: true);
    }
  });

  /// Recharge les questions par défaut livrées dans les assets
  /// (`assets/questions/<code>.json`) pour une discipline.
  Future<void> resetFromDefaults(Discipline discipline) async {
    // 1. Lecture du fichier JSON embarqué.
    final doc = await loadDefaultQuestionsJson(discipline.code);
    // 2. Validation avec les mêmes règles que l'import admin.
    final parsed = parseQuestionsMap(doc, expected: discipline);
    // 3. Remplacement complet de la discipline.
    await replaceDiscipline(discipline, parsed.questions);
  }
}
