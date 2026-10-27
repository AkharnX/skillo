/// Gestion des questions (US5) : liste des questions d'une discipline, ajout,
/// édition, suppression, import JSON et réinitialisation aux questions par
/// défaut.
///
/// La discipline se choisit avec un bouton segmenté ; chaque question est une
/// carte qui montre son type (choix unique / multiples), son temps limite et
/// son nombre de choix. Un appui sur la carte ouvre l'éditeur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'json_import_screen.dart';
import 'question_editor_screen.dart';

/// Écran « Questions » de l'espace admin.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  /// Discipline dont on affiche les questions.
  Discipline _discipline = Discipline.java;

  /// Questions de la discipline courante (rechargées après chaque action).
  late Future<List<Question>> _questions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Relance la lecture des questions de la discipline courante.
  void _reload() {
    _questions = context.read<QuestionRepository>().forDiscipline(_discipline);
  }

  /// Ouvre un écran (éditeur ou import) puis recharge la liste au retour,
  /// car la base a pu changer.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reload);
  }

  /// Demande confirmation puis supprime la question [q].
  Future<void> _delete(Question q) async {
    // 1. Boîte de dialogue de confirmation.
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    // 2. Suppression en base puis rechargement, seulement si confirmé.
    if (ok != true || !mounted) return;
    await context.read<QuestionRepository>().delete(q.id!);
    if (mounted) setState(_reload);
  }

  /// Demande confirmation puis remplace les questions de la discipline par
  /// les questions par défaut embarquées dans l'application.
  Future<void> _reset() async {
    // 1. Boîte de dialogue de confirmation.
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
    // 2. Réinitialisation puis rechargement, seulement si confirmé.
    if (ok != true || !mounted) return;
    await context.read<QuestionRepository>().resetFromDefaults(_discipline);
    if (mounted) setState(_reload);
  }

  /// Réagit au menu « ⋯ » : import JSON ou réinitialisation.
  void _onMenu(String value) {
    if (value == 'import') {
      _open(JsonImportScreen(discipline: _discipline));
    }
    if (value == 'reset') _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // 1. Sélecteur de discipline + menu d'actions.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildToolbar(),
              ),
              // 2. Liste des questions.
              Expanded(
                child: FutureBuilder<List<Question>>(
                  future: _questions,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildList(snapshot.data!);
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

  /// Carte du haut : bouton segmenté des disciplines et menu « ⋯ ».
  Widget _buildToolbar() {
    // Un segment par discipline, dans l'ordre de l'énumération.
    final segments = <ButtonSegment<Discipline>>[];
    for (final d in Discipline.values) {
      segments.add(
        ButtonSegment(
          value: d,
          label: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    final color = AppColors.forDiscipline(_discipline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: SegmentedButton<Discipline>(
                segments: segments,
                selected: {_discipline},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: color.withValues(alpha: 0.14),
                  selectedForegroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onSelectionChanged: (s) => setState(() {
                  _discipline = s.first;
                  _reload();
                }),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              key: const Key('questions-menu'),
              tooltip: 'Plus d\'actions',
              icon: const Icon(Icons.more_horiz),
              onSelected: _onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.upload_file_outlined),
                    title: Text('Importer / remplacer via JSON'),
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restart_alt),
                    title: Text('Réinitialiser (questions par défaut)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  /// Liste des cartes de questions, ou état vide.
  Widget _buildList(List<Question> questions) {
    // Aucune question : on invite à en ajouter ou à importer.
    if (questions.isEmpty) {
      return const EmptyState(
        icon: Icons.quiz_outlined,
        title: 'Aucune question. Ajoutez-en une ou importez un JSON.',
        message:
            'Le bouton « Ajouter » crée une question, le menu « ⋯ » '
            'importe un fichier JSON.',
      );
    }

    // Le premier élément est le titre de section, les suivants les cartes.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: questions.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionTitle(
              title: 'Questions ${_discipline.label}',
              subtitle:
                  '${questions.length} question(s) · appuyez pour modifier',
            ),
          );
        }
        final index = i - 1;
        final q = questions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _QuestionCard(
            number: index + 1,
            question: q,
            onTap: () => _open(
              QuestionEditorScreen(discipline: _discipline, question: q),
            ),
            onDelete: () => _delete(q),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
      },
    );
  }
}

/// Carte d'une question : numéro, énoncé, badges (type, temps, nombre de
/// choix) et actions modifier / supprimer.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.onTap,
    required this.onDelete,
  });

  /// Position de la question dans la liste (à partir de 1).
  final int number;
  final Question question;

  /// Ouvre l'éditeur.
  final VoidCallback onTap;

  /// Demande la suppression.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final color = AppColors.forDiscipline(q.discipline);
    final isRadio = q.type == QuestionType.radio;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Numéro de la question dans une pastille de la couleur de la
              // discipline.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              // Énoncé + badges.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: isRadio
                              ? Icons.radio_button_checked
                              : Icons.check_box_outlined,
                          label: q.type.label,
                          color: AppColors.primary,
                        ),
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          label: '${q.timeLimitS} s',
                          color: AppColors.warning,
                        ),
                        _InfoChip(
                          icon: Icons.format_list_bulleted,
                          label: '${q.choices.length} choix',
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions.
              Column(
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onTap,
                  ),
                  IconButton(
                    key: Key('delete-${q.id}'),
                    tooltip: 'Supprimer',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit badge d'information : icône + texte court, sur fond pâle.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
