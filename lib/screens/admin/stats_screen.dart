/// Statistiques (US7) : un anneau (« donut ») de réussite par discipline et un
/// anneau global, pour l'année scolaire choisie.
///
/// Chaque anneau est une jauge fine : la part verte correspond aux tests
/// réussis, la part rouge aux tests échoués, séparées par un petit espace.
/// Le taux de réussite est écrit en grand au centre, en encre (jamais de la
/// couleur de la série), et une légende en chasse fixe donne les effectifs.
/// Sans résultat, l'anneau est gris. Les trois disciplines s'affichent sur
/// une ligne quand l'écran est assez large, sinon les unes sous les autres.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../models/discipline.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Filtre d'année.
                  _buildYearFilter(data),
                  const SizedBox(height: 22),
                  // 2. Un anneau par discipline.
                  const SectionTitle(
                    title: 'Réussite par discipline',
                    subtitle: 'Part des tests réussis et échoués',
                  ),
                  const SizedBox(height: 10),
                  _buildDisciplineGrid(data),
                  const SizedBox(height: 22),
                  // 3. Anneau global, plus grand.
                  const SectionTitle(
                    title: 'Réussite globale',
                    subtitle: 'Toutes disciplines confondues',
                  ),
                  const SizedBox(height: 10),
                  _DonutCard(
                        leading: const _GlobalMark(),
                        title: 'Global · $yearLabel',
                        caption: _label('Global $yearLabel', data.global),
                        stats: data.global,
                        size: 200,
                        rateSize: 36,
                      )
                      .animate()
                      .fadeIn(duration: 280.ms)
                      .slideY(begin: 0.04, end: 0),
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
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }

  /// Les trois anneaux de discipline : trois colonnes de même hauteur à
  /// partir de 700 px, une seule colonne (cartes empilées) sur téléphone.
  Widget _buildDisciplineGrid(_StatsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final threeColumns = constraints.maxWidth >= 700;

        // Une carte par discipline, dans l'ordre des disciplines.
        final cards = <Widget>[];
        for (final d in Discipline.values) {
          final stats = data.byDiscipline[d]!;
          cards.add(
            _DonutCard(
              leading: DisciplineAvatar(discipline: d, size: 40),
              title: d.label,
              caption: _label(d.label, stats),
              stats: stats,
              size: 150,
              rateSize: 28,
            ),
          );
        }

        // Sur téléphone : les cartes les unes sous les autres.
        if (!threeColumns) {
          final column = <Widget>[];
          for (var i = 0; i < cards.length; i++) {
            if (i > 0) column.add(const SizedBox(height: 12));
            column.add(cards[i]);
          }
          return Column(
            children: column,
          ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
        }

        // Sur grand écran : une ligne, chaque carte prend un tiers de la
        // largeur. IntrinsicHeight aligne le bas des trois cartes même si une
        // légende tient sur deux lignes.
        final row = <Widget>[];
        for (var i = 0; i < cards.length; i++) {
          if (i > 0) row.add(const SizedBox(width: 12));
          row.add(Expanded(child: cards[i]));
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: row,
          ),
        ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
      },
    );
  }
}

/// Pastille de la carte globale : carré encre pâle avec une icône encre.
class _GlobalMark extends StatelessWidget {
  const _GlobalMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.public, color: AppColors.ink, size: 20),
    );
  }
}

/// Carte avec un anneau de réussite : en-tête (pastille + titre en Space Grotesk +
/// phrase récapitulative), anneau avec le taux au centre, légende en chasse
/// fixe avec les effectifs.
class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.leading,
    required this.title,
    required this.caption,
    required this.stats,
    required this.size,
    required this.rateSize,
  });

  /// Pastille affichée à gauche du titre (discipline ou icône globale).
  final Widget leading;
  final String title;

  /// Phrase sous le titre, ex. « Java : 50 % de réussite (1 / 2) ».
  final String caption;
  final PassStats stats;

  /// Diamètre de l'anneau en pixels logiques.
  final double size;

  /// Taille du taux écrit au centre de l'anneau.
  final double rateSize;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastille + titre sur une ligne, puis la phrase de résumé sur
            // toute la largeur de la carte (elle tient ainsi sur une ligne).
            Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppText.display(18))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: _Donut(stats: stats, size: size, rateSize: rateSize),
            ),
            const SizedBox(height: 16),
            Center(child: _Legend(stats: stats)),
          ],
        ),
      ),
    );
  }
}

/// L'anneau lui-même : part verte (réussis), part rouge (échoués), taux au
/// centre. Sans résultat, un anneau gris et un tiret.
class _Donut extends StatelessWidget {
  const _Donut({
    required this.stats,
    required this.size,
    required this.rateSize,
  });

  final PassStats stats;
  final double size;
  final double rateSize;

  @override
  Widget build(BuildContext context) {
    final empty = stats.total == 0;
    // Anneau fin : épaisseur ≈ 12 % du rayon ; le trou occupe le reste.
    final radius = size / 2;
    final ring = radius * 0.12;
    final hole = radius - ring;

    // 1. Les parts de l'anneau : une seule part grise si aucun résultat,
    //    sinon une part par effectif non nul (une part vide se dessine mal).
    final sections = <PieChartSectionData>[];
    if (empty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: AppColors.border,
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

    // 2. Chiffre clé au centre : le taux de réussite, en encre.
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
              // Un espace de 2 px entre les deux parts, aucun si l'anneau
              // est plein (une seule part).
              sectionsSpace: sections.length > 1 ? 2 : 0,
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
                style: AppText.number(
                  rateSize,
                  color: empty ? AppColors.muted : AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                empty ? 'aucun test' : 'de réussite',
                style: AppText.label(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Légende sur une ligne : « ● Réussi 3 · ● Échoué 1 ». Les libellés restent
/// en gris, les effectifs en chasse fixe encre ; seul le point porte la
/// couleur de la série.
class _Legend extends StatelessWidget {
  const _Legend({required this.stats});

  final PassStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(
          color: AppColors.success,
          label: 'Réussi',
          value: stats.passed,
        ),
        const Text('·', style: TextStyle(color: AppColors.muted)),
        _LegendItem(
          color: AppColors.danger,
          label: 'Échoué',
          value: stats.failed,
        ),
      ],
    );
  }
}

/// Un élément de légende : point coloré, libellé gris, effectif en mono.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(width: 5),
        Text('$value', style: AppText.number(14, color: AppColors.ink)),
      ],
    );
  }
}
