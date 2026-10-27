/// Carré avec la lettre d'une réponse (A, B, C…), comme sur une feuille de
/// QCM. Utilisé devant chaque choix du test et dans l'éditeur de questions.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Lettre d'une réponse dans un carré. Sélectionné : fond encre, lettre
/// jaune. Sinon : fond pâle, lettre encre.
class ChoiceLetter extends StatelessWidget {
  const ChoiceLetter({
    super.key,
    required this.index,
    this.selected = false,
    this.size = 34,
  });

  /// Position du choix (0 → « A », 1 → « B », …).
  final int index;

  /// Vrai quand le choix est coché.
  final bool selected;

  final double size;

  /// Lettre correspondant à [index] : on part du code de « A ».
  String get letter => String.fromCharCode('A'.codeUnitAt(0) + index);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        letter,
        style: AppText.mono(
          size * 0.42,
          color: selected ? AppColors.accent : AppColors.ink,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
