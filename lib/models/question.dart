import 'discipline.dart';

/// Type de question : une seule bonne réponse (radio) ou plusieurs (checkbox).
enum QuestionType {
  radio('radio', 'Choix unique'),
  checkbox('checkbox', 'Choix multiples');

  const QuestionType(this.code, this.label);
  final String code;
  final String label;

  static QuestionType fromCode(String code) =>
      values.firstWhere((t) => t.code == code);
}

class Choice {
  const Choice({this.id, required this.text, this.correct = false});

  final int? id;
  final String text;
  final bool correct;

  Choice copyWith({String? text, bool? correct}) =>
      Choice(id: id, text: text ?? this.text, correct: correct ?? this.correct);
}

class Question {
  const Question({
    this.id,
    required this.discipline,
    required this.text,
    required this.type,
    required this.timeLimitS,
    required this.choices,
  });

  final int? id;
  final Discipline discipline;
  final String text;
  final QuestionType type;

  /// Temps limite pour répondre, en secondes (US2, US5).
  final int timeLimitS;
  final List<Choice> choices;

  /// Index des bonnes réponses dans [choices].
  Set<int> get correctIndexes => {
    for (var i = 0; i < choices.length; i++)
      if (choices[i].correct) i,
  };

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
