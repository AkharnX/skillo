import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// En-tête coloré en dégradé, affiché en haut des écrans principaux.
///
/// Il porte un titre, un sous-titre optionnel et éventuellement un widget
/// à droite (avatar, bouton). Le bas est arrondi pour "poser" le contenu
/// qui suit sur le fond gris de l'écran.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
  });

  /// Titre principal (ex. "Bonjour Marie").
  final String title;

  /// Ligne secondaire sous le titre (ex. "Choisis un test à passer").
  final String? subtitle;

  /// Widget affiché à droite du titre (ex. bouton de déconnexion).
  final Widget? trailing;

  /// Contenu optionnel sous le texte (ex. résumé des scores).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (child != null) ...[const SizedBox(height: 20), child!],
        ],
      ),
    );
  }
}
