/// Motivation du candidat, choisie dans une liste déroulante (US1, US3).
library;

/// Motivation du candidat, choisie dans une liste déroulante (US1, US3).
///
/// Le [label] sert à la fois à l'affichage et au stockage en base : c'est
/// une valeur imposée par le cahier des charges, donc stable.
enum Motivation {
  poursuiteEtudes("Poursuite d'études"),
  reorientation('Réorientation'),
  reconversion('Reconversion');

  const Motivation(this.label);

  /// Libellé affiché et stocké en base.
  final String label;

  /// Retrouve la motivation à partir de son libellé, ou null s'il est inconnu
  /// (par exemple la chaîne vide stockée pour le compte admin).
  static Motivation? fromLabel(String label) {
    // Boucle sur les valeurs de l'énumération ; dès que le libellé
    // correspond, on renvoie la motivation. Sinon null.
    for (final motivation in values) {
      if (motivation.label == label) return motivation;
    }
    return null;
  }
}
