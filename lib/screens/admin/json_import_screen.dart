/// Import JSON (US5) : remplace toutes les questions d'une discipline par
/// celles d'un document JSON collé dans l'écran.
///
/// Un bouton permet de pré-remplir la zone de texte avec les questions
/// actuelles, exportées dans le même format : c'est le moyen le plus simple
/// de voir le format attendu et de modifier les questions en bloc.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';
import '../../theme/app_colors.dart';
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

  /// Exemple de document affiché dans l'aide au format.
  static const _example =
      '{\n'
      '  "discipline": "java",\n'
      '  "questions": [\n'
      '    {\n'
      '      "text": "Énoncé…",\n'
      '      "type": "radio",\n'
      '      "timeLimit": 30,\n'
      '      "choices": [\n'
      '        {"text": "Choix A", "correct": true},\n'
      '        {"text": "Choix B"}\n'
      '      ]\n'
      '    }\n'
      '  ]\n'
      '}';

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
    final color = AppColors.forDiscipline(widget.discipline);
    return Scaffold(
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
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
              const SizedBox(height: 12),
              // 2. Zone de saisie.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
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
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
              // 3. Erreur éventuelle.
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              // 4. Bouton d'import.
              FilledButton.icon(
                key: const Key('import-submit'),
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.upload),
                label: const Text('Importer et remplacer'),
              ),
              const SizedBox(height: 20),
              // 5. Aide au format.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Format attendu',
                        subtitle:
                            '"type" vaut "radio" (choix unique) ou "checkbox" '
                            '(choix multiples) ; "timeLimit" est en secondes ; '
                            '"correct" est facultatif (faux par défaut).',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const SelectableText(
                          _example,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau orange pâle : avertissement avant une action destructive.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
