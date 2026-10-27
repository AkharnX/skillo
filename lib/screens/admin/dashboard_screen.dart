/// Tableau de bord admin (US6) : derniers résultats des candidats, avec une
/// recherche par nom ou prénom et un filtre par année scolaire.
///
/// L'écran affiche en haut une carte de filtres, puis trois tuiles de chiffres
/// clés (candidats, tests passés, taux de réussite) calculées sur les
/// résultats affichés, puis la liste des résultats : une carte par résultat
/// avec la pastille de la discipline, le nom du candidat, la date, le score
/// en chasse fixe et le badge Réussi / Échoué.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../models/test_result.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';

/// Écran « Résultats » de l'espace admin.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Texte saisi dans le champ de recherche (nom ou prénom).
  final _search = TextEditingController();

  /// Année scolaire filtrée ; `null` = toutes les années.
  String? _year;

  /// Résultats à afficher (rechargés à chaque changement de filtre).
  late Future<List<TestResult>> _results;

  /// Années scolaires disponibles dans la liste déroulante.
  late Future<List<String>> _years;

  /// Format d'affichage de la date de passage, ex. « 05/10/2026 à 14:30 ».
  static final _dateFormat = DateFormat("dd/MM/yyyy 'à' HH:mm");

  @override
  void initState() {
    super.initState();
    _years = context.read<ResultRepository>().schoolYears();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Relance la requête des résultats avec les filtres courants.
  void _reload() {
    _results = context.read<ResultRepository>().recent(
      search: _search.text,
      schoolYear: _year,
    );
  }

  /// Appelé quand l'utilisateur choisit une année dans la liste.
  void _onYearChanged(String? year) {
    setState(() {
      _year = year;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // 1. Carte des filtres (recherche + année).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildFilters(),
              ),
              // 2. Chiffres clés + liste des résultats.
              Expanded(
                child: FutureBuilder<List<TestResult>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildResults(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Carte contenant le champ de recherche et la liste des années.
  ///
  /// Sur un écran étroit (téléphone) les deux champs sont empilés ; sur un
  /// écran large ils sont côte à côte.
  Widget _buildFilters() {
    final searchField = TextField(
      key: const Key('dashboard-search'),
      controller: _search,
      decoration: const InputDecoration(
        labelText: 'Rechercher un candidat',
        hintText: 'Nom ou prénom',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (_) => setState(_reload),
    );

    // La liste des années se remplit quand la requête est terminée.
    final yearField = FutureBuilder<List<String>>(
      future: _years,
      builder: (context, snapshot) {
        // Entrées du menu : d'abord « Toutes les années », puis chaque année.
        final items = <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Toutes les années'),
          ),
        ];
        // On parcourt les années trouvées en base pour les ajouter au menu.
        for (final y in snapshot.data ?? const <String>[]) {
          items.add(DropdownMenuItem<String?>(value: y, child: Text(y)));
        }
        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Année scolaire',
            prefixIcon: Icon(Icons.calendar_today_outlined),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButton<String?>(
            key: const Key('dashboard-year'),
            value: _year,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: _onYearChanged,
          ),
        );
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Écran étroit : on empile les deux champs.
            if (constraints.maxWidth < 560) {
              return Column(
                children: [searchField, const SizedBox(height: 10), yearField],
              );
            }
            // Écran large : recherche à gauche, année à droite.
            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: yearField),
              ],
            );
          },
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }

  /// Liste des résultats précédée des tuiles de chiffres clés.
  Widget _buildResults(List<TestResult> results) {
    // Aucun résultat : message d'état vide, pas de tuiles.
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Aucun résultat',
        message:
            'Aucun test ne correspond à la recherche ou à l\'année choisie.',
      );
    }

    // Les deux premiers éléments de la liste sont les tuiles et le titre ;
    // les suivants sont les cartes de résultat.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return _KeyFigures(results: results);
        if (i == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 10),
            child: SectionTitle(
              title: 'Résultats récents',
              subtitle:
                  '${results.length} test(s), du plus récent au plus ancien',
            ),
          );
        }
        final index = i - 2;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ResultCard(result: results[index], dateFormat: _dateFormat),
        ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
      },
    );
  }
}

/// Rangée de trois tuiles : candidats distincts, tests passés, taux de
/// réussite. Les chiffres portent sur les résultats actuellement affichés
/// (donc filtrés par la recherche et l'année).
class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.results});

  final List<TestResult> results;

  @override
  Widget build(BuildContext context) {
    // 1. On parcourt les résultats pour compter les candidats distincts
    //    (par identifiant utilisateur) et le nombre de tests réussis.
    final candidateIds = <int>{};
    var passedCount = 0;
    for (final r in results) {
      candidateIds.add(r.userId);
      if (r.passed) passedCount++;
    }

    // 2. Taux de réussite en pourcentage entier (0 si aucun test).
    final rate = results.isEmpty
        ? 0
        : (passedCount * 100 / results.length).round();

    // 3. Les trois tuiles.
    final candidates = StatTile(
      icon: Icons.people_alt_outlined,
      label: 'Candidats',
      value: '${candidateIds.length}',
    );
    final tests = StatTile(
      icon: Icons.assignment_turned_in_outlined,
      label: 'Tests passés',
      value: '${results.length}',
    );
    final success = StatTile(
      icon: Icons.trending_up_rounded,
      color: AppColors.success,
      label: 'Réussite',
      value: '$rate %',
    );

    // 4. Trois colonnes quand la place le permet ; sur téléphone, deux tuiles
    //    côte à côte puis la troisième en pleine largeur, pour que les grands
    //    chiffres ne soient jamais coupés.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: candidates),
                  const SizedBox(width: 10),
                  Expanded(child: tests),
                ],
              ),
              const SizedBox(height: 10),
              success,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: candidates),
            const SizedBox(width: 10),
            Expanded(child: tests),
            const SizedBox(width: 10),
            Expanded(child: success),
          ],
        );
      },
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }
}

/// Carte d'un résultat : pastille de la discipline, nom du candidat, ligne
/// « discipline · date · année », score en chasse fixe et badge Réussi /
/// Échoué. Un seul [ListTile] par résultat (les tests les comptent).
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.dateFormat});

  final TestResult result;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: DisciplineAvatar(discipline: r.discipline, size: 44),
        title: Text(
          r.candidateName ?? '?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${r.discipline.label} · ${dateFormat.format(r.takenAt)} · '
            '${r.schoolYear}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        // Le ListTile limite la hauteur du `trailing` à 56 px : le score
        // (une ligne en chasse fixe) puis le badge tiennent juste dedans.
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${r.score} / ${r.total}',
              style: AppText.mono(18, color: AppColors.ink),
            ),
            const SizedBox(height: 3),
            StatusChip.passFail(r.passed),
          ],
        ),
      ),
    );
  }
}
