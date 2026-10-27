/// Coque de l'espace admin (US4) : en-tête coloré, navigation entre les trois
/// écrans (résultats, questions, statistiques) et bouton de déconnexion.
///
/// Sur téléphone la navigation est une barre en bas d'écran ; sur un écran
/// large (web de bureau) elle devient un rail vertical à gauche. Les trois
/// écrans sont gardés en mémoire dans un `IndexedStack` pour que leurs filtres
/// ne soient pas perdus quand on change d'onglet.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
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

  /// Largeur à partir de laquelle on passe au rail de navigation latéral.
  static const double _wideBreakpoint = 900;

  /// Titres affichés dans l'en-tête, dans l'ordre des onglets.
  static const _titles = ['Tableau de bord', 'Questions', 'Statistiques'];

  /// Sous-titres de l'en-tête, dans l'ordre des onglets.
  static const _subtitles = [
    'Espace admin · derniers résultats des candidats',
    'Espace admin · banque de questions par discipline',
    'Espace admin · taux de réussite par discipline',
  ];

  /// Change l'onglet affiché.
  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // 1. On décide de la disposition selon la largeur disponible.
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    // 2. En-tête commun : titre de l'onglet + bouton de déconnexion.
    final header = GradientHeader(
      title: _titles[_index],
      subtitle: _subtitles[_index],
      trailing: IconButton(
        tooltip: 'Se déconnecter',
        icon: const Icon(Icons.logout, color: Colors.white),
        onPressed: context.read<AuthState>().logout,
      ),
    );

    // 3. Contenu : l'en-tête puis l'écran courant (les autres restent montés).
    final content = Column(
      children: [
        header,
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [
              DashboardScreen(),
              QuestionsScreen(),
              StatsScreen(),
            ],
          ),
        ),
      ],
    );

    // 4. Écran large : rail vertical à gauche, pas de barre en bas.
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
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
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    // 5. Téléphone / fenêtre étroite : barre de navigation en bas.
    return Scaffold(
      body: content,
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
