import 'discipline.dart';

/// Résultat d'un candidat à un test (une ligne de la table `results`).
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

  final int? id;
  final int userId;
  final Discipline discipline;
  final int score;
  final int total;
  final double percent;
  final bool passed;
  final String schoolYear;
  final DateTime takenAt;

  /// Rempli par les requêtes admin (jointure avec `users`).
  final String? candidateName;

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
