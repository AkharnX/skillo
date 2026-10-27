/// Gestion des questions (US5) : liste des questions d'une discipline, ajout,
/// édition, suppression, import JSON et réinitialisation aux questions par
/// défaut.
///
/// La discipline se choisit avec un bouton segmenté (encre quand sélectionné,
/// via le thème) ; chaque question est une carte blanche : numéro en chasse
/// fixe dans un carré teinté de la couleur de la discipline, énoncé, puis une
/// rangée de puces (type, temps limite, nombre de choix). Un appui sur la
/// carte ouvre l'éditeur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
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
      // Bouton d'ajout : encre avec l'icône en jaune signal.
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('questions-add'),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        onPressed: () => _open(QuestionEditorScreen(discipline: _discipline)),
        icon: const Icon(Icons.add, color: AppColors.accent),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
                // Marges réduites pour que les trois libellés tiennent sur un
                // téléphone ; les couleurs viennent du thème.
                style: SegmentedButton.styleFrom(
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
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
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

    // Accord du mot « question » selon le nombre.
    final count = questions.length;
    final countLabel = count > 1 ? '$count questions' : '$count question';

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
              subtitle: '$countLabel · appuyez pour modifier',
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
        ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
      },
    );
  }
}

/// Carte d'une question : numéro en chasse fixe, énoncé, puces (type, temps,
/// nombre de choix) et actions modifier / supprimer.
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
              // Numéro sur deux chiffres (« 01 ») dans un carré teinté de la
              // couleur de la discipline.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: AppText.mono(
                    13,
                    color: color,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Énoncé + puces.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: isRadio
                              ? Icons.radio_button_checked
                              : Icons.check_box_outlined,
                          label: q.type.label,
                        ),
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          label: '${q.timeLimitS} s',
                        ),
                        _InfoChip(
                          icon: Icons.format_list_bulleted,
                          label: '${q.choices.length} choix',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions, côte à côte pour garder la carte basse.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.ink),
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

/// Puce d'information : icône grise + texte court sur fond pâle.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
