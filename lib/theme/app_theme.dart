/// Thème Material 3 de l'application.
///
/// Le thème définit une seule fois : la police de texte courant (Manrope,
/// embarquée dans les assets), les couleurs, la forme des cartes, des boutons
/// et des champs de saisie. Les écrans utilisent les widgets standards et
/// héritent automatiquement de ce style. Les titres passent par [AppText].
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Construit le [ThemeData] unique de l'application.
ThemeData buildAppTheme() {
  // 1. Schéma de couleurs : la couleur « principale » est l'encre, l'accent
  //    jaune est la couleur secondaire. On force les surfaces et l'erreur pour
  //    rester exactement dans notre palette.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.ink,
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
  );

  // 2. Formes partagées : cartes très arrondies, boutons et champs un peu moins.
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: const BorderSide(color: AppColors.border),
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  // 3. Style de texte des boutons (police précisée explicitement : un
  //    `textStyle` remplace le style par défaut, il ne le fusionne pas).
  const buttonText = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 15.5,
    fontWeight: FontWeight.w700,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,

    // Barre d'application plate, fondue dans le fond, titre en Space Grotesk.
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.display(19),
    ),

    // Cartes blanches, bord fin, sans ombre.
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),

    // Champs : fond blanc, bord fin, bord encre à la prise de focus.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Bouton principal : encre, texte blanc, haut et arrondi.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.ink, width: 1.4),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: buttonText,
      ),
    ),

    // Barre de navigation basse (admin sur mobile) : encre + accent.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.ink,
      indicatorColor: AppColors.accent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.ink : AppColors.inkMuted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.inkMuted,
        );
      }),
    ),

    // Barre latérale (admin sur grand écran) : mêmes couleurs.
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.ink,
      indicatorColor: AppColors.accent,
      selectedIconTheme: const IconThemeData(color: AppColors.ink),
      unselectedIconTheme: const IconThemeData(color: AppColors.inkMuted),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.inkMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: controlShape,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.border,
    ),
  );
}
