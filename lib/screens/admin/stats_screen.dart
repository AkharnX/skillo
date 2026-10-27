/// Statistiques (US7) : un anneau (« donut ») de réussite par discipline et un
/// anneau global, pour l'année scolaire choisie.
///
/// Chaque anneau est fin : la part verte correspond aux tests réussis, la part
/// rouge aux tests échoués. Le taux de réussite est écrit en grand au centre
/// et une légende donne les effectifs. Les trois disciplines s'affichent sur
/// une ligne quand l'écran est assez large, sinon les unes sous les autres.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../models/discipline.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// Écran « Statistiques » de l'espace admin.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// Tout ce qu'il faut pour dessiner l'écran, chargé en une seule fois.
class _StatsData {
  const _StatsData(this.years, this.year, this.byDiscipline, this.global);

  /// Années scolaires présentes en base, la plus récente d'abord.
  final List<String> years;

  /// Année affichée ; `null` = toutes les années.
  final String? year;

  /// Réussites / échecs de chaque discipline.
  final Map<Discipline, PassStats> byDiscipline;

  /// Réussites / échecs toutes disciplines confondues.
  final PassStats global;
}

class _StatsScreenState extends State<StatsScreen> {
  /// Année choisie par l'utilisateur (`null` = toutes les années).
  String? _year;

  /// Vrai dès que l'utilisateur a touché la liste : avant, on affiche par
  /// défaut l'année la plus récente.
  bool _yearChosen = false;

  /// Données en cours de chargement ou chargées.
  late Future<_StatsData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Recharge les années, les statistiques par discipline et globales.
  void _reload() {
    final repo = context.read<ResultRepository>();
    _data = () async {
      // 1. Années disponibles ; par défaut on prend la plus récente.
      final years = await repo.schoolYears();
      final year = _yearChosen ? _year : (years.isEmpty ? null : years.first);
      // 2. Statistiques par discipline puis globales pour cette année.
      final byDiscipline = await repo.statsByDiscipline(schoolYear: year);
      final global = year == null
          ? await repo.globalStatsAllYears()
          : await repo.globalStats(year);
      return _StatsData(years, year, byDiscipline, global);
    }();
  }

  /// Appelé quand l'utilisateur choisit une année dans la liste.
  void _onYearChanged(String? year) {
    setState(() {
      _year = year;
      _yearChosen = true;
      _reload();
    });
  }

  /// Phrase récapitulative d'une statistique, ex.
  /// « Java : 50 % de réussite (1 / 2) ».
  static String _label(String prefix, PassStats s) =>
      '$prefix : ${(s.rate * 100).round()} % de réussite (${s.passed} / ${s.total})';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsData>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final yearLabel = data.year ?? 'toutes années';
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Filtre d'année.
                  _buildYearFilter(data),
                  const SizedBox(height: 20),
                  // 2. Un anneau par discipline.
                  const SectionTitle(
                    title: 'Réussite par discipline',
                    subtitle: 'Part des tests réussis et échoués',
                  ),
                  const SizedBox(height: 10),
                  _buildDisciplineGrid(data),
                  const SizedBox(height: 20),
                  // 3. Anneau global.
                  const SectionTitle(
                    title: 'Réussite globale',
                    subtitle: 'Toutes disciplines confondues',
                  ),
                  const SizedBox(height: 10),
                  _DonutCard(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.public,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: 'Global · $yearLabel',
                        caption: _label('Global $yearLabel', data.global),
                        stats: data.global,
                        size: 200,
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Carte avec la liste déroulante des années scolaires.
  Widget _buildYearFilter(_StatsData data) {
    // Entrées du menu : « Toutes les années » puis chaque année trouvée.
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Toutes les années'),
      ),
    ];
    for (final y in data.years) {
      items.add(DropdownMenuItem<String?>(value: y, child: Text(y)));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Année scolaire',
            prefixIcon: Icon(Icons.calendar_today_outlined),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButton<String?>(
            key: const Key('stats-year'),
            value: data.year,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: items,
            onChanged: _onYearChanged,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  /// Les trois anneaux de discipline : trois colonnes sur écran large, une
  /// seule colonne sur téléphone.
  Widget _buildDisciplineGrid(_StatsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        // Une carte par discipline, toutes de la même largeur.
        final cards = <Widget>[];
        for (final d in Discipline.values) {
          final stats = data.byDiscipline[d]!;
          cards.add(
            SizedBox(
              width: cardWidth,
              child: _DonutCard(
                leading: DisciplineAvatar(discipline: d, size: 40),
                title: d.label,
                caption: _label(d.label, stats),
                stats: stats,
                size: 150,
              ),
            ),
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

/// Carte avec un anneau de réussite : en-tête (pastille + titre + phrase
/// récapitulative), anneau avec le taux au centre, légende avec effectifs.
class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.leading,
    required this.title,
    required this.caption,
    required this.stats,
    this.size = 150,
  });

  /// Pastille affichée à gauche du titre (discipline ou icône globale).
  final Widget leading;
  final String title;

  /// Phrase sous le titre, ex. « Java : 50 % de réussite (1 / 2) ».
  final String caption;
  final PassStats stats;

  /// Diamètre de l'anneau en pixels logiques.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: SectionTitle(title: title, subtitle: caption),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: _Donut(stats: stats, size: size),
            ),
            const SizedBox(height: 16),
            _Legend(stats: stats),
          ],
        ),
      ),
    );
  }
}

