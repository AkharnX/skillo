/// Thème Material 3 de l'application : police, couleurs et formes partagées
/// par tous les écrans. Construit une seule fois dans `app.dart`.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Construit le thème Material 3 de l'application.
///
/// Le thème définit une seule fois : la police (Manrope, embarquée dans les
/// assets), les couleurs, la forme des cartes, des boutons et des champs de
/// saisie. Les écrans n'ont plus qu'à utiliser les widgets standards, ils
/// héritent automatiquement de ce style.
ThemeData buildAppTheme() {
  // Le ColorScheme est généré à partir de la couleur principale, puis on
  // force quelques couleurs pour garder exactement notre palette.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  // Forme arrondie partagée par les cartes, boutons et champs.
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.background,

    // Barre d'application plate, fondue dans le fond.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.black87,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    ),

    // Cartes blanches, sans ombre forte, bord arrondi.
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: rounded.copyWith(side: const BorderSide(color: Color(0xFFE5E7EB))),
      margin: EdgeInsets.zero,
    ),

    // Champs de saisie : fond blanc, bord fin, arrondi.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Boutons principaux : pleins, hauts, arrondis.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Barre de navigation (admin) : indicateur violet clair.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
