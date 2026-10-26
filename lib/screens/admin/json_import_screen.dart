import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';

/// Import JSON (US5) : remplace toutes les questions d'une discipline.
/// Un bouton permet d'exporter les questions actuelles dans le même format.
class JsonImportScreen extends StatefulWidget {
  const JsonImportScreen({super.key, required this.discipline});

  final Discipline discipline;

  @override
  State<JsonImportScreen> createState() => _JsonImportScreenState();
}

class _JsonImportScreenState extends State<JsonImportScreen> {
  final _json = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  Future<void> _fillWithCurrent() async {
    final questions = await context.read<QuestionRepository>().forDiscipline(
      widget.discipline,
    );
    if (!mounted) return;
    setState(() => _json.text = questionsToJson(widget.discipline, questions));
  }

  Future<void> _import() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final parsed = parseQuestionsJson(
        _json.text,
        expected: widget.discipline,
      );
      await context.read<QuestionRepository>().replaceDiscipline(
        widget.discipline,
        parsed.questions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${parsed.questions.length} question(s) importée(s) pour ${widget.discipline.label}.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on QuestionJsonException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import JSON · ${widget.discipline.label}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Collez un document JSON. Toutes les questions actuelles de '
                '« ${widget.discipline.label} » seront remplacées.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('import-fill-current'),
                onPressed: _fillWithCurrent,
                icon: const Icon(Icons.download),
                label: const Text('Pré-remplir avec les questions actuelles'),
              ),
              TextField(
                key: const Key('import-json'),
                controller: _json,
                maxLines: 18,
                minLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: '{"discipline": "java", "questions": [ … ]}',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('import-submit'),
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload),
                label: const Text('Importer et remplacer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
