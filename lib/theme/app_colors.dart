/// Palette de couleurs de l'application Skillo.
///
/// Identité visuelle : « encre et signal ». Les surfaces importantes (en-têtes,
/// barre latérale admin, bouton principal) sont d'un bleu nuit profond, l'encre.
/// Une seule couleur vive, le jaune signal, sert d'accent : chrono, indicateur
/// de navigation, pastilles. Le reste est calme : fond gris-bleu très clair,
/// cartes blanches. Les trois disciplines gardent chacune leur teinte.
///
/// Toutes les couleurs « métier » sont centralisées ici : aucun écran ne doit
/// écrire une couleur en dur.
library;

import 'package:flutter/material.dart';

import '../models/discipline.dart';

/// Classe utilitaire (non instanciable) regroupant les couleurs de l'app.
class AppColors {
  AppColors._();

  /// Encre : bleu nuit presque noir. Panneaux sombres, bouton principal,
  /// titres.
  static const Color ink = Color(0xFF14192B);

  /// Encre « relevée » : surface sombre posée sur [ink] (carte dans un panneau
  /// sombre, élément survolé de la barre latérale).
  static const Color inkRaised = Color(0xFF222842);

  /// Texte secondaire sur fond sombre.
  static const Color inkMuted = Color(0xFF9AA3C0);

  /// Accent signal : jaune vif. Utilisé avec parcimonie, surtout sur l'encre
  /// (chrono, indicateur de navigation, badge). Sur fond clair, le texte posé
  /// dessus est toujours [ink].
  static const Color accent = Color(0xFFFFD60A);

  /// Accent atténué pour les fonds pâles (pastilles sur surface claire).
  static const Color accentSoft = Color(0xFFFFF4B8);

  /// Fond général des écrans : gris très légèrement bleuté.
  static const Color background = Color(0xFFF1F2F7);

  /// Surface des cartes.
  static const Color surface = Colors.white;

  /// Bordure fine des cartes et des champs.
  static const Color border = Color(0xFFE1E4EE);

  /// Texte principal sur fond clair.
  static const Color text = Color(0xFF1B1F31);

  /// Texte secondaire sur fond clair (légendes, sous-titres).
  static const Color muted = Color(0xFF667085);

  /// Vert : test réussi, bonne réponse.
  static const Color success = Color(0xFF15803D);

  /// Rouge : test échoué, erreur de saisie.
  static const Color danger = Color(0xFFD92D20);

  /// Orange : avertissement, chrono qui approche de zéro.
  static const Color warning = Color(0xFFE07B00);

  /// Alias conservé pour compatibilité : la couleur « principale » est l'encre.
  static const Color primary = ink;

  /// Alias conservé pour compatibilité.
  static const Color primaryLight = inkRaised;

  /// Couleur associée à chaque discipline.
  ///
  /// Un `switch` sur l'énumération : chaque discipline a sa teinte, utilisée
  /// sur les cartes d'accueil, les badges du tableau de bord et les graphiques.
  static Color forDiscipline(Discipline d) {
    switch (d) {
      case Discipline.java:
        return const Color(0xFFE8590C); // orange « café »
      case Discipline.algo:
        return const Color(0xFF0E9F8E); // vert-bleu « organigramme »
      case Discipline.htmlCss:
        return const Color(0xFFD6336C); // rose « balise »
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
