import 'package:sqflite_common/sqlite_api.dart';

import '../logic/school_year.dart';
import '../models/discipline.dart';
import '../models/test_result.dart';

/// Levée si le candidat a déjà passé ce test (US2 : un seul passage).
class AlreadyTakenException implements Exception {
  @override
  String toString() => 'Ce test a déjà été passé.';
}

/// Réussites / échecs pour un ensemble de résultats (US7).
class PassStats {
  const PassStats({required this.passed, required this.failed});
  final int passed;
  final int failed;
  int get total => passed + failed;

  /// Taux de réussite entre 0 et 1 (0 s'il n'y a aucun résultat).
  double get rate => total == 0 ? 0.0 : passed / total;
}

/// Accès à la table `results` (US2, US3, US6, US7).
class ResultRepository {
  ResultRepository(this._db);

  final Database _db;

  /// Marque le test comme commencé (US2) : une ligne « 0 / total, non
  /// terminé » est écrite tout de suite. Ainsi, recharger la page ou fermer
  /// l'application pendant le test ne permet pas de le repasser.
  Future<void> start(
    int userId,
    Discipline discipline,
    int total,
    DateTime now,
  ) async {
    if (await hasTaken(userId, discipline)) throw AlreadyTakenException();
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

  /// Enregistre le résultat final. Complète la ligne créée par [start] si
  /// elle existe ; refuse si un résultat terminé existe déjà.
  Future<TestResult> save(TestResult r) async {
    final existing = await _db.query(
      'results',
      columns: ['id', 'finished'],
      where: 'user_id = ? AND discipline = ?',
      whereArgs: [r.userId, r.discipline.code],
    );
    final row = {...r.toRow(), 'finished': 1};
    if (existing.isEmpty) {
      final id = await _db.insert('results', row);
      return TestResult.fromRow({...row, 'id': id});
    }
    if (existing.single['finished'] == 1) throw AlreadyTakenException();
    final id = existing.single['id'] as int;
    await _db.update('results', row, where: 'id = ?', whereArgs: [id]);
    return TestResult.fromRow({...row, 'id': id});
  }

  Future<bool> hasTaken(int userId, Discipline discipline) async {
    final rows = await _db.query(
      'results',
      columns: ['id'],
      where: 'user_id = ? AND discipline = ?',
      whereArgs: [userId, discipline.code],
    );
    return rows.isNotEmpty;
  }

  /// Résultats d'un candidat (affichés sur son profil, US3).
  Future<List<TestResult>> forUser(int userId) async {
    final rows = await _db.query(
      'results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'taken_at DESC',
    );
    return rows.map(TestResult.fromRow).toList();
  }

  /// Derniers résultats pour le tableau de bord admin (US6), avec le nom du
  /// candidat, recherche par nom OU prénom (insensible à la casse) et filtre
  /// par année scolaire.
  Future<List<TestResult>> recent({
    String? search,
    String? schoolYear,
    int limit = 50,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) {
      where.add('(u.last_name LIKE ? OR u.first_name LIKE ?)');
      args.addAll(['%$term%', '%$term%']);
    }
    if (schoolYear != null && schoolYear.isNotEmpty) {
      where.add('r.school_year = ?');
      args.add(schoolYear);
    }
    final rows = await _db.rawQuery(
      'SELECT r.*, (u.first_name || \' \' || u.last_name) AS candidate_name '
      'FROM results r JOIN users u ON u.id = r.user_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
      'ORDER BY r.taken_at DESC LIMIT ?',
      [...args, limit],
    );
    return rows.map(TestResult.fromRow).toList();
  }

  /// Années scolaires présentes en base, la plus récente d'abord.
  Future<List<String>> schoolYears() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT school_year FROM results ORDER BY school_year DESC',
    );
    return rows.map((r) => r['school_year'] as String).toList();
  }

  /// Réussites / échecs par discipline (toutes les disciplines sont présentes,
  /// même sans résultat). [schoolYear] null = toutes les années.
  Future<Map<Discipline, PassStats>> statsByDiscipline({
    String? schoolYear,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT discipline, '
      'SUM(CASE WHEN passed = 1 THEN 1 ELSE 0 END) AS passed, '
      'SUM(CASE WHEN passed = 0 THEN 1 ELSE 0 END) AS failed '
      'FROM results ${schoolYear == null ? '' : 'WHERE school_year = ? '}'
      'GROUP BY discipline',
      [?schoolYear],
    );
    final byCode = {for (final r in rows) r['discipline'] as String: r};
    return {
      for (final d in Discipline.values)
        d: PassStats(
          passed: (byCode[d.code]?['passed'] as int?) ?? 0,
          failed: (byCode[d.code]?['failed'] as int?) ?? 0,
        ),
    };
  }

  /// Taux de réussite global de tous les candidats pour une année scolaire.
  Future<PassStats> globalStats(String schoolYear) =>
      _sum(statsByDiscipline(schoolYear: schoolYear));

  /// Taux de réussite global, toutes années confondues.
  Future<PassStats> globalStatsAllYears() => _sum(statsByDiscipline());

  Future<PassStats> _sum(Future<Map<Discipline, PassStats>> stats) async {
    final perDiscipline = await stats;
    var passed = 0;
    var failed = 0;
    for (final s in perDiscipline.values) {
      passed += s.passed;
      failed += s.failed;
    }
    return PassStats(passed: passed, failed: failed);
  }
}
