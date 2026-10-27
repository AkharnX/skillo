/// Lecture, validation et écriture du format JSON des questions (US5).
///
/// Le même format sert aux fichiers livrés dans `assets/questions/` et à
/// l'import JSON de l'interface admin :
/// ```json
/// {"discipline": "java",
///  "questions": [{"text": "…", "type": "radio", "timeLimit": 30,
///                 "choices": [{"text": "…", "correct": true}, …]}]}
/// ```
/// [validateQuestion] contient les règles métier communes à l'import et à
/// l'éditeur de questions, pour qu'une question invalide ne puisse entrer
/// en base par aucun des deux chemins.
library;

import 'dart:convert';

import '../models/discipline.dart';
import '../models/question.dart';

/// Erreur de format ou de validation d'un JSON de questions (US5).
/// Le [message] est en français et affiché tel quel à l'admin.
class QuestionJsonException implements Exception {
  QuestionJsonException(this.message);

  /// Explication lisible du problème (ex. « Question 3 : il faut au moins
  /// 2 choix. »).
  final String message;

  @override
  String toString() => message;
}

/// Résultat de l'analyse d'un document JSON : la discipline et ses questions.
class ParsedQuestions {
  const ParsedQuestions(this.discipline, this.questions);

  /// Discipline déclarée dans le champ `discipline` du document.
  final Discipline discipline;

  /// Questions validées, dans l'ordre du fichier.
  final List<Question> questions;
}

/// Analyse et valide un texte JSON brut (contenu d'un fichier importé).
///
/// Si [expected] est fourni, la discipline du document doit correspondre :
/// l'admin ne peut pas importer un fichier « algo » dans l'onglet « Java ».
/// Toute erreur (JSON mal formé, champ manquant, règle métier violée) est
/// transformée en [QuestionJsonException].
ParsedQuestions parseQuestionsJson(String raw, {Discipline? expected}) {
  // 1. Décodage du texte. Une FormatException devient notre exception.
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw QuestionJsonException('JSON invalide : ${e.message}');
  }
  // 2. La racine doit être un objet {...}, pas une liste ni un nombre.
  if (decoded is! Map<String, dynamic>) {
    throw QuestionJsonException('Le document doit être un objet JSON.');
  }
  // 3. Analyse du contenu.
  return parseQuestionsMap(decoded, expected: expected);
}

