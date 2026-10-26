/// Année scolaire d'une date : de septembre à août.
/// Ex. : 26/10/2026 -> "2026-2027", 01/03/2026 -> "2025-2026".
String schoolYearFor(DateTime date) {
  final start = date.month >= 9 ? date.year : date.year - 1;
  return '$start-${start + 1}';
}