/// L'anneau lui-même : part verte (réussis), part rouge (échoués), taux au
/// centre. Sans résultat, un anneau gris et un tiret.
class _Donut extends StatelessWidget {
  const _Donut({required this.stats, required this.size});

  final PassStats stats;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = stats.total == 0;
    // Anneau fin : épaisseur = 11 % du diamètre, trou = 36 % du diamètre.
    final ring = size * 0.11;
    final hole = size * 0.36;

    // 1. Les parts de l'anneau : une seule part grise si aucun résultat,
    //    sinon une part par effectif non nul (une part vide se dessine mal).
    final sections = <PieChartSectionData>[];
    if (empty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: AppColors.muted.withValues(alpha: 0.2),
          radius: ring,
          showTitle: false,
        ),
      );
    } else {
      if (stats.passed > 0) {
        sections.add(
          PieChartSectionData(
            value: stats.passed.toDouble(),
            color: AppColors.success,
            radius: ring,
            showTitle: false,
          ),
        );
      }
      if (stats.failed > 0) {
        sections.add(
          PieChartSectionData(
            value: stats.failed.toDouble(),
            color: AppColors.danger,
            radius: ring,
            showTitle: false,
          ),
        );
      }
    }

    // 2. Chiffre clé au centre : le taux de réussite.
    final rateText = empty ? '—' : '${(stats.rate * 100).round()} %';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: empty ? 0 : 2,
              centerSpaceRadius: hole,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rateText,
                style: TextStyle(
                  fontSize: size * 0.17,
                  fontWeight: FontWeight.w800,
                  // Le chiffre reste en couleur de texte : la couleur de la
                  // série est portée par l'anneau, pas par le texte.
                  color: empty ? AppColors.muted : null,
                ),
              ),
              Text(
                empty ? 'aucun test' : 'de réussite',
                style: TextStyle(
                  fontSize: size * 0.075,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Légende à deux lignes : « Réussi » et « Échoué » avec leurs effectifs.
class _Legend extends StatelessWidget {
  const _Legend({required this.stats});

  final PassStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LegendRow(
          color: AppColors.success,
          label: 'Réussi',
          value: stats.passed,
        ),
        const SizedBox(height: 6),
        _LegendRow(
          color: AppColors.danger,
          label: 'Échoué',
          value: stats.failed,
        ),
      ],
    );
  }
}

/// Une ligne de légende : point coloré, libellé, effectif aligné à droite.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
