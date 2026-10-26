import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reine/screens/auth/register_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.close());

  testWidgets('submitting an empty form shows a required-field error per text field', (tester) async {
    await tester.pumpWidget(app.wrap(const RegisterScreen()));
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Champ obligatoire'), findsNWidgets(6));
    expect(find.text('Choisissez une motivation'), findsOneWidget);
  });

  testWidgets('an invalid email is reported', (tester) async {
    await tester.pumpWidget(app.wrap(const RegisterScreen()));
    await tester.enterText(find.byKey(const Key('register-email')), 'pas-un-email');
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Email invalide'), findsOneWidget);
  });

  testWidgets('a complete form creates the account and logs the candidate in', (tester) async {
    await tester.pumpWidget(app.wrap(const RegisterScreen()));
    await tester.enterText(find.byKey(const Key('register-last-name')), 'Dupont');
    await tester.enterText(find.byKey(const Key('register-first-name')), 'Jean');
    await tester.enterText(find.byKey(const Key('register-email')), 'jean@dupont.fr');
    await tester.enterText(find.byKey(const Key('register-age')), '22');
    await tester.enterText(find.byKey(const Key('register-address')), '1 rue de Paris');
    await tester.enterText(find.byKey(const Key('register-password')), 'secret');
    await tester.tap(find.byKey(const Key('register-motivation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconversion').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(app.auth.user, isNotNull);
    expect(app.auth.user!.fullName, 'Jean Dupont');
    expect(await app.users.login('jean@dupont.fr', 'secret'), isNotNull);
  });

}
