import 'package:flutter_test/flutter_test.dart';
import 'package:reine/logic/school_year.dart';

void main() {
  test('a date in October belongs to the school year starting that year', () {
    expect(schoolYearFor(DateTime(2026, 10, 26)), '2026-2027');
  });

  test(
    'a date in March belongs to the school year started the year before',
    () {
      expect(schoolYearFor(DateTime(2026, 3, 1)), '2025-2026');
    },
  );

  test('September 1st starts a new school year', () {
    expect(schoolYearFor(DateTime(2026, 9, 1)), '2026-2027');
  });
}
