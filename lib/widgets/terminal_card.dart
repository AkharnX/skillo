/// Bloc décoratif façon terminal : trois points en haut, puis des lignes en
/// chasse fixe. Sert d'illustration sur l'écran de connexion (les trois
/// disciplines listées comme des commandes) : un détail qui parle du sujet,
/// le code, sans image externe.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Une ligne du terminal : un texte et une couleur.
class TerminalLine {
  const TerminalLine(this.text, {this.color = Colors.white});

  final String text;
  final Color color;
}

/// Carte sombre imitant une fenêtre de terminal.
class TerminalCard extends StatelessWidget {
  const TerminalCard({super.key, required this.lines, this.title = 'skillo'});

  /// Lignes affichées dans l'ordre.
  final List<TerminalLine> lines;

  /// Nom affiché dans la barre de titre.
  final String title;

  @override
  Widget build(BuildContext context) {
    // Construit un widget Text par ligne, dans l'ordre : on parcourt `lines`
    // et on accumule les widgets dans `rows`.
    final rows = <Widget>[];
    for (final line in lines) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            line.text,
            style: AppText.mono(
              13.5,
              color: line.color,
              weight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de titre : trois pastilles et le nom.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                _dot(AppColors.danger),
                _dot(AppColors.warning),
                _dot(AppColors.success),
                const SizedBox(width: 10),
                Text(title, style: AppText.mono(12, color: AppColors.inkMuted)),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }

  /// Une petite pastille ronde de la barre de titre.
  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
