/// Import JSON (US5) : remplace toutes les questions d'une discipline par
/// celles d'un document JSON collé dans l'écran.
///
/// Un bouton permet de pré-remplir la zone de texte avec les questions
/// actuelles, exportées dans le même format : c'est le moyen le plus simple
/// de voir le format attendu et de modifier les questions en bloc. En bas,
/// l'exemple de format est montré dans un bloc « terminal » sombre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';

/// Écran plein d'import JSON pour une discipline.
class JsonImportScreen extends StatefulWidget {
  const JsonImportScreen({super.key, required this.discipline});

  /// Discipline dont les questions seront remplacées.
  final Discipline discipline;

  @override
  State<JsonImportScreen> createState() => _JsonImportScreenState();
}

class _JsonImportScreenState extends State<JsonImportScreen> {
  /// Contenu de la zone de texte JSON.
  final _json = TextEditingController();

  /// Message d'erreur du dernier import (format ou contenu invalide).
  String? _error;

  /// Vrai pendant l'import, pour désactiver le bouton et éviter un double
  /// envoi.
  bool _busy = false;

  /// Exemple de document affiché dans l'aide au format, une ligne par entrée.
  static const _exampleLines = [
    '{',
    '  "discipline": "java",',
    '  "questions": [',
    '    {',
    '      "text": "Énoncé…",',
    '      "type": "radio",',
    '      "timeLimit": 30,',
    '      "choices": [',
    '        {"text": "Choix A", "correct": true},',
    '        {"text": "Choix B"}',
    '      ]',
    '    }',
    '  ]',
    '}',
  ];

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  /// Remplit la zone de texte avec les questions actuelles de la discipline.
  Future<void> _fillWithCurrent() async {
    final questions = await context.read<QuestionRepository>().forDiscipline(
      widget.discipline,
    );
    if (!mounted) return;
    setState(() => _json.text = questionsToJson(widget.discipline, questions));
  }

  /// Analyse le JSON puis remplace les questions de la discipline.
  Future<void> _import() async {
    // 1. On passe en mode occupé et on efface l'erreur précédente.
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      // 2. Analyse et validation (lève QuestionJsonException si invalide).
      final parsed = parseQuestionsJson(
        _json.text,
        expected: widget.discipline,
      );
      // 3. Remplacement en base, message de confirmation, retour.
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
      // Le thème met le titre en Syne.
      appBar: AppBar(title: Text('Import JSON · ${widget.discipline.label}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Avertissement : l'import remplace tout.
              _WarningBanner(
                text:
                    'Collez un document JSON. Toutes les questions actuelles de '
                    '« ${widget.discipline.label} » seront remplacées.',
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0),
              const SizedBox(height: 12),
              // 2. Zone de saisie.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DisciplineAvatar(
                            discipline: widget.discipline,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: SectionTitle(
                              title: 'Document JSON',
                              subtitle:
                                  'Collez ou modifiez le contenu ci-dessous.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('import-json'),
                        controller: _json,
                        maxLines: 18,
                        minLines: 6,
                        style: AppText.mono(13, weight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText:
                              '{"discipline": "java", "questions": [ … ]}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('import-fill-current'),
                        onPressed: _fillWithCurrent,
                        icon: const Icon(Icons.download),
                        label: const Text(
                          'Pré-remplir avec les questions actuelles',
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0),
              // 3. Erreur éventuelle.
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              // 4. Bouton d'import (encre via le thème).
              FilledButton.icon(
                key: const Key('import-submit'),
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload),
                label: const Text('Importer et remplacer'),
              ),
              const SizedBox(height: 20),
              // 5. Aide au format : l'exemple dans un bloc terminal sombre.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle(
                        title: 'Format attendu',
                        subtitle:
                            '"type" vaut "radio" (choix unique) ou "checkbox" '
                            '(choix multiples) ; "timeLimit" est en secondes ; '
                            '"correct" est facultatif (faux par défaut).',
                      ),
                      const SizedBox(height: 12),
                      _buildExample(),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  /// Bloc terminal avec l'exemple de JSON. Il occupe toute la largeur de la
  /// carte ; sur un écran étroit les lignes longues défilent horizontalement
  /// au lieu d'être coupées.
  Widget _buildExample() {
    // Une ligne de terminal par ligne de l'exemple, toutes blanches.
    final lines = <TerminalLine>[];
    for (final text in _exampleLines) {
      lines.add(TerminalLine(text));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: TerminalCard(
              title: '${widget.discipline.code}.json',
              lines: lines,
            ),
          ),
        );
      },
    );
  }
}

/// Bandeau jaune pâle : avertissement avant une action destructive. Texte
/// et icône en encre, toujours lisibles sur le jaune.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau rouge pâle avec le message d'erreur d'import.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
