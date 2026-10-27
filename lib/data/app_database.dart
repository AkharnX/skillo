/// Ouverture de la base SQLite, création du schéma et données initiales.
///
/// Ce fichier est le point d'entrée de la couche « données » :
///  1. [openAppDatabase] ouvre (ou crée) le fichier `reine.db` ;
///  2. [_createSchema] crée les 4 tables (`users`, `questions`, `choices`,
///     `results`) et les index d'unicité la première fois ;
///  3. [seedIfEmpty] insère le compte admin et les questions par défaut
///     livrées dans `assets/questions/` si la base est vide.
///
/// Les repositories (`UserRepository`, `QuestionRepository`,
/// `ResultRepository`) reçoivent ensuite la [Database] ouverte ici.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common/sqlite_api.dart';

import 'db_factory.dart';
import 'password.dart';

export 'package:sqflite_common/sqlite_api.dart' show Database;

export 'password.dart';

/// Email du compte administrateur pré-existant (US4). L'admin n'a pas de
/// formulaire d'inscription : son compte est inséré par [seedIfEmpty].
const kAdminEmail = 'admin@reine.app';

/// Mot de passe de l'admin. Il est haché avant d'être stocké (voir
/// `password.dart`), seul son hash est en base.
const kAdminPassword = 'admin123';

/// Codes des disciplines, dans l'ordre d'affichage. Chaque code correspond à
/// un fichier `assets/questions/<code>.json` et à une valeur de l'énumération
/// `Discipline`.
const kDisciplineCodes = ['java', 'algo', 'html_css'];

/// Nom du fichier SQLite sur le disque (ou dans le stockage du navigateur).
const _dbName = 'reine.db';

/// Version du schéma. À incrémenter si on modifie les tables, pour déclencher
/// une migration (`onUpgrade`) sur les bases déjà installées.
const _schemaVersion = 1;

/// Ouvre (et crée si besoin) la base SQLite de l'application.
///
/// [factory] et [path] servent aux tests : on passe `databaseFactoryFfi` et
/// `inMemoryDatabasePath` pour avoir une base vide en mémoire à chaque test.
/// En production, les deux sont `null` et l'implémentation dépend de la
/// plateforme (voir `db_factory.dart`).
///
/// `PRAGMA foreign_keys = ON` est indispensable : SQLite ignore les clés
/// étrangères (et donc les `ON DELETE CASCADE`) tant qu'on ne l'active pas.
Future<Database> openAppDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  // 1. Choix de la fabrique et du chemin du fichier.
  final f = factory ?? platformDatabaseFactory();
  final dbPath = path ?? '${await f.getDatabasesPath()}/$_dbName';

  // 2. Ouverture : `onCreate` n'est appelé que si le fichier n'existe pas.
  final db = await f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: _schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db),
    ),
  );

  // 3. Données de départ (admin + questions) si les tables sont vides.
  await seedIfEmpty(db);
  return db;
}

