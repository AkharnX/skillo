import '../models/discipline.dart';
import '../models/question.dart';
import '../models/test_result.dart';
import 'school_year.dart';

/// Pourcentage minimum pour considérer un test réussi.
const kPassThresholdPercent = 50.0;

/// Une réponse est juste si l'ensemble des choix cochés est exactement
/// l'ensemble des bonnes réponses (valable pour radio et checkbox).
bool isCorrectAnswer(Question question, Set<int> selectedIndexes) {
  final correct = question.correctIndexes;
  return selectedIndexes.length == correct.length &&
      selectedIndexes.containsAll(correct);
}

/// Calcule le résultat d'un test : 1 point par bonne réponse.
/// [answers] contient, pour chaque question (même ordre), les index cochés.
TestResult computeResult({
  required int userId,
  required Discipline discipline,
  required List<Question> questions,
  required List<Set<int>> answers,
  required DateTime now,
}) {
  var score = 0;
  for (var i = 0; i < questions.length; i++) {
    final selected = i < answers.length ? answers[i] : <int>{};
    if (isCorrectAnswer(questions[i], selected)) score++;
  }
  final total = questions.length;
  final percent = total == 0 ? 0.0 : score * 100 / total;
  return TestResult(
    userId: userId,
    discipline: discipline,
    score: score,
    total: total,
    percent: percent,
    passed: percent >= kPassThresholdPercent,
    schoolYear: schoolYearFor(now),
    takenAt: now,
  );
}
