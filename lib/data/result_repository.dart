/// Accès à la table `results` : résultats des tests passés par les candidats.
///
/// Ce fichier garantit la règle « un seul passage par test » (US2) grâce à
/// [ResultRepository.start] et [ResultRepository.save], et fournit les
/// requêtes du profil candidat (US3), du tableau de bord (US6) et des
/// statistiques admin (US7).
library;

import 'package:sqflite_common/sqlite_api.dart';

import '../logic/school_year.dart';
import '../models/discipline.dart';
import '../models/test_result.dart';

/// Levée si le candidat a déjà passé ce test (US2 : un seul passage).
class AlreadyTakenException implements Exception {
  /// Message affiché tel quel à l'utilisateur.
  @override
  String toString() => 'Ce test a déjà été passé.';
}

/// Nombre de réussites et d'échecs pour un ensemble de résultats (US7).
class PassStats {
  const PassStats({required this.passed, required this.failed});

  /// Nombre de tests réussis.
  final int passed;

  /// Nombre de tests échoués.
  final int failed;

  /// Nombre total de tests passés.
  int get total => passed + failed;

  /// Taux de réussite entre 0 et 1. Vaut 0 s'il n'y a aucun résultat, pour
  /// éviter une division par zéro.
  double get rate => total == 0 ? 0.0 : passed / total;
}

/// Accès à la table `results` (US2, US3, US6, US7).
class ResultRepository {
  /// Reçoit la base déjà ouverte par `openAppDatabase`.
  ResultRepository(this._db);

  final Database _db;

  /// Marque le test comme commencé (US2).
  ///
  /// Une ligne « 0 / total, non terminé » (`finished = 0`) est écrite **tout
  /// de suite**, avant la première question. Pourquoi ? Si le candidat
  /// recharge la page ou ferme l'application pendant le test, [hasTaken]
  /// renverra déjà true : il ne pourra pas recommencer avec de nouvelles
  /// questions. S'il ne termine jamais, son résultat reste 0 / total.
  /// [save] viendra ensuite compléter cette même ligne.
  ///
  /// Lève [AlreadyTakenException] si une ligne existe déjà pour ce candidat
  /// et cette discipline.
  Future<void> start(
    int userId,
    Discipline discipline,
    int total,
    DateTime now,
  ) async {
    // 1. Refus si le test a déjà été commencé ou terminé.
    if (await hasTaken(userId, discipline)) throw AlreadyTakenException();

    // 2. Ligne provisoire : score nul, non terminée.
    await _db.insert('results', {
      'user_id': userId,
      'discipline': discipline.code,
      'score': 0,
      'total': total,
      'percent': 0.0,
      'passed': 0,
      'school_year': schoolYearFor(now),
      'taken_at': now.toIso8601String(),
      'finished': 0,
    });
  }

  /// Enregistre le résultat final d'un test.
  ///
  /// Trois cas :
  ///  - aucune ligne pour ce candidat / cette discipline : on insère ;
  ///  - une ligne « non terminée » créée par [start] : on la complète ;
  ///  - une ligne déjà terminée : on refuse ([AlreadyTakenException]).
  /// Retourne le résultat avec son id en base.
  Future<TestResult> save(TestResult r) async {
    // 1. Y a-t-il déjà une ligne pour ce candidat et cette discipline ?
    final existing = await _db.query(
      'results',
      columns: ['id', 'finished'],
      where: 'user_id = ? AND discipline = ?',
      whereArgs: [r.userId, r.discipline.code],
    );

    // 2. Colonnes à écrire : celles du résultat + finished = 1 (terminé).
    final row = r.toRow();
    row['finished'] = 1;

    // 3a. Aucune ligne : insertion classique.
    if (existing.isEmpty) {
      final id = await _db.insert('results', row);
      row['id'] = id;
      return TestResult.fromRow(row);
    }

    // 3b. Une ligne existe et est déjà terminée : second passage interdit.
    if (existing.single['finished'] == 1) throw AlreadyTakenException();

    // 3c. Ligne provisoire de start() : on la remplace par le vrai résultat.
    final id = existing.single['id'] as int;
    await _db.update('results', row, where: 'id = ?', whereArgs: [id]);
    row['id'] = id;
    return TestResult.fromRow(row);
  }

  /// True si une ligne de résultat existe (terminée ou non) pour ce candidat
  /// et cette discipline : le test ne peut plus être (re)passé.
  Future<bool> hasTaken(int userId, Discipline discipline) async {
    final rows = await _db.query(
      'results',
      columns: ['id'],
      where: 'user_id = ? AND discipline = ?',
      whereArgs: [userId, discipline.code],
    );
    return rows.isNotEmpty;
  }

  /// Résultats d'un candidat, du plus récent au plus ancien (profil, US3).
  Future<List<TestResult>> forUser(int userId) async {
    final rows = await _db.query(
      'results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'taken_at DESC',
    );

    // Boucle sur les lignes SQL ; on accumule un TestResult par ligne.
    // Résultat : la liste des résultats dans l'ordre de la requête.
    final results = <TestResult>[];
    for (final row in rows) {
      results.add(TestResult.fromRow(row));
    }
    return results;
  }

