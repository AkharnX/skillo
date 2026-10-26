import 'dart:convert';

import '../models/discipline.dart';
import '../models/question.dart';

/// Erreur de format ou de validation d'un JSON de questions (US5).
class QuestionJsonException implements Exception {
  QuestionJsonException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Résultat de l'analyse d'un document JSON : la discipline et ses questions.
class ParsedQuestions {
  const ParsedQuestions(this.discipline, this.questions);
  final Discipline discipline;
  final List<Question> questions;
}

/// Analyse et valide un document JSON au format :
/// `{"discipline": "java", "questions": [{"text", "type", "timeLimit", "choices": [{"text", "correct"}]}]}`.
/// Si [expected] est fourni, la discipline du document doit correspondre.
ParsedQuestions parseQuestionsJson(String raw, {Discipline? expected}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw QuestionJsonException('JSON invalide : ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw QuestionJsonException('Le document doit être un objet JSON.');
  }
  return parseQuestionsMap(decoded, expected: expected);
}

ParsedQuestions parseQuestionsMap(
  Map<String, dynamic> doc, {
  Discipline? expected,
}) {
  final code = doc['discipline'];
  if (code is! String) {
    throw QuestionJsonException('Champ "discipline" manquant.');
  }
  final Discipline discipline;
  try {
    discipline = Discipline.fromCode(code);
  } on ArgumentError {
    throw QuestionJsonException(
      'Discipline inconnue "$code" (attendu : ${Discipline.values.map((d) => d.code).join(', ')}).',
    );
  }
  if (expected != null && discipline != expected) {
    throw QuestionJsonException(
      'Le document concerne "${discipline.label}" mais vous importez dans "${expected.label}".',
    );
  }
  final list = doc['questions'];
  if (list is! List || list.isEmpty) {
    throw QuestionJsonException(
      'Le champ "questions" doit être une liste non vide.',
    );
  }
  final questions = <Question>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! Map<String, dynamic>) {
      throw QuestionJsonException('Question ${i + 1} : objet attendu.');
    }
    final question = _questionFromMap(item, discipline);
    final error = validateQuestion(question);
    if (error != null) {
      throw QuestionJsonException('Question ${i + 1} : $error');
    }
    questions.add(question);
  }
  return ParsedQuestions(discipline, questions);
}

Question _questionFromMap(Map<String, dynamic> m, Discipline discipline) {
  final typeCode = m['type'];
  final type = QuestionType.values.cast<QuestionType?>().firstWhere(
    (t) => t!.code == typeCode,
    orElse: () => null,
  );
  if (type == null) {
    throw QuestionJsonException(
      'type "$typeCode" inconnu (radio ou checkbox).',
    );
  }
  final rawChoices = m['choices'];
  final choices = rawChoices is List
      ? rawChoices
            .whereType<Map<String, dynamic>>()
            .map(
              (c) => Choice(
                text: '${c['text'] ?? ''}',
                correct: c['correct'] == true,
              ),
            )
            .toList()
      : <Choice>[];
  final timeLimit = m['timeLimit'];
  return Question(
    discipline: discipline,
    text: '${m['text'] ?? ''}',
    type: type,
    timeLimitS: timeLimit is int ? timeLimit : 0,
    choices: choices,
  );
}

/// Règles communes à l'import JSON et à l'éditeur de questions.
/// Retourne un message d'erreur, ou null si la question est valide.
String? validateQuestion(Question q) {
  if (q.text.trim().isEmpty) return 'le texte est obligatoire.';
  if (q.timeLimitS <= 0) return 'le temps limite doit être supérieur à 0.';
  if (q.choices.length < 2) return 'il faut au moins 2 choix.';
  if (q.choices.any((c) => c.text.trim().isEmpty)) {
    return 'chaque choix doit avoir un texte.';
  }
  final correct = q.correctIndexes.length;
  if (q.type == QuestionType.radio && correct != 1) {
    return 'une question à choix unique doit avoir exactement 1 bonne réponse.';
  }
  if (q.type == QuestionType.checkbox && correct < 1) {
    return 'une question à choix multiples doit avoir au moins 1 bonne réponse.';
  }
  return null;
}

/// Sérialise des questions dans le même format que l'import (export / sauvegarde).
String questionsToJson(Discipline discipline, List<Question> questions) =>
    const JsonEncoder.withIndent('  ').convert({
      'discipline': discipline.code,
      'questions': [
        for (final q in questions)
          {
            'text': q.text,
            'type': q.type.code,
            'timeLimit': q.timeLimitS,
            'choices': [
              for (final c in q.choices) {'text': c.text, 'correct': c.correct},
            ],
          },
      ],
    });
