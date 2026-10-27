/// En-tête sombre « encre » affiché en haut des écrans principaux.
///
/// Historiquement un dégradé violet, d'où le nom de fichier ; le widget
/// s'appelle désormais [InkHeader] et `GradientHeader` reste un alias pour
/// les écrans existants.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Alias de compatibilité : les écrans écrits avec `GradientHeader`
/// continuent de fonctionner.
typedef GradientHeader = InkHeader;

/// Panneau d'en-tête sur fond encre, avec un titre en Space Grotesk, un sous-titre
/// optionnel, un widget à droite (avatar, bouton) et un contenu optionnel
/// sous le texte. Un halo jaune très discret dans le coin supérieur droit
/// donne de la profondeur sans dégradé criard.
class InkHeader extends StatelessWidget {
  const InkHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.child,
    this.roundedBottom = true,
    this.maxContentWidth,
  });

  /// Titre principal (ex. « Bonjour Marie »).
  final String title;

  /// Ligne secondaire sous le titre.
  final String? subtitle;

  /// Petite étiquette en capitales au-dessus du titre (ex. « ESPACE ADMIN »).
  final String? eyebrow;

  /// Widget affiché à droite du titre (ex. bouton de déconnexion).
  final Widget? trailing;

  /// Contenu optionnel sous le texte (ex. résumé des scores).
  final Widget? child;

  /// Arrondit le bas du panneau (faux quand il est collé à une barre
  /// latérale).
  final bool roundedBottom;

  /// Largeur maximale du contenu (texte, tuiles). Quand elle est donnée, le
  /// contenu est centré dans cette largeur pour s'aligner sur la colonne de
  /// l'écran (ex. 640 px côté candidat) ; sinon il occupe toute la largeur.
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: roundedBottom
          ? const BorderRadius.vertical(bottom: Radius.circular(28))
          : BorderRadius.zero,
      child: Container(
        width: double.infinity,
        color: AppColors.ink,
        child: Stack(
          children: [
            // Halo jaune discret, décoratif, dans le coin supérieur droit.
            Positioned(
              right: -120,
              top: -140,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.10),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxContentWidth ?? double.infinity,
                ),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrow != null) ...[
                              Text(
                                eyebrow!.toUpperCase(),
                                style: AppText.label(color: AppColors.accent),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              title,
                              style: AppText.display(26, color: Colors.white),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: AppColors.inkMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  if (child != null) ...[const SizedBox(height: 20), child!],
                ],
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
