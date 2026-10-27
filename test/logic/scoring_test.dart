import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/logic/scoring.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/question.dart';

Question radio() => Question(
  discipline: Discipline.java,
  text: 'q',
  type: QuestionType.radio,
  timeLimitS: 10,
  choices: [
    Choice(text: 'a'),
    Choice(text: 'b', correct: true),
    Choice(text: 'c'),
  ],
);

Question checkbox() => Question(
  discipline: Discipline.java,
  text: 'q',
  type: QuestionType.checkbox,
  timeLimitS: 10,
  choices: [
    Choice(text: 'a', correct: true),
    Choice(text: 'b'),
    Choice(text: 'c', correct: true),
  ],
);

void main() {
  group('isCorrectAnswer', () {
    test('radio: the correct choice selected is correct', () {
      expect(isCorrectAnswer(radio(), {1}), isTrue);
    });
    test('radio: a wrong choice is incorrect', () {
      expect(isCorrectAnswer(radio(), {0}), isFalse);
    });
    test('radio: no selection is incorrect', () {
      expect(isCorrectAnswer(radio(), {}), isFalse);
    });
    test('checkbox: exactly the correct set is correct', () {
      expect(isCorrectAnswer(checkbox(), {0, 2}), isTrue);
    });
    test('checkbox: a partial selection is incorrect', () {
      expect(isCorrectAnswer(checkbox(), {0}), isFalse);
    });
    test('checkbox: a superset selection is incorrect', () {
      expect(isCorrectAnswer(checkbox(), {0, 1, 2}), isFalse);
    });
  });

  group('computeResult', () {
    final questions = [radio(), radio(), checkbox(), checkbox()];

    test('2 correct out of 4 gives 50% and passes', () {
      final r = computeResult(
        userId: 7,
        discipline: Discipline.algo,
        questions: questions,
        answers: [
          {1},
          {0},
          {0, 2},
          {1},
        ],
        now: DateTime(2026, 10, 26),
      );
      expect(r.userId, 7);
      expect(r.discipline, Discipline.algo);
      expect(r.score, 2);
      expect(r.total, 4);
      expect(r.percent, 50.0);
      expect(r.passed, isTrue);
      expect(r.schoolYear, '2026-2027');
      expect(r.takenAt, DateTime(2026, 10, 26));
    });

    test('1 correct out of 4 fails', () {
      final r = computeResult(
        userId: 7,
        discipline: Discipline.algo,
        questions: questions,
        answers: [
          {1},
          {0},
          {0},
          {1},
        ],
        now: DateTime(2026, 10, 26),
      );
      expect(r.score, 1);
      expect(r.percent, 25.0);
      expect(r.passed, isFalse);
    });
  });
}
