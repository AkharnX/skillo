import 'package:flutter_test/flutter_test.dart';
import 'package:reine/app.dart';
import 'package:reine/data/app_database.dart';
import 'package:reine/models/motivation.dart';
import 'package:reine/screens/admin/admin_shell.dart';
import 'package:reine/screens/auth/login_screen.dart';
import 'package:reine/screens/candidate/candidate_home_screen.dart';

import 'test_app.dart';

void main() {
  late TestApp app;
  setUp(() async => app = await TestApp.create());
  tearDown(() => app.close());

  testWidgets('shows login, then the screen matching the role', (tester) async {
    await tester.pumpWidget(app.wrap(const HomeRouter()));
    expect(find.byType(LoginScreen), findsOneWidget);

    await app.auth.login(kAdminEmail, kAdminPassword);
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);

    app.auth.logout();
    await app.auth.register(
      lastName: 'D', firstName: 'J', email: 'j@d.fr', password: 'x',
      age: 20, address: 'a', motivation: Motivation.reconversion,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CandidateHomeScreen), findsOneWidget);
  });
}
