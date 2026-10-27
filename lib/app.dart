/// Racine de l'application : providers (base, repositories, authentification),
/// thème global et routeur d'accueil qui choisit l'écran selon le rôle.
library;

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

/// Widget racine : fournit la base, les repositories et l'état
/// d'authentification à tous les écrans, puis construit le [MaterialApp].
///
/// Les repositories sont créés une seule fois ici et récupérés dans les
/// écrans avec `context.read<...>()`. Ainsi aucun écran n'ouvre lui-même la
/// base : il demande simplement le repository dont il a besoin.
class SkilloApp extends StatelessWidget {
  const SkilloApp({super.key, required this.db});

  /// Base SQLite déjà ouverte par `main()`.
  final Database db;

  @override
  Widget build(BuildContext context) {
    // 1. Le repository des utilisateurs est créé à part : il sert à la fois
    //    aux écrans (via Provider) et à l'AuthState (connexion/inscription).
    final users = UserRepository(db);

    // 2. On empile les providers puis on construit l'application Material.
    return MultiProvider(
      providers: [
        Provider<Database>.value(value: db),
        Provider<UserRepository>.value(value: users),
        Provider<QuestionRepository>(create: (_) => QuestionRepository(db)),
        Provider<ResultRepository>(create: (_) => ResultRepository(db)),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState(users)),
      ],
      child: MaterialApp(
        title: 'Skillo',
        debugShowCheckedModeBanner: false,
        // Thème unique défini dans lib/theme/app_theme.dart : police Manrope,
        // palette AppColors, formes arrondies des cartes et boutons.
        theme: buildAppTheme(),
        home: const HomeRouter(),
      ),
    );
  }
}

/// Choisit l'écran d'accueil selon l'utilisateur connecté.
///
/// - personne de connecté : écran de connexion ;
/// - administrateur : coquille admin (tableau de bord, questions, stats) ;
/// - candidat : accueil candidat (les trois tests).
///
/// Le widget écoute [AuthState] : dès qu'un utilisateur se connecte ou se
/// déconnecte, il se reconstruit et change d'écran sans navigation manuelle.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` : on se reconstruit à chaque changement d'utilisateur.
    final user = context.watch<AuthState>().user;

    // 1. Pas d'utilisateur : on affiche la connexion.
    if (user == null) return const LoginScreen();

    // 2. Utilisateur connecté : écran selon le rôle.
    return user.isAdmin ? const AdminShell() : const CandidateHomeScreen();
  }
}
