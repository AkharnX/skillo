/// Tuile de statistique : une étiquette en capitales, un grand chiffre en
/// chasse fixe et une icône. Utilisée sur le tableau de bord admin et dans
/// les en-têtes (tests passés, réussite…).
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Tuile « étiquette + grand chiffre ».
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.ink,
    this.onDark = false,
  });

  /// Texte de l'étiquette (ex. « Candidats »).
  final String label;

  /// Valeur affichée en grand (ex. « 12 », « 75 % »).
  final String value;

  /// Icône optionnelle en haut de la tuile.
  final IconData? icon;

  /// Couleur de l'icône.
  final Color color;

  /// Vrai quand la tuile est posée sur un fond encre.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final valueColor = onDark ? Colors.white : AppColors.ink;
    final labelColor = onDark ? AppColors.inkMuted : AppColors.muted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onDark ? AppColors.inkRaised : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: onDark ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: onDark ? AppColors.accent : color),
            const SizedBox(height: 10),
          ],
          Text(value, style: AppText.mono(26, color: valueColor)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppText.label(color: labelColor)),
        ],
      ),
    );
  }
}
