/// Widget partagé : titre de section avec sous-titre optionnel.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Titre de section (ex. "Mes tests", "Résultats récents") avec un sous-titre
/// optionnel, pour structurer les écrans qui empilent plusieurs blocs.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle});

  /// Texte du titre, en gras.
  final String title;

  /// Ligne grise optionnelle sous le titre.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.display(19)),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}
