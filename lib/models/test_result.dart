/// Modèle d'un résultat de test : une ligne de la table `results`.
library;

import 'discipline.dart';

/// Résultat d'un candidat à un test (une ligne de la table `results`).
///
/// Les conversions vers / depuis la base sont regroupées ici ([toRow] et
/// [fromRow]) pour que le reste du code ne manipule jamais les noms de
/// colonnes SQL.
class TestResult {
  const TestResult({
    this.id,
    required this.userId,
    required this.discipline,
    required this.score,
    required this.total,
    required this.percent,
    required this.passed,
    required this.schoolYear,
    required this.takenAt,
    this.candidateName,
  });

  /// Id en base, ou null tant que le résultat n'a pas été enregistré.
  final int? id;

  /// Id du candidat (table `users`).
  final int userId;

  /// Discipline du test passé.
  final Discipline discipline;

  /// Nombre de bonnes réponses.
  final int score;

  /// Nombre de questions du test.
  final int total;

  /// `score * 100 / total`, entre 0 et 100.
  final double percent;

  /// True si [percent] atteint le seuil de réussite (voir `scoring.dart`).
  final bool passed;

  /// Année scolaire du passage, ex. « 2026-2027 » (voir `school_year.dart`).
  final String schoolYear;

  /// Date et heure du passage.
  final DateTime takenAt;

  /// Nom complet du candidat. Rempli uniquement par les requêtes admin qui
  /// font une jointure avec `users` (`ResultRepository.recent`), null sinon.
  final String? candidateName;

  /// Colonnes à écrire en base. L'id n'y figure pas (généré par la base).
  /// Les booléens deviennent 1 / 0 et la date un texte ISO 8601, car SQLite
  /// n'a ni type booléen ni type date.
  Map<String, Object?> toRow() => {
    'user_id': userId,
    'discipline': discipline.code,
    'score': score,
    'total': total,
    'percent': percent,
    'passed': passed ? 1 : 0,
    'school_year': schoolYear,
    'taken_at': takenAt.toIso8601String(),
  };

  /// Construit un résultat à partir d'une ligne SQL (opération inverse de
  /// [toRow]). `percent` est lu comme `num` car SQLite peut renvoyer un
  /// entier pour une colonne REAL quand la valeur est ronde (0 au lieu de 0.0).
  factory TestResult.fromRow(Map<String, Object?> row) => TestResult(
    id: row['id'] as int,
    userId: row['user_id'] as int,
    discipline: Discipline.fromCode(row['discipline'] as String),
    score: row['score'] as int,
    total: row['total'] as int,
    percent: (row['percent'] as num).toDouble(),
    passed: row['passed'] == 1,
    schoolYear: row['school_year'] as String,
    takenAt: DateTime.parse(row['taken_at'] as String),
    candidateName: row['candidate_name'] as String?,
  );
}
