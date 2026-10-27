import 'package:flutter/material.dart';

import '../models/discipline.dart';
import '../theme/app_colors.dart';

/// Pastille ronde colorée avec l'icône d'une discipline.
///
/// Utilisée partout où une discipline est affichée (accueil candidat, profil,
/// tableau de bord admin) pour qu'elle soit reconnaissable d'un coup d'œil.
class DisciplineAvatar extends StatelessWidget {
  const DisciplineAvatar({super.key, required this.discipline, this.size = 48});

  final Discipline discipline;

  /// Diamètre de la pastille en pixels logiques.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDiscipline(discipline);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(
        AppColors.iconForDiscipline(discipline),
        color: color,
        size: size * 0.5,
      ),
    );
  }
}
