/// Motivation du candidat, choisie dans une liste déroulante (US1, US3).
enum Motivation {
  poursuiteEtudes("Poursuite d'études"),
  reorientation('Réorientation'),
  reconversion('Reconversion');

  const Motivation(this.label);

  /// Libellé affiché et stocké en base.
  final String label;

  static Motivation? fromLabel(String label) {
    for (final m in values) {
      if (m.label == label) return m;
    }
    return null;
  }
}
