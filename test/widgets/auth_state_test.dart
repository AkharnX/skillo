import 'package:flutter_test/flutter_test.dart';
import 'package:reine/data/app_database.dart';
import 'package:reine/models/motivation.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() => app.close());

  test('login with wrong credentials returns a message and keeps user null', () async {
    final error = await app.auth.login('nobody@x.fr', 'x');
    expect(error, 'Email ou mot de passe incorrect');
    expect(app.auth.user, isNull);
  });

  test('login as admin sets an admin user', () async {
    expect(await app.auth.login(kAdminEmail, kAdminPassword), isNull);
    expect(app.auth.user!.isAdmin, isTrue);
    app.auth.logout();
    expect(app.auth.user, isNull);
  });

  test('register twice with the same name and email returns the duplicate message', () async {
    Future<String?> go() => app.auth.register(
          lastName: 'Dupont', firstName: 'Jean', email: 'jean@dupont.fr', password: 'x',
          age: 20, address: 'a', motivation: Motivation.reconversion,
        );
    expect(await go(), isNull);
    app.auth.logout();
    expect(await go(), 'Un compte existe déjà avec ce nom et cet email.');
  });

  test('refresh reloads the user from the database', () async {
    await app.auth.register(
      lastName: 'Dupont', firstName: 'Jean', email: 'jean@dupont.fr', password: 'x',
      age: 20, address: 'a', motivation: Motivation.reconversion,
    );
    await app.users.updateProfile(app.auth.user!.id, address: 'b');
    await app.auth.refresh();
    expect(app.auth.user!.address, 'b');
  });
}
