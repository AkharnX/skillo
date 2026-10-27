/// Écran de fin de test : score, pourcentage, réussite.
///
/// Une carte centrée affiche un anneau de progression (percent_indicator)
/// coloré en vert si le test est réussi, en rouge sinon, avec le pourcentage
/// au centre. Dessous : le badge Réussi / Échoué, un petit récapitulatif
/// (discipline, bonnes réponses, seuil, date) et un bouton de retour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../logic/scoring.dart';
import '../../models/test_result.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// Écran de résultat d'un test, affiché à la place de l'écran de test.
class TestResultScreen extends StatelessWidget {
  const TestResultScreen({super.key, required this.result});

  /// Résultat calculé et enregistré par l'écran de test.
  final TestResult result;

  /// Retour à l'accueil candidat : on dépile toutes les routes jusqu'à la
  /// première (le routeur d'accueil).
  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Couleur du résultat : vert si réussi, rouge sinon.
    final color = result.passed ? AppColors.success : AppColors.danger;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: Text('Résultat ${result.discipline.label}')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Carte principale : anneau + verdict + récapitulatif.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        // Anneau de score, animé de 0 au pourcentage obtenu.
                        CircularPercentIndicator(
                          radius: 84,
                          lineWidth: 14,
                          percent: (result.percent / 100).clamp(0.0, 1.0),
                          animation: true,
                          animationDuration: 800,
                          curve: Curves.easeOutCubic,
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor: color,
                          backgroundColor: color.withValues(alpha: 0.12),
                          center: Text(
                            '${result.percent.round()} %',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Verdict.
                        Text(
                          result.passed ? 'Test réussi !' : 'Test échoué',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusChip.passFail(result.passed),
                        const SizedBox(height: 8),
                        Text(
                          result.passed
                              ? 'Bravo, vous avez atteint le seuil de réussite.'
                              : 'Le seuil de réussite n\'est pas atteint.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Récapitulatif ligne par ligne.
                        _SummaryRow(
                          icon: AppColors.iconForDiscipline(result.discipline),
                          iconColor: AppColors.forDiscipline(result.discipline),
                          label: 'Discipline',
                          value: result.discipline.label,
                        ),
                        _SummaryRow(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: color,
                          label: 'Bonnes réponses',
                          value: '${result.score} / ${result.total}',
                        ),
                        _SummaryRow(
                          icon: Icons.flag_outlined,
                          iconColor: AppColors.primary,
                          label: 'Seuil de réussite',
                          value: '${kPassThresholdPercent.round()} %',
                        ),
                        _SummaryRow(
                          icon: Icons.event_outlined,
                          iconColor: AppColors.muted,
                          label: 'Date',
                          value: dateFormat.format(result.takenAt),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),

                // 2. Retour à l'accueil.
                FilledButton.icon(
                  onPressed: () => _goHome(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text("Retour à l'accueil"),
                ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne du récapitulatif : icône, libellé à gauche, valeur en gras à droite.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
