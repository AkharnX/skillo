import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:skillo/data/app_database.dart';
import 'package:skillo/data/question_repository.dart';
import 'package:skillo/data/result_repository.dart';
import 'package:skillo/data/user_repository.dart';
import 'package:skillo/state/auth_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en mémoire + providers, pour les tests de widgets.
class TestApp {
  TestApp._(this.db);

  final Database db;
  late final users = UserRepository(db);
  late final questions = QuestionRepository(db);
  late final results = ResultRepository(db);
  late final auth = AuthState(users);

  static Future<TestApp> create() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    // Sans isolate : indispensable dans les tests de widgets (zone FakeAsync).
    final db = await openAppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    return TestApp._(db);
  }

  /// Enveloppe [home] avec les mêmes providers que l'application réelle.
  Widget wrap(Widget home) => MultiProvider(
    providers: [
      Provider<Database>.value(value: db),
      Provider<UserRepository>.value(value: users),
      Provider<QuestionRepository>.value(value: questions),
      Provider<ResultRepository>.value(value: results),
      ChangeNotifierProvider<AuthState>.value(value: auth),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> close() => db.close();
}
