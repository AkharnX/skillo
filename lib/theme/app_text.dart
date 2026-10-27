/// Styles de texte de l'application.
///
/// Trois polices, trois rôles :
/// - **Syne** (display) : titres et grands chiffres, caractère affirmé ;
/// - **Manrope** (body) : tout le texte courant, définie dans le thème ;
/// - **JetBrains Mono** (mono) : chrono, scores, numéros de question, lettres
///   des réponses. Les chiffres y ont tous la même largeur, donc rien ne saute
///   quand le chrono décompte.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Classe utilitaire (non instanciable) regroupant les styles de texte.
class AppText {
  AppText._();

  /// Nom de la police d'affichage (titres).
  static const String displayFamily = 'Syne';

  /// Nom de la police à chasse fixe (chiffres, codes).
  static const String monoFamily = 'JetBrainsMono';

  /// Titre en Syne, gras, lettres resserrées.
  ///
  /// [size] est la taille en pixels logiques ; [color] vaut l'encre par défaut.
  static TextStyle display(double size, {Color color = AppColors.ink}) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: -size * 0.02,
      color: color,
    );
  }

  /// Texte à chasse fixe (chrono, score, numéro).
  static TextStyle mono(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Petite étiquette en capitales espacées (« SECTION », « DISCIPLINE »).
  static TextStyle label({Color color = AppColors.muted}) {
    return TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: color,
    );
  }
}
