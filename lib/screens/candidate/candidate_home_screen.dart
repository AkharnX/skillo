import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../data/result_repository.dart';
import '../../models/discipline.dart';
import '../../models/test_result.dart';
import '../../state/auth_state.dart';
import 'profile_screen.dart';
import 'test_screen.dart';

/// Accueil candidat : les trois disciplines, à passer ou déjà passées.
class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  late Future<Map<Discipline, TestResult>> _results;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = context.read<AuthState>().user!;
    _results = context
        .read<ResultRepository>()
        .forUser(user.id)
        .then((list) => {for (final r in list) r.discipline: r});
  }

  Future<void> _start(Discipline d) async {
    if (_starting) return; // évite un double tap
    setState(() => _starting = true);
    try {
      final user = context.read<AuthState>().user!;
      final questions = await context.read<QuestionRepository>().forDiscipline(
        d,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        _snack('Aucune question disponible pour ${d.label}.');
        return;
      }
      // Le test est marqué « commencé » avant d'ouvrir l'écran : un
      // rechargement en cours de test ne permet pas de le repasser.
      try {
        await context.read<ResultRepository>().start(
          user.id,
          d,
          questions.length,
          DateTime.now(),
        );
      } on AlreadyTakenException {
        if (mounted) _snack('Vous avez déjà passé le test ${d.label}.');
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TestScreen(discipline: d, questions: questions),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _load();
        });
      }
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour ${auth.user!.firstName}'),
        actions: [
          IconButton(
            key: const Key('go-profile'),
            tooltip: 'Mon profil',
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (mounted) setState(_load);
            },
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
          ),
        ],
      ),
      body: FutureBuilder<Map<Discipline, TestResult>>(
        future: _results,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Choisissez une évaluation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final d in Discipline.values)
                    _DisciplineCard(
                      discipline: d,
                      result: results[d],
                      onStart: _starting ? null : () => _start(d),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.discipline,
    required this.result,
    required this.onStart,
  });

  final Discipline discipline;
  final TestResult? result;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(discipline.label[0])),
        title: Text(discipline.label),
        subtitle: r == null
            ? const Text('Pas encore passé')
            : Text('Score : ${r.score} / ${r.total} (${r.percent.round()} %)'),
        trailing: r == null
            ? FilledButton(
                key: Key('start-${discipline.code}'),
                onPressed: onStart,
                child: const Text('Passer le test'),
              )
            : Icon(
                r.passed ? Icons.check_circle : Icons.cancel,
                color: r.passed ? Colors.green : Colors.red,
              ),
      ),
    );
  }
}