/// Analyse et valide un document déjà décodé en Map (voir
/// [parseQuestionsJson]). Utilisé aussi pour les JSON des assets.
ParsedQuestions parseQuestionsMap(
  Map<String, dynamic> doc, {
  Discipline? expected,
}) {
  // 1. Champ "discipline" : présent, texte, et code connu.
  final code = doc['discipline'];
  if (code is! String) {
    throw QuestionJsonException('Champ "discipline" manquant.');
  }
  final Discipline discipline;
  try {
    discipline = Discipline.fromCode(code);
  } on ArgumentError {
    throw QuestionJsonException(
      'Discipline inconnue "$code" (attendu : ${_allDisciplineCodes()}).',
    );
  }

  // 2. Cohérence avec la discipline attendue par l'écran d'import.
  if (expected != null && discipline != expected) {
    throw QuestionJsonException(
      'Le document concerne "${discipline.label}" mais vous importez dans "${expected.label}".',
    );
  }

  // 3. Champ "questions" : une liste non vide.
  final list = doc['questions'];
  if (list is! List || list.isEmpty) {
    throw QuestionJsonException(
      'Le champ "questions" doit être une liste non vide.',
    );
  }

  // 4. Conversion et validation de chaque question.
  // Boucle sur les positions 0..n-1 de la liste (l'index sert à numéroter
  // les messages d'erreur « Question 3 : … »). On accumule les Question
  // valides ; la première invalide arrête tout avec une exception.
  // Résultat : la liste complète des questions valides.
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

/// Codes de toutes les disciplines séparés par des virgules, pour les
/// messages d'erreur (« java, algo, html_css »).
String _allDisciplineCodes() {
  // Boucle sur les disciplines ; on accumule leur code.
  // Résultat : ['java', 'algo', 'html_css'], puis joint par ", ".
  final codes = <String>[];
  for (final discipline in Discipline.values) {
    codes.add(discipline.code);
  }
  return codes.join(', ');
}

/// Convertit l'objet JSON d'une question en [Question], sans la valider
/// (c'est le rôle de [validateQuestion]). Les champs absents reçoivent une
/// valeur « vide » (texte "", timeLimit 0, aucun choix) qui sera ensuite
/// rejetée par la validation avec un message clair.
Question _questionFromMap(Map<String, dynamic> m, Discipline discipline) {
  // 1. Type : "radio" ou "checkbox", sinon erreur immédiate.
  final typeCode = m['type'];
  final type = QuestionType.fromCodeOrNull('$typeCode');
  if (type == null) {
    throw QuestionJsonException(
      'type "$typeCode" inconnu (radio ou checkbox).',
    );
  }

  // 2. Choix : chaque élément de la liste qui est bien un objet devient un
  //    Choice ; les éléments d'un autre type sont ignorés.
  // Boucle sur les éléments bruts de "choices" ; on accumule un Choice par
  // objet valide. Résultat : la liste des choix (vide si le champ manque).
  final choices = <Choice>[];
  final rawChoices = m['choices'];
  if (rawChoices is List) {
    for (final raw in rawChoices) {
      if (raw is! Map<String, dynamic>) continue;
      choices.add(
        Choice(text: '${raw['text'] ?? ''}', correct: raw['correct'] == true),
      );
    }
  }

  // 3. Temps limite : doit être un entier, sinon 0 (rejeté à la validation).
  final timeLimit = m['timeLimit'];
  var timeLimitS = 0;
  if (timeLimit is int) timeLimitS = timeLimit;

  return Question(
    discipline: discipline,
    text: '${m['text'] ?? ''}',
    type: type,
    timeLimitS: timeLimitS,
    choices: choices,
  );
}

/// Règles communes à l'import JSON et à l'éditeur de questions.
/// Retourne un message d'erreur (début de phrase en minuscule, pour être
/// préfixé par « Question N : »), ou null si la question est valide.
String? validateQuestion(Question q) {
  // 1. Texte et temps limite.
  if (q.text.trim().isEmpty) return 'le texte est obligatoire.';
  if (q.timeLimitS <= 0) return 'le temps limite doit être supérieur à 0.';

  // 2. Au moins deux choix, tous avec un texte.
  if (q.choices.length < 2) return 'il faut au moins 2 choix.';
  // Boucle sur les choix ; dès qu'un choix a un texte vide, on renvoie
  // l'erreur. Si on sort de la boucle, tous les choix ont un texte.
  for (final choice in q.choices) {
    if (choice.text.trim().isEmpty) return 'chaque choix doit avoir un texte.';
  }

  // 3. Nombre de bonnes réponses selon le type : exactement 1 pour radio,
  //    au moins 1 pour checkbox.
  final correctCount = q.correctIndexes.length;
  if (q.type == QuestionType.radio && correctCount != 1) {
    return 'une question à choix unique doit avoir exactement 1 bonne réponse.';
  }
  if (q.type == QuestionType.checkbox && correctCount < 1) {
    return 'une question à choix multiples doit avoir au moins 1 bonne réponse.';
  }
  return null;
}

/// Sérialise des questions dans le même format que l'import (export /
/// sauvegarde). `parseQuestionsJson(questionsToJson(d, qs))` redonne les
/// mêmes questions. Le JSON est indenté de 2 espaces pour rester lisible.
String questionsToJson(Discipline discipline, List<Question> questions) {
  // Boucle sur les questions ; on accumule une Map JSON par question.
  // Résultat : la liste "questions" du document.
  final questionMaps = <Map<String, Object?>>[];
  for (final question in questions) {
    questionMaps.add(_questionToMap(question));
  }
  return const JsonEncoder.withIndent('  ')
      .convert({'discipline': discipline.code, 'questions': questionMaps});
}

/// Objet JSON d'une question : texte, type, temps limite et choix.
Map<String, Object?> _questionToMap(Question question) {
  // Boucle sur les choix de la question ; on accumule une Map
  // {"text", "correct"} par choix. Résultat : la liste "choices".
  final choiceMaps = <Map<String, Object?>>[];
  for (final choice in question.choices) {
    choiceMaps.add({'text': choice.text, 'correct': choice.correct});
  }
  return {
    'text': question.text,
    'type': question.type.code,
    'timeLimit': question.timeLimitS,
    'choices': choiceMaps,
  };
}
