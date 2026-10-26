import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../models/test_result.dart';

/// Tableau de bord admin (US6) : derniers résultats, recherche par nom ou
/// prénom, filtre par année scolaire.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _search = TextEditingController();
  String? _year; // null = toutes les années
  late Future<List<TestResult>> _results;
  late Future<List<String>> _years;

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

  void _reload() {
    _results = context.read<ResultRepository>().recent(
      search: _search.text,
      schoolYear: _year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('dashboard-search'),
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Rechercher un candidat (nom ou prénom)',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(_reload),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FutureBuilder<List<String>>(
                      future: _years,
                      builder: (context, snapshot) => DropdownButton<String?>(
                        key: const Key('dashboard-year'),
                        value: _year,
                        hint: const Text('Année scolaire'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Toutes les années'),
                          ),
                          for (final y in snapshot.data ?? const <String>[])
                            DropdownMenuItem<String?>(value: y, child: Text(y)),
                        ],
                        onChanged: (y) => setState(() {
                          _year = y;
                          _reload();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<TestResult>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final results = snapshot.data!;
                    if (results.isEmpty) {
                      return const Center(child: Text('Aucun résultat'));
                    }
                    return ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = results[i];
                        return ListTile(
                          leading: Icon(
                            r.passed ? Icons.check_circle : Icons.cancel,
                            color: r.passed ? Colors.green : Colors.red,
                          ),
                          title: Text(r.candidateName ?? '?'),
                          subtitle: Text(
                            '${r.discipline.label} · ${dateFormat.format(r.takenAt)} · ${r.schoolYear}',
                          ),
                          trailing: Text(
                            '${r.score} / ${r.total}  (${r.percent.round()} %)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
