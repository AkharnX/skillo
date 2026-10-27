/// Widget partagé : message « rien à afficher » pour les listes vides.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Message affiché quand une liste est vide (aucun résultat, aucune question…).
///
/// Une grande icône grise, un titre et une phrase d'explication : l'utilisateur
/// comprend tout de suite qu'il n'y a pas d'erreur, juste rien à afficher.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  /// Grande icône grise au-dessus du titre.
  final IconData icon;

  /// Titre court (ex. « Aucun résultat »).
  final String title;

  /// Phrase d'explication optionnelle sous le titre.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            // Le message et son espacement ne sont ajoutés que s'il existe.
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
