/// Coque de l'espace admin (US4) : navigation entre les trois écrans
/// (résultats, questions, statistiques), en-tête encre et bouton de
/// déconnexion.
///
/// Identité « encre et signal » : sur un écran large (web de bureau) une barre
/// latérale encre occupe toute la hauteur, avec le logo en haut, le rail de
/// navigation (indicateur jaune) et la déconnexion tout en bas. Sur téléphone
/// l'en-tête encre porte le bouton de déconnexion et la navigation devient
/// une barre encre en bas d'écran. Les trois écrans restent montés dans un
/// `IndexedStack` pour que leurs filtres ne soient pas perdus au changement
/// d'onglet.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'questions_screen.dart';
import 'stats_screen.dart';

/// Écran racine de l'administrateur connecté.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  /// Index de l'onglet affiché : 0 = résultats, 1 = questions, 2 = stats.
  int _index = 0;

  /// Largeur à partir de laquelle on passe à la barre latérale.
  static const double _wideBreakpoint = 900;

  /// Largeur de la barre latérale encre sur grand écran.
  static const double _railWidth = 96;

  /// Titres affichés dans l'en-tête, dans l'ordre des onglets.
  static const _titles = ['Résultats', 'Questions', 'Statistiques'];

  /// Sous-titres de l'en-tête, dans l'ordre des onglets.
  static const _subtitles = [
    'Derniers tests passés par les candidats',
    'Banque de questions par discipline',
    'Taux de réussite par discipline et global',
  ];

  /// Change l'onglet affiché.
  void _select(int i) => setState(() => _index = i);

  /// Bouton de déconnexion, blanc car toujours posé sur l'encre.
  Widget _logoutButton(BuildContext context) {
    return IconButton(
      tooltip: 'Se déconnecter',
      icon: const Icon(Icons.logout, color: Colors.white),
      onPressed: context.read<AuthState>().logout,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. On décide de la disposition selon la largeur disponible.
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    // 2. Les trois écrans, tous montés, un seul visible.
    final body = IndexedStack(
      index: _index,
      children: const [DashboardScreen(), QuestionsScreen(), StatsScreen()],
    );

    // 3. Écran large : barre latérale encre + en-tête sans arrondi (il est
    //    collé à la barre) + écran courant.
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              width: _railWidth,
              selectedIndex: _index,
              onSelected: _select,
              logout: _logoutButton(context),
            ),
            Expanded(
              child: Column(
                children: [
                  InkHeader(
                    roundedBottom: false,
                    eyebrow: 'Espace admin',
                    title: _titles[_index],
                    subtitle: _subtitles[_index],
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4. Téléphone / fenêtre étroite : en-tête encre avec la déconnexion à
    //    droite, barre de navigation en bas (stylée par le thème).
    return Scaffold(
      body: Column(
        children: [
          InkHeader(
            eyebrow: 'Espace admin',
            title: _titles[_index],
            subtitle: _subtitles[_index],
            trailing: _logoutButton(context),
          ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Résultats',
          ),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Questions'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Stats'),
        ],
      ),
    );
  }
}

/// Barre latérale encre pleine hauteur : logo en haut, rail de navigation
/// (le thème le colore encre avec un indicateur jaune), déconnexion en bas.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.selectedIndex,
    required this.onSelected,
    required this.logout,
  });

  final double width;

  /// Onglet courant, mis en évidence par l'indicateur jaune.
  final int selectedIndex;

  /// Appelé avec l'index de la destination touchée.
  final ValueChanged<int> onSelected;

  /// Bouton de déconnexion, posé tout en bas.
  final Widget logout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.ink,
      child: Column(
        children: [
          // Logo en haut de la barre.
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 22, 0, 10),
            child: AppLogoMark(size: 40),
          ),
          // Le rail prend la hauteur restante ; ses destinations sont
          // alignées en haut.
          Expanded(
            child: NavigationRail(
              minWidth: width,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -1,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Résultats'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.quiz),
                  label: Text('Questions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.pie_chart),
                  label: Text('Stats'),
                ),
              ],
            ),
          ),
          // Déconnexion, séparée par un trait discret.
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: logout,
          ),
        ],
      ),
    );
  }
}
