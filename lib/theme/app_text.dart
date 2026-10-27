/// Styles de texte de l'application.
///
/// Trois polices, trois rôles bien séparés :
/// - **Space Grotesk** (display) : titres. Grotesque légèrement technique,
///   lisible même en gras ;
/// - **Manrope** (body) : tout le texte courant, définie dans le thème, et
///   les chiffres clés (scores, tuiles, taux) en très gras ;
/// - **JetBrains Mono** (mono) : uniquement le chrono, le faux terminal, le
///   JSON et les petits index (« 01 », lettres A/B/C). Ses chiffres ont tous
///   la même largeur, donc rien ne saute quand le chrono décompte.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Classe utilitaire (non instanciable) regroupant les styles de texte.
class AppText {
  AppText._();

  /// Nom de la police d'affichage (titres).
  static const String displayFamily = 'SpaceGrotesk';

  /// Nom de la police à chasse fixe (chrono, codes).
  static const String monoFamily = 'JetBrainsMono';

  /// Titre en Space Grotesk, gras, lettres légèrement resserrées.
  ///
  /// [size] est la taille en pixels logiques ; [color] vaut l'encre par défaut.
  static TextStyle display(double size, {Color color = AppColors.ink}) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -size * 0.015,
      color: color,
    );
  }

  /// Chiffre clé (score « 3 / 4 », tuile « 12 », taux « 75 % ») : Manrope
  /// très gras, dont les chiffres sont simples et nets, avec des chiffres de
  /// largeur fixe pour que les colonnes de nombres restent alignées.
  static TextStyle number(double size, {Color color = AppColors.ink}) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -size * 0.01,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Texte à chasse fixe (chrono, terminal, JSON, index).
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
      letterSpacing: 1.1,
      color: color,
    );
  }
}