/// Crée toutes les tables et index. Appelé une seule fois, à la création du
/// fichier de base.
Future<void> _createSchema(Database db) async {
  // Table des utilisateurs (candidats et admin).
  //  - role : 'candidate' ou 'admin', vérifié par la contrainte CHECK ;
  //  - password_hash : empreinte SHA-256, jamais le mot de passe en clair ;
  //  - created_at : date d'inscription au format ISO 8601 (texte).
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

  // US1 : un compte unique par combinaison Nom + Email.
  // Index UNIQUE : la base refuse elle-même un doublon, même si le code
  // oubliait de vérifier. `COLLATE NOCASE` rend la comparaison insensible à
  // la casse : « DUPONT / Jean@Dupont.fr » et « dupont / jean@dupont.fr »
  // sont considérés comme le même compte.
  await db.execute(
    'CREATE UNIQUE INDEX ux_users_name_email '
    'ON users (last_name COLLATE NOCASE, email COLLATE NOCASE)',
  );

  // Table des questions. Une question appartient à une discipline (code
  // texte : 'java', 'algo', 'html_css'), a un type ('radio' = une seule bonne
  // réponse, 'checkbox' = plusieurs) et un temps limite en secondes (> 0).
  await db.execute('''
    CREATE TABLE questions (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      discipline   TEXT    NOT NULL,
      text         TEXT    NOT NULL,
      type         TEXT    NOT NULL CHECK (type IN ('radio', 'checkbox')),
      time_limit_s INTEGER NOT NULL CHECK (time_limit_s > 0)
    )''');

  // Table des choix de réponse. Chaque ligne appartient à une question
  // (`question_id`). `ON DELETE CASCADE` : supprimer une question supprime
  // automatiquement ses choix. `is_correct` vaut 1 (bonne réponse) ou 0.
  await db.execute('''
    CREATE TABLE choices (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      question_id INTEGER NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
      text        TEXT    NOT NULL,
      is_correct  INTEGER NOT NULL DEFAULT 0
    )''');

  // Table des résultats : un candidat (`user_id`) a passé le test d'une
  // discipline. On garde le score brut, le total de questions, le pourcentage,
  // réussi ou non (1/0), l'année scolaire (« 2026-2027 ») pour les filtres
  // admin, la date de passage et `finished` (0 = test commencé mais pas
  // terminé, voir `ResultRepository.start`).
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
      taken_at    TEXT    NOT NULL,
      finished    INTEGER NOT NULL DEFAULT 1
    )''');

  // US2 : chaque test ne peut être passé qu'une seule fois par candidat.
  // L'index UNIQUE sur (user_id, discipline) garantit qu'il n'existe jamais
  // deux lignes de résultat pour le même candidat et la même discipline.
  await db.execute(
    'CREATE UNIQUE INDEX ux_results_user_discipline ON results (user_id, discipline)',
  );
}

/// Insère le compte admin et les questions par défaut si les tables sont
/// vides. Appelé à chaque ouverture : la fonction vérifie d'abord ce qui
/// existe, donc la rappeler ne duplique rien.
Future<void> seedIfEmpty(Database db) async {
  // 1. Compte admin : on l'insère seulement s'il n'y a aucun admin.
  final admins = await db.query(
    'users',
    where: 'role = ?',
    whereArgs: ['admin'],
  );
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

  // 2. Questions : on regarde s'il existe au moins une question. Si la table
  //    est vide, on charge les trois fichiers JSON des assets.
  final questions = await db.query('questions', limit: 1);
  if (questions.isEmpty) {
    // Boucle sur les codes de discipline ('java', 'algo', 'html_css').
    // Pour chacun : on lit son fichier JSON puis on insère ses questions.
    // À la fin, la table `questions` contient les questions des 3 disciplines.
    for (final code in kDisciplineCodes) {
      final json = await loadDefaultQuestionsJson(code);
      await insertQuestionsFromJson(db, code, json);
    }
  }
}

/// Lit `assets/questions/<discipline>.json` et le décode en Map.
/// Le format du fichier est décrit dans `assets/questions/README.md`.
Future<Map<String, dynamic>> loadDefaultQuestionsJson(String discipline) async {
  final raw = await rootBundle.loadString('assets/questions/$discipline.json');
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Insère les questions d'un JSON (format des assets) pour une discipline.
///
/// Utilisé uniquement au premier démarrage par [seedIfEmpty]. Le JSON des
/// assets est supposé valide (il est vérifié par les tests) : on ne refait
/// pas ici la validation de `parseQuestionsMap`, réservée à l'import admin.
///
/// Les questions sont insérées une par une (on a besoin de l'`id` généré
/// pour rattacher les choix), les choix sont regroupés dans un `batch`
/// envoyé en une seule fois à la fin, ce qui est plus rapide.
Future<void> insertQuestionsFromJson(
  Database db,
  String discipline,
  Map<String, dynamic> json,
) async {
  final batch = db.batch();

  // Boucle sur chaque question du JSON. Pour chacune : on insère la ligne
  // dans `questions`, on récupère son id, puis on prépare ses choix.
  // À la fin, toutes les questions sont en base et tous les choix sont dans
  // le batch.
  for (final q in json['questions'] as List) {
    final question = q as Map<String, dynamic>;
    final questionId = await db.insert('questions', {
      'discipline': discipline,
      'text': question['text'],
      'type': question['type'],
      'time_limit_s': question['timeLimit'],
    });

    // Boucle sur les choix de cette question : chaque choix devient une
    // ligne de `choices` ajoutée au batch, rattachée à `questionId`.
    // `correct` absent ou false -> is_correct = 0.
    for (final c in question['choices'] as List) {
      final choice = c as Map<String, dynamic>;
      batch.insert('choices', {
        'question_id': questionId,
        'text': choice['text'],
        'is_correct': choice['correct'] == true ? 1 : 0,
      });
    }
  }

  // Envoi groupé de tous les choix.
  await batch.commit(noResult: true);
}
