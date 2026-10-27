/// Logo de l'application : un carré jaune avec un « S » en Space Grotesk, suivi du
/// nom « Skillo ». Utilisé sur les écrans de connexion et d'inscription.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Logo + nom de l'application, horizontalement.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.size = 40,
    this.onDark = false,
    this.showName = true,
  });

  /// Côté du carré du logo, en pixels logiques.
  final double size;

  /// Vrai quand le logo est posé sur un fond encre : le nom passe en blanc.
  final bool onDark;

  /// Affiche ou non le nom à côté du carré.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogoMark(size: size),
        if (showName) ...[
          SizedBox(width: size * 0.3),
          Text(
            'Skillo',
            style: AppText.display(
              size * 0.7,
              color: onDark ? Colors.white : AppColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

/// Le carré jaune seul, avec le « S ».
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        'S',
        style: AppText.display(size * 0.62, color: AppColors.ink),
      ),
    );
  }
}
