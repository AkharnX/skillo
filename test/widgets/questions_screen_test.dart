import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/models/discipline.dart';
import 'package:skillo/screens/admin/json_import_screen.dart';
import 'package:skillo/screens/admin/question_editor_screen.dart';
import 'package:skillo/screens/admin/questions_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() => app.close());

  testWidgets('lists the questions of the selected discipline', (tester) async {
    await tester.pumpWidget(app.wrap(const QuestionsScreen()));
    await tester.pumpAndSettle();
    final java = await app.questions.forDiscipline(Discipline.java);
    expect(find.text(java.first.text), findsOneWidget);

    await tester.tap(find.text('HTML/CSS'));
    await tester.pumpAndSettle();
    final html = await app.questions.forDiscipline(Discipline.htmlCss);
    expect(find.text(html.first.text), findsOneWidget);
    expect(find.text(java.first.text), findsNothing);
  });

  testWidgets('deleting a question removes it from the database', (
    tester,
  ) async {
    await tester.pumpWidget(app.wrap(const QuestionsScreen()));
    await tester.pumpAndSettle();
    final before = await app.questions.forDiscipline(Discipline.java);
    await tester.tap(find.byKey(Key('delete-${before.first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    final after = await app.questions.forDiscipline(Discipline.java);
    expect(after.length, before.length - 1);
    expect(find.text(before.first.text), findsNothing);
  });

  testWidgets('the editor creates a new question with its choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.wrap(const QuestionEditorScreen(discipline: Discipline.algo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('editor-text')),
      'Combien font 2+2 ?',
    );
    await tester.enterText(find.byKey(const Key('editor-time')), '15');
    await tester.enterText(find.byKey(const Key('editor-choice-0')), '4');
    await tester.enterText(find.byKey(const Key('editor-choice-1')), '5');
    await tester.tap(find.byKey(const Key('editor-correct-0')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('editor-save')));
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();

    final algo = await app.questions.forDiscipline(Discipline.algo);
    final created = algo.firstWhere((q) => q.text == 'Combien font 2+2 ?');
    expect(created.timeLimitS, 15);
    expect(created.choices.map((c) => c.text), ['4', '5']);
    expect(created.correctIndexes, {0});
  });

  testWidgets('the editor refuses a radio question without a correct answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      app.wrap(const QuestionEditorScreen(discipline: Discipline.algo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('editor-text')), 'Q');
    await tester.enterText(find.byKey(const Key('editor-time')), '15');
    await tester.enterText(find.byKey(const Key('editor-choice-0')), 'a');
    await tester.enterText(find.byKey(const Key('editor-choice-1')), 'b');
    await tester.ensureVisible(find.byKey(const Key('editor-save')));
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('exactement 1 bonne réponse'), findsOneWidget);
    expect(
      (await app.questions.forDiscipline(Discipline.algo))
          .any((q) => q.text == 'Q'),
      isFalse,
    );
  });

  testWidgets(
    'JSON import replaces the discipline, invalid JSON changes nothing',
    (tester) async {
      await tester.pumpWidget(
        app.wrap(const JsonImportScreen(discipline: Discipline.java)),
      );
      await tester.pumpAndSettle();
      final before = (await app.questions.forDiscipline(Discipline.java))
          .length;

      await tester.enterText(
        find.byKey(const Key('import-json')),
        '{"discipline":"java","questions":[]}',
      );
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('liste non vide'), findsOneWidget);
      expect(
        (await app.questions.forDiscipline(Discipline.java)).length,
        before,
      );

      await tester.enterText(
        find.byKey(const Key('import-json')),
        '{"discipline":"java","questions":[{"text":"Nouvelle","type":"radio","timeLimit":9,'
        '"choices":[{"text":"a","correct":true},{"text":"b"}]}]}',
      );
      await tester.tap(find.byKey(const Key('import-submit')));
      await tester.pumpAndSettle();
      final after = await app.questions.forDiscipline(Discipline.java);
      expect(after.length, 1);
      expect(after.single.text, 'Nouvelle');
    },
  );
}
