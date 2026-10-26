import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import 'json_import_screen.dart';
import 'question_editor_screen.dart';

/// Gestion des questions (US5) : liste par discipline, ajout, édition,
/// suppression, import JSON et réinitialisation.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  Discipline _discipline = Discipline.java;
  late Future<List<Question>> _questions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _questions = context.read<QuestionRepository>().forDiscipline(_discipline);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reload);
  }

  Future<void> _delete(Question q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la question ?'),
        content: Text(q.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<QuestionRepository>().delete(q.id!);
    if (mounted) setState(_reload);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réinitialiser ${_discipline.label} ?'),
        content: const Text(
          'Toutes les questions de cette discipline seront remplacées par les questions par défaut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<QuestionRepository>().resetFromDefaults(_discipline);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
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
                      child: SegmentedButton<Discipline>(
                        segments: [
                          for (final d in Discipline.values)
                            ButtonSegment(value: d, label: Text(d.label)),
                        ],
                        selected: {_discipline},
                        onSelectionChanged: (s) => setState(() {
                          _discipline = s.first;
                          _reload();
                        }),
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: const Key('questions-menu'),
                      onSelected: (v) {
                        if (v == 'import') {
                          _open(JsonImportScreen(discipline: _discipline));
                        }
                        if (v == 'reset') _reset();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'import',
                          child: Text('Importer / remplacer via JSON'),
                        ),
                        PopupMenuItem(
                          value: 'reset',
                          child: Text('Réinitialiser (questions par défaut)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Question>>(
                  future: _questions,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final questions = snapshot.data!;
                    if (questions.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucune question. Ajoutez-en une ou importez un JSON.',
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, i) {
                        final q = questions[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(q.text),
                          subtitle: Text(
                            '${q.type.label} · ${q.timeLimitS} s · ${q.choices.length} choix',
                          ),
                          onTap: () => _open(
                            QuestionEditorScreen(
                              discipline: _discipline,
                              question: q,
                            ),
                          ),
                          trailing: IconButton(
                            key: Key('delete-${q.id}'),
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(q),
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('questions-add'),
        onPressed: () => _open(QuestionEditorScreen(discipline: _discipline)),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
