/// Les trois disciplines évaluées (US2).
enum Discipline {
  java('java', 'Java'),
  algo('algo', 'Algorithmes'),
  htmlCss('html_css', 'HTML/CSS');

  const Discipline(this.code, this.label);

  /// Code stocké en base et dans les JSON.
  final String code;

  /// Libellé affiché à l'écran.
  final String label;

  static Discipline fromCode(String code) => values.firstWhere(
        (d) => d.code == code,
        orElse: () => throw ArgumentError('Discipline inconnue : $code'),
      );
}
