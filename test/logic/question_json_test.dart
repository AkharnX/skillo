import 'package:flutter_test/flutter_test.dart';
import 'package:reine/logic/question_json.dart';
import 'package:reine/models/discipline.dart';
import 'package:reine/models/question.dart';

const valid = '''
{"discipline": "java", "questions": [
  {"text": "Q1", "type": "radio", "timeLimit": 20,
   "choices": [{"text": "a", "correct": true}, {"text": "b", "correct": false}]},
  {"text": "Q2", "type": "checkbox", "timeLimit": 30,
   "choices": [{"text": "a", "correct": true}, {"text": "b", "correct": true}, {"text": "c"}]}
]}''';

String withQuestion(String q, {String discipline = 'java'}) =>
    '{"discipline": "$discipline", "questions": [$q]}';

void main() {
  test('a valid document yields questions with their choices', () {
    final parsed = parseQuestionsJson(valid);
    expect(parsed.discipline, Discipline.java);
    expect(parsed.questions.length, 2);
    final q2 = parsed.questions[1];
    expect(q2.type, QuestionType.checkbox);
    expect(q2.timeLimitS, 30);
    expect(q2.choices.length, 3);
    expect(q2.correctIndexes, {0, 1});
    expect(q2.discipline, Discipline.java);
  });

  test('the expected discipline must match the document', () {
    expect(
      () => parseQuestionsJson(valid, expected: Discipline.algo),
      throwsA(isA<QuestionJsonException>()),
    );
  });

  test('a radio question with two correct answers is rejected', () {
    final doc = withQuestion(
      '{"text": "Q", "type": "radio", "timeLimit": 10, "choices": [{"text": "a", "correct": true}, {"text": "b", "correct": true}]}',
    );
    expect(() => parseQuestionsJson(doc), throwsA(isA<QuestionJsonException>()));
  });

  test('a question with a single choice is rejected', () {
    final doc = withQuestion(
      '{"text": "Q", "type": "radio", "timeLimit": 10, "choices": [{"text": "a", "correct": true}]}',
    );
    expect(() => parseQuestionsJson(doc), throwsA(isA<QuestionJsonException>()));
  });

  test('a time limit of 0 is rejected', () {
    final doc = withQuestion(
      '{"text": "Q", "type": "radio", "timeLimit": 0, "choices": [{"text": "a", "correct": true}, {"text": "b"}]}',
    );
    expect(() => parseQuestionsJson(doc), throwsA(isA<QuestionJsonException>()));
  });

  test('a checkbox question without any correct answer is rejected', () {
    final doc = withQuestion(
      '{"text": "Q", "type": "checkbox", "timeLimit": 10, "choices": [{"text": "a"}, {"text": "b"}]}',
    );
    expect(() => parseQuestionsJson(doc), throwsA(isA<QuestionJsonException>()));
  });

  test('an unknown discipline is rejected', () {
    final doc = withQuestion(
      '{"text": "Q", "type": "radio", "timeLimit": 10, "choices": [{"text": "a", "correct": true}, {"text": "b"}]}',
      discipline: 'php',
    );
    expect(() => parseQuestionsJson(doc), throwsA(isA<QuestionJsonException>()));
  });

  test('malformed JSON is reported as a QuestionJsonException', () {
    expect(() => parseQuestionsJson('{not json'), throwsA(isA<QuestionJsonException>()));
  });

  test('validateQuestion returns null for a valid question and a message otherwise', () {
    final ok = Question(
      discipline: Discipline.java, text: 'Q', type: QuestionType.radio, timeLimitS: 5,
      choices: const [Choice(text: 'a', correct: true), Choice(text: 'b')],
    );
    expect(validateQuestion(ok), isNull);
    expect(validateQuestion(ok.copyWith(text: '  ')), isNotNull);
  });

  test('questionsToJson round-trips through parseQuestionsJson', () {
    final parsed = parseQuestionsJson(valid);
    final again = parseQuestionsJson(questionsToJson(parsed.discipline, parsed.questions));
    expect(again.questions.length, 2);
    expect(again.questions[1].correctIndexes, {0, 1});
  });
}
