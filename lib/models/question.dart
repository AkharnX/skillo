/// Modèles d'une question de test et de ses choix de réponse.
///
/// Ces classes sont **immuables** (tous les champs sont `final`) : pour
/// modifier une question on crée une copie avec `copyWith`. C'est ce qui
/// permet à l'éditeur admin de préparer un brouillon sans toucher à
/// l'original tant que l'admin n'a pas cliqué sur « Enregistrer ».
library;

import 'discipline.dart';

/// Type de question : une seule bonne réponse (radio) ou plusieurs (checkbox).
///
/// Le [code] est stocké en base et dans les JSON ; le [label] est affiché
/// dans l'éditeur de questions.
enum QuestionType {
  radio('radio', 'Choix unique'),
  checkbox('checkbox', 'Choix multiples');

  const QuestionType(this.code, this.label);

  /// Code stocké en base ('radio' / 'checkbox').
  final String code;

  /// Libellé affiché à l'écran.
  final String label;

  /// Retrouve le type à partir de son code, ou null s'il est inconnu.
  /// Utilisé par l'import JSON, qui veut produire un message d'erreur.
  static QuestionType? fromCodeOrNull(String code) {
    // Boucle sur les valeurs de l'énumération ; dès que le code correspond,
    // on renvoie le type. Si on sort de la boucle, aucun ne correspond.
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }

  /// Retrouve le type à partir de son code. Lève une [ArgumentError] si le
  /// code est inconnu ; en pratique impossible pour une valeur lue en base,
  /// car la colonne `type` a une contrainte CHECK.
  static QuestionType fromCode(String code) {
    final type = fromCodeOrNull(code);
    if (type == null) throw ArgumentError('Type de question inconnu : $code');
    return type;
  }
}

/// Un choix de réponse proposé sous une question.
class Choice {
  const Choice({this.id, required this.text, this.correct = false});

  /// Id en base, ou null tant que le choix n'a pas été enregistré.
  final int? id;

  /// Texte affiché à côté de la case / du bouton radio.
  final String text;

  /// True si ce choix fait partie des bonnes réponses.
  final bool correct;

  /// Copie du choix avec un nouveau texte et/ou une nouvelle valeur de
  /// [correct]. L'id est conservé.
  Choice copyWith({String? text, bool? correct}) =>
      Choice(id: id, text: text ?? this.text, correct: correct ?? this.correct);
}

/// Une question d'un test, avec ses choix de réponse.
class Question {
  const Question({
    this.id,
    required this.discipline,
    required this.text,
    required this.type,
    required this.timeLimitS,
    required this.choices,
  });

  /// Id en base, ou null tant que la question n'a pas été enregistrée.
  final int? id;

  /// Discipline à laquelle la question appartient.
  final Discipline discipline;

  /// Énoncé de la question.
  final String text;

  /// Une seule bonne réponse (radio) ou plusieurs (checkbox).
  final QuestionType type;

  /// Temps limite pour répondre, en secondes (US2, US5). Quand il est écoulé,
  /// l'écran de test passe à la question suivante.
  final int timeLimitS;

  /// Choix proposés, dans l'ordre d'affichage.
  final List<Choice> choices;

  /// Index (positions dans [choices]) des bonnes réponses.
  ///
  /// Un `Set` plutôt qu'une liste parce que l'ordre n'a pas d'importance :
  /// la correction compare l'ensemble coché à cet ensemble (voir
  /// `isCorrectAnswer`).
  Set<int> get correctIndexes {
    // Boucle sur les positions 0..n-1 des choix ; on accumule la position
    // de chaque choix marqué correct. Résultat : {1} pour une question radio
    // dont la 2e réponse est la bonne, {0, 2} pour une checkbox, etc.
    final indexes = <int>{};
    for (var i = 0; i < choices.length; i++) {
      if (choices[i].correct) indexes.add(i);
    }
    return indexes;
  }

  /// Copie de la question en remplaçant seulement les champs fournis.
  Question copyWith({
    int? id,
    Discipline? discipline,
    String? text,
    QuestionType? type,
    int? timeLimitS,
    List<Choice>? choices,
  }) => Question(
    id: id ?? this.id,
    discipline: discipline ?? this.discipline,
    text: text ?? this.text,
    type: type ?? this.type,
    timeLimitS: timeLimitS ?? this.timeLimitS,
    choices: choices ?? this.choices,
  );
}
