import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common/sqlite_api.dart';

import 'db_factory.dart';
import 'password.dart';

export 'package:sqflite_common/sqlite_api.dart' show Database;
export 'password.dart';

/// Compte administrateur pré-existant (US4).
const kAdminEmail = 'admin@reine.app';
const kAdminPassword = 'admin123';

/// Codes des disciplines, dans l'ordre d'affichage.
const kDisciplineCodes = ['java', 'algo', 'html_css'];

const _dbName = 'reine.db';
const _schemaVersion = 1;

/// Ouvre (et crée si besoin) la base SQLite de l'application.
///
/// [factory] et [path] servent aux tests (base en mémoire). En production
/// l'implémentation dépend de la plateforme (voir `db_factory.dart`).
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? platformDatabaseFactory();
  final dbPath = path ?? '${await f.getDatabasesPath()}/$_dbName';
  final db = await f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: _schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db),
    ),
  );
  await seedIfEmpty(db);
  return db;
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      role          TEXT    NOT NULL CHECK (role IN ('candidate', 'admin')),
      last_name     TEXT    NOT NULL,
      first_name    TEXT    NOT NULL,
      email         TEXT    NOT NULL,
      password_hash TEXT    NOT NULL,
      age           INTEGER NOT NULL,
      address       TEXT    NOT NULL,
      motivation    TEXT    NOT NULL,
      created_at    TEXT    NOT NULL
    )''');
  // US1 : un compte unique par combinaison Nom + Email (insensible à la casse).
  await db.execute(
    'CREATE UNIQUE INDEX ux_users_name_email '
    'ON users (last_name COLLATE NOCASE, email COLLATE NOCASE)',
  );
  await db.execute('''
    CREATE TABLE questions (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      discipline   TEXT    NOT NULL,
      text         TEXT    NOT NULL,
      type         TEXT    NOT NULL CHECK (type IN ('radio', 'checkbox')),
      time_limit_s INTEGER NOT NULL CHECK (time_limit_s > 0)
    )''');
  await db.execute('''
    CREATE TABLE choices (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
      text        TEXT    NOT NULL,
      is_correct  INTEGER NOT NULL DEFAULT 0
    )''');
  await db.execute('''
    CREATE TABLE results (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      discipline  TEXT    NOT NULL,
      score       INTEGER NOT NULL,
      total       INTEGER NOT NULL,
      percent     REAL    NOT NULL,
      passed      INTEGER NOT NULL,
      school_year TEXT    NOT NULL,
      taken_at    TEXT    NOT NULL
    )''');
  // US2 : chaque test ne peut être passé qu'une seule fois.
  await db.execute(
    'CREATE UNIQUE INDEX ux_results_user_discipline ON results (user_id, discipline)',
  );
}

/// Insère le compte admin et les questions par défaut si les tables sont vides.
Future<void> seedIfEmpty(Database db) async {
  final admins = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
  if (admins.isEmpty) {
    await db.insert('users', {
      'role': 'admin',
      'last_name': 'Admin',
      'first_name': 'Reine',
      'email': kAdminEmail,
      'password_hash': hashPassword(kAdminPassword),
      'age': 0,
      'address': '',
      'motivation': '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  final questions = await db.query('questions', limit: 1);
  if (questions.isEmpty) {
    for (final code in kDisciplineCodes) {
      final json = await loadDefaultQuestionsJson(code);
      await insertQuestionsFromJson(db, code, json);
    }
  }
}

/// Lit `assets/questions/<discipline>.json`.
Future<Map<String, dynamic>> loadDefaultQuestionsJson(String discipline) async {
  final raw = await rootBundle.loadString('assets/questions/$discipline.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Insère les questions d'un JSON (format des assets) pour une discipline.
Future<void> insertQuestionsFromJson(
  Database db,
  String discipline,
  Map<String, dynamic> json,
) async {
  final batch = db.batch();
  for (final q in json['questions'] as List) {
    final question = q as Map<String, dynamic>;
    final questionId = await db.insert('questions', {
      'discipline': discipline,
      'text': question['text'],
      'type': question['type'],
      'time_limit_s': question['timeLimit'],
    });
    for (final c in question['choices'] as List) {
      final choice = c as Map<String, dynamic>;
      batch.insert('choices', {
        'question_id': questionId,
        'text': choice['text'],
        'is_correct': choice['correct'] == true ? 1 : 0,
      });
    }
  }
  await batch.commit(noResult: true);
}
