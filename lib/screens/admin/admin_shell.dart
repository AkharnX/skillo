import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import 'dashboard_screen.dart';
import 'questions_screen.dart';
import 'stats_screen.dart';

/// Coque admin (US4) : barre de navigation vers les trois écrans.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _titles = ['Tableau de bord', 'Questions', 'Statistiques'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${_titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: context.read<AuthState>().logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [DashboardScreen(), QuestionsScreen(), StatsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Résultats',
          ),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Questions'),
          NavigationDestination(
            icon: Icon(Icons.pie_chart),
            label: 'Statistiques',
          ),
        ],
      ),
    );
  }
}
