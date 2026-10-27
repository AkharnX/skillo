import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/models/motivation.dart';
import 'package:skillo/models/question.dart';
import 'package:skillo/screens/candidate/test_result_screen.dart';
import 'package:skillo/screens/candidate/test_screen.dart';

import 'test_app.dart';

Question q(
  String text, {
  int timeLimit = 10,
  QuestionType type = QuestionType.radio,
}) => Question(
  discipline: Discipline.java,
  text: text,
  type: type,
  timeLimitS: timeLimit,
  choices: const [
    Choice(text: 'Bonne', correct: true),
    Choice(text: 'Mauvaise'),
  ],
);

void main() {
  late TestApp app;
  setUp(() async {
    app = await TestApp.create();
    await app.auth.register(
      lastName: 'D',
      firstName: 'J',
      email: 'j@d.fr',
      password: 'x',
      age: 20,
      address: 'a',
      motivation: Motivation.reconversion,
    );
  });
  tearDown(() => app.close());

  testWidgets('when the time runs out the next question is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.wrap(
        TestScreen(
          discipline: Discipline.java,
          questions: [q('Question A', timeLimit: 2), q('Question B')],
        ),
      ),
    );
    expect(find.text('Question A'), findsOneWidget);
    expect(find.text('2 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Question A'), findsNothing);
    expect(find.text('Question B'), findsOneWidget);
    expect(find.text('10 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('9 s'), findsOneWidget);
  });

  testWidgets(
    'answering correctly then validating shows the result and saves it',
    (tester) async {
      await tester.pumpWidget(
        app.wrap(
          TestScreen(
            discipline: Discipline.java,
            questions: [q('Seule question')],
          ),
        ),
      );
      await tester.tap(find.text('Bonne'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('test-validate')));
      await tester.pumpAndSettle();

      expect(find.byType(TestResultScreen), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      final saved = await app.results.forUser(app.auth.user!.id);
      expect(saved.single.discipline, Discipline.java);
      expect(saved.single.score, 1);
      expect(saved.single.passed, isTrue);
    },
  );

  testWidgets('a checkbox question with no selection counts as wrong', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.wrap(
        TestScreen(
          discipline: Discipline.java,
          questions: [q('Cases', type: QuestionType.checkbox, timeLimit: 1)],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('0 / 1'), findsOneWidget);
    expect(
      (await app.results.forUser(app.auth.user!.id)).single.passed,
      isFalse,
    );
  });

  testWidgets('a double click on Valider does not skip a question', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.wrap(
        TestScreen(
          discipline: Discipline.java,
          questions: [q('Question A'), q('Question B'), q('Question C')],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('test-validate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('test-validate')));
    await tester.pump();
    expect(find.text('Question B'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('test-validate')));
    await tester.pump();
    expect(find.text('Question C'), findsOneWidget);
  });
}
