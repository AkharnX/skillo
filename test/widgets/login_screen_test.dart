import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillo/data/app_database.dart';
import 'package:skillo/screens/auth/login_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() => app.close());

  testWidgets('wrong credentials show an error message', (tester) async {
    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.enterText(find.byKey(const Key('login-email')), 'x@y.fr');
    await tester.enterText(find.byKey(const Key('login-password')), 'bad');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email ou mot de passe incorrect'), findsOneWidget);
    expect(app.auth.user, isNull);
  });

  testWidgets('admin credentials log the admin in', (tester) async {
    await tester.pumpWidget(app.wrap(const LoginScreen()));
    await tester.enterText(find.byKey(const Key('login-email')), kAdminEmail);
    await tester.enterText(
      find.byKey(const Key('login-password')),
      kAdminPassword,
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(app.auth.user?.isAdmin, isTrue);
  });
}
