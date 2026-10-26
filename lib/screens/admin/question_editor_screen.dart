import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';

/// Ajout ou édition d'une question (US5).
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.discipline,
    this.question,
  });

  final Discipline discipline;

  /// null = nouvelle question.
  final Question? question;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _ChoiceDraft {
  _ChoiceDraft(String text, this.correct)
    : controller = TextEditingController(text: text);
  final TextEditingController controller;
  bool correct;
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final TextEditingController _text;
  late final TextEditingController _time;
  late QuestionType _type;
  late final List<_ChoiceDraft> _choices;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _text = TextEditingController(text: q?.text ?? '');
    _time = TextEditingController(text: '${q?.timeLimitS ?? 30}');
    _type = q?.type ?? QuestionType.radio;
    _choices = q == null
        ? [_ChoiceDraft('', false), _ChoiceDraft('', false)]
        : [for (final c in q.choices) _ChoiceDraft(c.text, c.correct)];
  }

  @override
  void dispose() {
    _text.dispose();
    _time.dispose();
    for (final c in _choices) {
      c.controller.dispose();
    }
    super.dispose();
  }

  Question _draft() => Question(
    id: widget.question?.id,
    discipline: widget.discipline,
    text: _text.text,
    type: _type,
    timeLimitS: int.tryParse(_time.text.trim()) ?? 0,
    choices: [
      for (final c in _choices)
        Choice(text: c.controller.text, correct: c.correct),
    ],
  );

  void _setCorrect(int i, bool value) {
    setState(() {
      if (_type == QuestionType.radio) {
        for (var j = 0; j < _choices.length; j++) {
          _choices[j].correct = j == i && value;
        }
      } else {
        _choices[i].correct = value;
      }
    });
  }

  Future<void> _save() async {
    final q = _draft();
    final error = validateQuestion(q);
    if (error != null) {
      setState(() => _error = 'Erreur : $error');
      return;
    }
    await context.read<QuestionRepository>().save(q);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.question == null
              ? 'Nouvelle question · ${widget.discipline.label}'
              : 'Modifier · ${widget.discipline.label}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('editor-text'),
                controller: _text,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Énoncé de la question',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<QuestionType>(
                      key: const Key('editor-type'),
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final t in QuestionType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (t) => setState(() {
                        _type = t!;
                        if (_type == QuestionType.radio) {
                          // Au plus une bonne réponse en mode choix unique.
                          final first = _choices.indexWhere((c) => c.correct);
                          for (var j = 0; j < _choices.length; j++) {
                            _choices[j].correct = j == first;
                          }
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const Key('editor-time'),
                      controller: _time,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Temps limite (s)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Choix (cochez les bonnes réponses)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        key: Key('editor-correct-$i'),
                        value: _choices[i].correct,
                        onChanged: (v) => _setCorrect(i, v ?? false),
                      ),
                      Expanded(
                        child: TextField(
                          key: Key('editor-choice-$i'),
                          controller: _choices[i].controller,
                          decoration: InputDecoration(
                            labelText: 'Choix ${i + 1}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _choices.length <= 2
                            ? null
                            : () => setState(
                                () => _choices.removeAt(i).controller.dispose(),
                              ),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                key: const Key('editor-add-choice'),
                onPressed: () =>
                    setState(() => _choices.add(_ChoiceDraft('', false))),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un choix'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('editor-save'),
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
