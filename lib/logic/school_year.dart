/// Calcul de l'année scolaire d'une date.
///
/// Les résultats sont rangés par année scolaire (US6, US7) : l'admin filtre
/// le tableau de bord et les statistiques par « 2025-2026 », « 2026-2027 »…
library;

/// Année scolaire contenant [date], au format « AAAA-AAAA+1 ».
///
/// Une année scolaire va du 1er septembre au 31 août :
///  - du 1er septembre au 31 décembre, elle **commence** l'année de la date
///    (26/10/2026 -> « 2026-2027 ») ;
///  - de janvier à août, elle a commencé l'année **précédente**
///    (01/03/2026 -> « 2025-2026 »).
/// Le 1er septembre appartient donc déjà à la nouvelle année scolaire.
String schoolYearFor(DateTime date) {
  // 1. Année de début : l'année de la date si on est en septembre ou après,
  //    sinon l'année d'avant.
  final start = date.month >= 9 ? date.year : date.year - 1;
  // 2. Texte « début-fin ».
  return '$start-${start + 1}';
}
