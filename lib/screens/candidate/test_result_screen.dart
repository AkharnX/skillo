/// Écran de fin de test : score, pourcentage, réussite.
///
/// Une carte centrée affiche un anneau de progression (percent_indicator)
/// vert si le test est réussi, rouge sinon, avec le pourcentage en Space Grotesk au
/// centre. Dessous : le verdict en Space Grotesk, le badge Réussi / Échoué, puis un
/// bloc récapitulatif ligne par ligne (discipline, bonnes réponses en chasse
/// fixe, seuil, date) et un bouton de retour à l'accueil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../logic/scoring.dart';
import '../../models/test_result.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
                          radius: 90,
                          lineWidth: 14,
                          percent: (result.percent / 100).clamp(0.0, 1.0),
                          animation: true,
                          animationDuration: 800,
                          curve: Curves.easeOutCubic,
                          circularStrokeCap: CircularStrokeCap.round,
                          progressColor: color,
                          backgroundColor: AppColors.border,
                          center: Text(
                            '${result.percent.round()} %',
                            style: AppText.number(34, color: color),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Verdict en Space Grotesk, badge, phrase d'explication.
                        Text(
                          result.passed ? 'Test réussi !' : 'Test échoué',
                          textAlign: TextAlign.center,
                          style: AppText.display(24),
                        ),
                        const SizedBox(height: 10),
                        StatusChip.passFail(result.passed),
                        const SizedBox(height: 10),
                        Text(
                          result.passed
                              ? 'Bravo, vous avez atteint le seuil de réussite.'
                              : 'Le seuil de réussite n\'est pas atteint.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),

                        // Récapitulatif : un bloc gris clair, une ligne par
                        // information, les valeurs numériques en chasse fixe.
                        _SummaryBlock(
                          rows: [
                            _SummaryRow(
                              icon: AppColors.iconForDiscipline(
                                result.discipline,
                              ),
                              iconColor: AppColors.forDiscipline(
                                result.discipline,
                              ),
                              label: 'Discipline',
                              value: result.discipline.label,
                              mono: false,
                            ),
                            _SummaryRow(
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: color,
                              label: 'Bonnes réponses',
                              value: '${result.score} / ${result.total}',
                            ),
                            _SummaryRow(
                              icon: Icons.flag_outlined,
                              iconColor: AppColors.ink,
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
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0),
                const SizedBox(height: 16),

                // 2. Retour à l'accueil.
                FilledButton.icon(
                  onPressed: () => _goHome(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text("Retour à l'accueil"),
                ).animate(delay: 120.ms).fadeIn(duration: 280.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloc gris clair arrondi qui empile les lignes du récapitulatif, séparées
/// par un trait fin.
class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.rows});

  /// Lignes à afficher, dans l'ordre.
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    // Boucle sur les lignes : on accumule chaque ligne, précédée d'un
    // séparateur à partir de la deuxième. Résultat : lignes et traits alternés.
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(rows[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

/// Ligne du récapitulatif : icône, libellé à gauche, valeur à droite (en
/// chasse fixe pour les nombres et dates, en texte gras sinon).
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.mono = true,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  /// Vrai quand la valeur est un nombre ou une date (police à chasse fixe).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: mono
                ? AppText.number(15, color: AppColors.ink)
                : const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
          ),
        ],
      ),
    );
  }
}
