import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../logic/scoring.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../state/auth_state.dart';
import 'test_result_screen.dart';

/// Passage d'un test (US2) : une question à la fois, compte à rebours par
/// question, passage automatique à la suivante quand le temps est écoulé.
/// Les questions sont chargées une fois pour toutes avant d'ouvrir l'écran.
class TestScreen extends StatefulWidget {
  const TestScreen({
    super.key,
    required this.discipline,
    required this.questions,
  });

  final Discipline discipline;
  final List<Question> questions;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _index = 0;
  late int _remaining;
  final Set<int> _selected = {};
  final List<Set<int>> _answers = [];
  Timer? _timer;
  Timer? _tapLock;
  bool _finishing = false;

  Question get _question => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tapLock?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    _timer?.cancel();
    _selected.clear();
    _remaining = _question.timeLimitS;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _next();
    });
  }

  /// Enregistre la réponse courante et passe à la question suivante
  /// (ou termine le test).
  void _next() {
    if (_finishing || _tapLock != null) return;
    // Verrou court : un double clic sur « Valider » ne saute pas de question.
    _tapLock = Timer(const Duration(milliseconds: 300), () => _tapLock = null);
    _timer?.cancel();
    _answers.add(Set.of(_selected));
    if (_index + 1 < widget.questions.length) {
      setState(() => _index++);
      _startQuestion();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    _finishing = true;
    final user = context.read<AuthState>().user!;
    final result = computeResult(
      userId: user.id,
      discipline: widget.discipline,
      questions: widget.questions,
      answers: _answers,
      now: DateTime.now(),
    );
    final results = context.read<ResultRepository>();
    try {
      await results.save(result);
    } on AlreadyTakenException {
      // Déjà enregistré (double clic, etc.) : on affiche quand même le résultat.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestResultScreen(result: result)),
    );
  }

  void _toggle(int i, bool value) {
    setState(() {
      if (_question.type == QuestionType.radio) {
        _selected
          ..clear()
          ..add(i);
      } else if (value) {
        _selected.add(i);
      } else {
        _selected.remove(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final total = widget.questions.length;
    final urgent = _remaining <= 5;
    return PopScope(
      canPop: false, // pas de retour arrière pendant un test
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Test ${widget.discipline.label}'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Chip(
                  avatar: Icon(Icons.timer, color: urgent ? Colors.red : null),
                  label: Text(
                    '$_remaining s',
                    style: TextStyle(
                      color: urgent ? Colors.red : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_index + 1) / total),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Question ${_index + 1} / $total',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(q.text, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  q.type == QuestionType.radio
                      ? 'Une seule réponse'
                      : 'Plusieurs réponses possibles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (q.type == QuestionType.radio)
                  RadioGroup<int>(
                    groupValue: _selected.isEmpty ? null : _selected.first,
                    onChanged: (v) => _toggle(v!, true),
                    child: Column(
                      children: [
                        for (var i = 0; i < q.choices.length; i++)
                          Card(
                            child: RadioListTile<int>(
                              value: i,
                              title: Text(q.choices[i].text),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < q.choices.length; i++)
                    Card(
                      child: CheckboxListTile(
                        value: _selected.contains(i),
                        onChanged: (v) => _toggle(i, v ?? false),
                        title: Text(q.choices[i].text),
                      ),
                    ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('test-validate'),
                  onPressed: _next,
                  icon: Icon(
                    _index + 1 < total ? Icons.arrow_forward : Icons.check,
                  ),
                  label: Text(
                    _index + 1 < total ? 'Valider' : 'Terminer le test',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
