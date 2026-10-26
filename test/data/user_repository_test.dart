import 'package:flutter_test/flutter_test.dart';
import 'package:reine/data/app_database.dart';
import 'package:reine/data/user_repository.dart';
import 'package:reine/models/motivation.dart';
import 'package:reine/models/user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late UserRepository repo;

  setUp(() async {
    db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = UserRepository(db);
  });
  tearDown(() => db.close());

  Future<AppUser> registerDupont({String email = 'jean@dupont.fr', String lastName = 'Dupont'}) =>
      repo.register(
        lastName: lastName,
        firstName: 'Jean',
        email: email,
        password: 'secret',
        age: 22,
        address: '1 rue de Paris',
        motivation: Motivation.reconversion,
      );

  test('register then login returns the candidate', () async {
    final created = await registerDupont();
    expect(created.id, isPositive);
    expect(created.role, 'candidate');

    final user = await repo.login('jean@dupont.fr', 'secret');
    expect(user, isNotNull);
    expect(user!.id, created.id);
    expect(user.fullName, 'Jean Dupont');
    expect(user.motivation, Motivation.reconversion);
    expect(user.isAdmin, isFalse);
  });

  test('login with a wrong password returns null', () async {
    await registerDupont();
    expect(await repo.login('jean@dupont.fr', 'nope'), isNull);
  });

  test('email is normalised: spaces and case are ignored', () async {
    await registerDupont(email: '  Jean@Dupont.FR ');
    expect(await repo.login('jean@dupont.fr', 'secret'), isNotNull);
    expect(await repo.login('JEAN@dupont.fr ', 'secret'), isNotNull);
  });

  test('same last name and email (different case) is rejected', () async {
    await registerDupont();
    expect(
      () => registerDupont(lastName: 'DUPONT', email: 'JEAN@dupont.fr'),
      throwsA(isA<DuplicateAccountException>()),
    );
  });

  test('same email with another last name is allowed', () async {
    await registerDupont();
    final other = await registerDupont(lastName: 'Durand');
    expect(other.lastName, 'Durand');
  });

  test('the seeded admin can log in', () async {
    final admin = await repo.login(kAdminEmail, kAdminPassword);
    expect(admin, isNotNull);
    expect(admin!.isAdmin, isTrue);
  });

  test('updateProfile changes address and motivation only', () async {
    final u = await registerDupont();
    final updated = await repo.updateProfile(
      u.id,
      address: '2 avenue de Lyon',
      motivation: Motivation.poursuiteEtudes,
    );
    expect(updated.address, '2 avenue de Lyon');
    expect(updated.motivation, Motivation.poursuiteEtudes);
    expect(updated.email, 'jean@dupont.fr');
    expect((await repo.byId(u.id))!.address, '2 avenue de Lyon');
  });
}
