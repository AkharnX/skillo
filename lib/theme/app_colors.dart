/// Palette de couleurs de l'application (voir `docs/CONVENTIONS.md`).
///
/// Aucun écran ne doit écrire une couleur en dur : tout passe par
/// [AppColors], ce qui garantit la cohérence visuelle et permet de changer
/// l'identité graphique en un seul endroit.
library;

import 'package:flutter/material.dart';

import '../models/discipline.dart';

/// Palette de couleurs de l'application.
///
/// Toutes les couleurs "métier" sont centralisées ici pour que chaque écran
/// utilise exactement les mêmes teintes. Pour changer l'identité visuelle de
/// l'application, il suffit de modifier ce fichier.
class AppColors {
  AppColors._(); // Classe utilitaire : on empêche l'instanciation.

  /// Couleur principale (violet profond) : boutons, barre de navigation…
  static const Color primary = Color(0xFF4F46E5);

  /// Violet plus clair utilisé pour les dégradés d'en-tête.
  static const Color primaryLight = Color(0xFF7C6CF6);

  /// Fond général des écrans : un gris très légèrement bleuté, plus doux
  /// qu'un blanc pur.
  static const Color background = Color(0xFFF5F6FB);

  /// Couleur des cartes et des surfaces posées sur le fond.
  static const Color surface = Colors.white;

  /// Vert : test réussi, réponse correcte.
  static const Color success = Color(0xFF16A34A);

  /// Rouge : test échoué, erreur de saisie.
  static const Color danger = Color(0xFFDC2626);

  /// Orange : avertissement, chrono qui approche de zéro.
  static const Color warning = Color(0xFFF59E0B);

  /// Texte secondaire (sous-titres, légendes).
  static const Color muted = Color(0xFF6B7280);

  /// Couleur associée à chaque discipline.
  ///
  /// Un `switch` sur l'énumération : chaque discipline a sa teinte, utilisée
  /// sur les cartes d'accueil, les badges du tableau de bord et les graphiques.
  static Color forDiscipline(Discipline d) {
    switch (d) {
      case Discipline.java:
        return const Color(0xFFEA580C); // orange "café"
      case Discipline.algo:
        return const Color(0xFF0891B2); // bleu cyan
      case Discipline.htmlCss:
        return const Color(0xFFDB2777); // rose
    }
  }

  /// Icône associée à chaque discipline (même logique que [forDiscipline]).
  static IconData iconForDiscipline(Discipline d) {
    switch (d) {
      case Discipline.java:
        return Icons.coffee_rounded;
      case Discipline.algo:
        return Icons.account_tree_rounded;
      case Discipline.htmlCss:
        return Icons.code_rounded;
    }
  }
}
