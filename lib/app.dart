import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'data/question_repository.dart';
import 'data/result_repository.dart';
import 'data/user_repository.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/candidate/candidate_home_screen.dart';
import 'state/auth_state.dart';
import 'theme/app_theme.dart';

/// Racine de l'application : fournit la base, les repositories et l'état
/// d'authentification à tous les écrans.
class ReineApp extends StatelessWidget {
  const ReineApp({super.key, required this.db});

  final Database db;

  @override
  Widget build(BuildContext context) {
    final users = UserRepository(db);
    return MultiProvider(
      providers: [
        Provider<Database>.value(value: db),
        Provider<UserRepository>.value(value: users),
        Provider<QuestionRepository>(create: (_) => QuestionRepository(db)),
        Provider<ResultRepository>(create: (_) => ResultRepository(db)),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState(users)),
      ],
      child: MaterialApp(
        title: 'Reine',
        debugShowCheckedModeBanner: false,
        // Thème unique défini dans lib/theme/app_theme.dart.
        theme: buildAppTheme(),
        home: const HomeRouter(),
      ),
    );
  }
}

/// Choisit l'écran selon l'utilisateur connecté.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const LoginScreen();
    return user.isAdmin ? const AdminShell() : const CandidateHomeScreen();
  }
}
