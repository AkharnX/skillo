import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../models/discipline.dart';

/// Statistiques (US7) : un camembert de réussite par discipline et un
/// camembert global pour l'année scolaire choisie.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsData {
  const _StatsData(this.years, this.year, this.byDiscipline, this.global);
  final List<String> years;
  final String? year;
  final Map<Discipline, PassStats> byDiscipline;
  final PassStats global;
}

class _StatsScreenState extends State<StatsScreen> {
  String? _year;
  bool _yearChosen = false;
  late Future<_StatsData> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<ResultRepository>();
    _data = () async {
      final years = await repo.schoolYears();
      // Par défaut : l'année la plus récente.
      final year = _yearChosen ? _year : (years.isEmpty ? null : years.first);
      final byDiscipline = await repo.statsByDiscipline(schoolYear: year);
      final global = year == null
          ? await repo.globalStatsAllYears()
          : await repo.globalStats(year);
      return _StatsData(years, year, byDiscipline, global);
    }();
  }

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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Année scolaire : '),
                      DropdownButton<String?>(
                        key: const Key('stats-year'),
                        value: data.year,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Toutes les années'),
                          ),
                          for (final y in data.years)
                            DropdownMenuItem<String?>(value: y, child: Text(y)),
                        ],
                        onChanged: (y) => setState(() {
                          _year = y;
                          _yearChosen = true;
                          _reload();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Réussite par discipline',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (final d in Discipline.values)
                        _PieCard(
                          title: _label(d.label, data.byDiscipline[d]!),
                          stats: data.byDiscipline[d]!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Réussite globale',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Center(
                    child: _PieCard(
                      title: _label('Global $yearLabel', data.global),
                      stats: data.global,
                      size: 220,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _label(String prefix, PassStats s) =>
      '$prefix : ${(s.rate * 100).round()} % de réussite (${s.passed} / ${s.total})';
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.title, required this.stats, this.size = 160});

  final String title;
  final PassStats stats;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = stats.total == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: size / 5,
                  sections: empty
                      ? [
                          PieChartSectionData(
                            value: 1,
                            color: Colors.grey.shade300,
                            title: 'Aucun résultat',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            radius: size / 4,
                          ),
                        ]
                      : [
                          if (stats.passed > 0)
                            PieChartSectionData(
                              value: stats.passed.toDouble(),
                              color: Colors.green,
                              title: '${(stats.rate * 100).round()} %',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              radius: size / 4,
                            ),
                          if (stats.failed > 0)
                            PieChartSectionData(
                              value: stats.failed.toDouble(),
                              color: Colors.red,
                              title: '${100 - (stats.rate * 100).round()} %',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              radius: size / 4,
                            ),
                        ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Legend(color: Colors.green, label: 'Réussi'),
                SizedBox(width: 12),
                _Legend(color: Colors.red, label: 'Échoué'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