  /// Derniers résultats pour le tableau de bord admin (US6), avec le nom du
  /// candidat, recherche par nom OU prénom (insensible à la casse) et filtre
  /// par année scolaire.
  ///
  /// La requête SQL est assemblée morceau par morceau : chaque filtre actif
  /// ajoute une condition dans [conditions] et sa valeur dans [args]. Les
  /// valeurs passent toujours par des `?` (jamais concaténées dans le texte
  /// SQL) pour éviter les injections.
  Future<List<TestResult>> recent({
    String? search,
    String? schoolYear,
    int limit = 50,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    // 1. Filtre de recherche : LIKE '%terme%' sur le nom ou le prénom.
    //    LIKE est insensible à la casse pour les lettres ASCII dans SQLite.
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) {
      conditions.add('(u.last_name LIKE ? OR u.first_name LIKE ?)');
      args.add('%$term%');
      args.add('%$term%');
    }

    // 2. Filtre d'année scolaire (ex. '2026-2027').
    if (schoolYear != null && schoolYear.isNotEmpty) {
      conditions.add('r.school_year = ?');
      args.add(schoolYear);
    }

    // 3. Clause WHERE : vide, ou les conditions reliées par AND.
    var whereClause = '';
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')} ';
    }

    // 4. La limite est le dernier '?' de la requête.
    args.add(limit);

    // 5. Requête : toutes les colonnes de results (r.*) + le nom complet du
    //    candidat (prénom + espace + nom) obtenu par jointure sur users,
    //    du plus récent au plus ancien, au plus `limit` lignes.
    final rows = await _db.rawQuery(
      'SELECT r.*, (u.first_name || \' \' || u.last_name) AS candidate_name '
      'FROM results r JOIN users u ON u.id = r.user_id '
      '$whereClause'
      'ORDER BY r.taken_at DESC LIMIT ?',
      args,
    );

    // 6. Boucle sur les lignes ; on accumule un TestResult par ligne
    //    (candidate_name est lu par fromRow). Résultat : la liste affichée.
    final results = <TestResult>[];
    for (final row in rows) {
      results.add(TestResult.fromRow(row));
    }
    return results;
  }

  /// Années scolaires présentes en base, la plus récente d'abord
  /// (alimente les listes déroulantes de filtre de l'admin).
  Future<List<String>> schoolYears() async {
    // SELECT DISTINCT : chaque année une seule fois, même si 100 résultats.
    final rows = await _db.rawQuery(
      'SELECT DISTINCT school_year FROM results ORDER BY school_year DESC',
    );

    // Boucle sur les lignes ; on accumule la colonne school_year de chacune.
    // Résultat : ['2026-2027', '2025-2026', …].
    final years = <String>[];
    for (final row in rows) {
      years.add(row['school_year'] as String);
    }
    return years;
  }

  /// Réussites / échecs par discipline (US7). Toutes les disciplines sont
  /// présentes dans la Map, même sans résultat (0 / 0).
  /// [schoolYear] null = toutes les années confondues.
  Future<Map<Discipline, PassStats>> statsByDiscipline({
    String? schoolYear,
  }) async {
    // 1. Clause WHERE et arguments, selon qu'on filtre ou non par année.
    var whereClause = '';
    final args = <Object?>[];
    if (schoolYear != null) {
      whereClause = 'WHERE school_year = ? ';
      args.add(schoolYear);
    }

    // 2. Une ligne par discipline ayant au moins un résultat :
    //    `passed` = nombre de lignes où passed = 1 (SUM d'un CASE qui vaut
    //    1 ou 0), `failed` = nombre de lignes où passed = 0.
    final rows = await _db.rawQuery(
      'SELECT discipline, '
      'SUM(CASE WHEN passed = 1 THEN 1 ELSE 0 END) AS passed, '
      'SUM(CASE WHEN passed = 0 THEN 1 ELSE 0 END) AS failed '
      'FROM results $whereClause'
      'GROUP BY discipline',
      args,
    );

    // 3. Boucle sur les lignes SQL ; on accumule une Map
    //    « code de discipline -> ligne » pour retrouver vite la ligne d'une
    //    discipline. Résultat : {'java': {...}, 'algo': {...}} (les
    //    disciplines sans résultat n'y sont pas).
    final rowByCode = <String, Map<String, Object?>>{};
    for (final row in rows) {
      rowByCode[row['discipline'] as String] = row;
    }

    // 4. Boucle sur TOUTES les disciplines de l'énumération ; pour chacune on
    //    lit ses compteurs dans rowByCode (0 si elle n'a pas de ligne).
    //    Résultat : une Map complète, une entrée par discipline.
    final stats = <Discipline, PassStats>{};
    for (final discipline in Discipline.values) {
      final row = rowByCode[discipline.code];
      var passed = 0;
      var failed = 0;
      if (row != null) {
        passed = (row['passed'] as int?) ?? 0;
        failed = (row['failed'] as int?) ?? 0;
      }
      stats[discipline] = PassStats(passed: passed, failed: failed);
    }
    return stats;
  }

  /// Taux de réussite global de tous les candidats pour une année scolaire.
  Future<PassStats> globalStats(String schoolYear) =>
      _sum(statsByDiscipline(schoolYear: schoolYear));

  /// Taux de réussite global, toutes années confondues.
  Future<PassStats> globalStatsAllYears() => _sum(statsByDiscipline());

  /// Additionne les statistiques de toutes les disciplines en une seule.
  Future<PassStats> _sum(Future<Map<Discipline, PassStats>> stats) async {
    final perDiscipline = await stats;

    // Boucle sur les PassStats de chaque discipline ; on accumule les
    // réussites dans `passed` et les échecs dans `failed`.
    // Résultat : les totaux de toutes les disciplines réunies.
    var passed = 0;
    var failed = 0;
    for (final s in perDiscipline.values) {
      passed += s.passed;
      failed += s.failed;
    }
    return PassStats(passed: passed, failed: failed);
  }
}
