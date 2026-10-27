/// Widget partagé : badge coloré « Réussi » / « Échoué ».
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Petit badge "Réussi" / "Échoué" (ou tout autre texte court) avec une
/// couleur de fond pâle et un texte de la même teinte.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  /// Badge vert "Réussi" ou rouge "Échoué" selon [passed].
  factory StatusChip.passFail(bool passed) {
    return StatusChip(
      label: passed ? 'Réussi' : 'Échoué',
      color: passed ? AppColors.success : AppColors.danger,
    );
  }

  /// Texte court affiché dans le badge.
  final String label;

  /// Teinte du badge : pleine pour le texte, à 12 % pour le fond.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
