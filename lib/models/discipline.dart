/// Les trois disciplines évaluées par la plateforme (US2).
library;

/// Les trois disciplines évaluées (US2).
///
/// Chaque valeur porte un [code] technique (stocké en base et dans les JSON,
/// jamais affiché) et un [label] lisible pour l'écran. Séparer les deux
/// permet de renommer un libellé sans toucher aux données existantes.
enum Discipline {
  java('java', 'Java'),
  algo('algo', 'Algorithmes'),
  htmlCss('html_css', 'HTML/CSS');

  const Discipline(this.code, this.label);

  /// Code stocké en base et dans les JSON.
  final String code;

  /// Libellé affiché à l'écran.
  final String label;

  /// Retrouve la discipline à partir de son code. Lève une [ArgumentError]
  /// si le code est inconnu (fichier JSON d'une autre application, faute de
  /// frappe…) : l'appelant transforme cette erreur en message pour l'admin.
  static Discipline fromCode(String code) {
    // Boucle sur les valeurs de l'énumération ; dès que le code correspond,
    // on renvoie la discipline. Si on sort de la boucle, aucune ne correspond.
    for (final discipline in values) {
      if (discipline.code == code) return discipline;
    }
    throw ArgumentError('Discipline inconnue : $code');
  }
}
