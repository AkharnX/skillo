/// Calcul du score d'un test (US2).
///
/// Règles : 1 point par question entièrement juste, 0 sinon ; le test est
/// réussi à partir de [kPassThresholdPercent] % de bonnes réponses.
library;

import '../models/discipline.dart';
import '../models/question.dart';
import '../models/test_result.dart';
import 'school_year.dart';

/// Pourcentage minimum pour considérer un test réussi (50 % inclus).
const kPassThresholdPercent = 50.0;

/// Une réponse est juste si l'ensemble des choix cochés est **exactement**
/// l'ensemble des bonnes réponses.
///
/// La même règle sert aux deux types de question :
///  - radio (une seule bonne réponse) : il faut avoir coché cette réponse
///    et aucune autre ;
///  - checkbox (plusieurs bonnes réponses) : il faut toutes les avoir
///    cochées et aucune mauvaise. Une réponse partielle vaut 0 point.
/// Aucune case cochée (temps écoulé) = réponse fausse.
bool isCorrectAnswer(Question question, Set<int> selectedIndexes) {
  final correctIndexes = question.correctIndexes;

  // 1. Pas le même nombre de cases cochées que de bonnes réponses : faux.
  //    (Trop peu = réponse incomplète, trop = une mauvaise réponse cochée.)
  if (selectedIndexes.length != correctIndexes.length) return false;

  // 2. Même nombre : il reste à vérifier que chaque bonne réponse est cochée.
  // Boucle sur les index des bonnes réponses ; dès qu'une bonne réponse
  // n'est pas cochée, la réponse est fausse. Si on sort de la boucle,
  // toutes les bonnes réponses sont cochées (et rien d'autre, vu l'étape 1).
  for (final index in correctIndexes) {
    if (!selectedIndexes.contains(index)) return false;
  }
  return true;
}

/// Calcule le résultat d'un test : 1 point par bonne réponse.
///
/// [answers] contient, pour chaque question (même ordre que [questions]),
/// l'ensemble des index cochés. Si [answers] est plus courte que
/// [questions] (test interrompu), les questions sans réponse comptent 0.
TestResult computeResult({
  required int userId,
  required Discipline discipline,
  required List<Question> questions,
  required List<Set<int>> answers,
  required DateTime now,
}) {
  // 1. Comptage des bonnes réponses.
  // Boucle sur les positions 0..n-1 des questions ; on accumule dans `score`
  // le nombre de questions dont la réponse est juste.
  // Résultat : score = nombre de points obtenus.
  var score = 0;
  for (var i = 0; i < questions.length; i++) {
    // Réponse donnée à la question i, ou ensemble vide s'il n'y en a pas.
    var selected = <int>{};
    if (i < answers.length) selected = answers[i];
    if (isCorrectAnswer(questions[i], selected)) score++;
  }

  // 2. Pourcentage (0 si aucune question, pour éviter la division par zéro).
  final total = questions.length;
  final percent = total == 0 ? 0.0 : score * 100 / total;

  // 3. Résultat complet, prêt à être enregistré par ResultRepository.save.
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
