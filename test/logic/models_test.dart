import 'package:flutter_test/flutter_test.dart';
import 'package:reine/models/discipline.dart';
import 'package:reine/models/motivation.dart';
import 'package:reine/models/user.dart';

void main() {
  test('Discipline codes and labels match the backlog', () {
    expect(Discipline.java.code, 'java');
    expect(Discipline.algo.code, 'algo');
    expect(Discipline.htmlCss.code, 'html_css');
    expect(Discipline.java.label, 'Java');
    expect(Discipline.algo.label, 'Algorithmes');
    expect(Discipline.htmlCss.label, 'HTML/CSS');
    expect(Discipline.fromCode('html_css'), Discipline.htmlCss);
    expect(() => Discipline.fromCode('php'), throwsArgumentError);
  });

  test('Motivation labels match the backlog', () {
    expect(Motivation.poursuiteEtudes.label, "Poursuite d'études");
    expect(Motivation.reorientation.label, 'Réorientation');
    expect(Motivation.reconversion.label, 'Reconversion');
    expect(Motivation.fromLabel('Reconversion'), Motivation.reconversion);
    expect(Motivation.fromLabel(''), isNull);
  });

  test('AppUser.isAdmin depends on role', () {
    final u = AppUser(
      id: 1, role: 'admin', lastName: 'A', firstName: 'B', email: 'a@b.c',
      age: 0, address: '', motivation: null,
    );
    expect(u.isAdmin, isTrue);
    expect(u.fullName, 'B A');
  });
}
