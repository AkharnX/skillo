/// Ajout ou édition d'une question (US5).
///
/// Le formulaire est découpé en deux cartes : la question (énoncé, type et
/// temps limite) et la liste des choix. Chaque choix porte un bouton
/// « Bonne réponse » ; en mode choix unique, cocher un choix décoche les
/// autres. La validation métier est faite par `validateQuestion` avant
/// l'enregistrement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';

/// Écran plein pour créer ou modifier une question d'une discipline.
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.discipline,
    this.question,
  });

  /// Discipline à laquelle la question appartient.
  final Discipline discipline;

  /// Question à modifier ; `null` = nouvelle question.
  final Question? question;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

/// Brouillon d'un choix en cours d'édition : son champ texte et son état
/// « bonne réponse ».
class _ChoiceDraft {
  _ChoiceDraft(String text, this.correct)
    : controller = TextEditingController(text: text);

  /// Contrôleur du champ texte du choix.
  final TextEditingController controller;

  /// Vrai si ce choix est une bonne réponse.
  bool correct;
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  /// Énoncé de la question.
  late final TextEditingController _text;

  /// Temps limite en secondes (saisi en texte, converti à l'enregistrement).
  late final TextEditingController _time;

  /// Type de la question : choix unique ou choix multiples.
  late QuestionType _type;

  /// Les choix en cours d'édition (au moins deux).
  late final List<_ChoiceDraft> _choices;

  /// Message d'erreur de validation affiché sous le formulaire.
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _text = TextEditingController(text: q?.text ?? '');
    _time = TextEditingController(text: '${q?.timeLimitS ?? 30}');
    _type = q?.type ?? QuestionType.radio;

    // Nouvelle question : deux choix vides. Édition : un brouillon par
    // choix existant, dans le même ordre.
    _choices = [];
    if (q == null) {
      _choices.add(_ChoiceDraft('', false));
      _choices.add(_ChoiceDraft('', false));
    } else {
      for (final c in q.choices) {
        _choices.add(_ChoiceDraft(c.text, c.correct));
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _time.dispose();
    // On libère le contrôleur de chaque choix.
    for (final c in _choices) {
      c.controller.dispose();
    }
    super.dispose();
  }

  /// Construit la [Question] correspondant à l'état actuel du formulaire.
  Question _draft() {
    // Un [Choice] par brouillon, dans l'ordre d'affichage.
    final choices = <Choice>[];
    for (final c in _choices) {
      choices.add(Choice(text: c.controller.text, correct: c.correct));
    }
    return Question(
      id: widget.question?.id,
      discipline: widget.discipline,
      text: _text.text,
      type: _type,
      timeLimitS: int.tryParse(_time.text.trim()) ?? 0,
      choices: choices,
    );
  }

  /// Marque le choix [i] comme bonne réponse ou non.
  ///
  /// En mode choix unique, un seul choix peut être correct : on décoche donc
  /// tous les autres.
  void _setCorrect(int i, bool value) {
    setState(() {
      if (_type == QuestionType.radio) {
        // On parcourt tous les choix : seul le choix i garde la valeur.
        for (var j = 0; j < _choices.length; j++) {
          _choices[j].correct = j == i && value;
        }
      } else {
        _choices[i].correct = value;
      }
    });
  }

  /// Change le type de question. En passant en choix unique, on ne garde
  /// que la première bonne réponse cochée.
  void _setType(QuestionType? type) {
    if (type == null) return;
    setState(() {
      _type = type;
      if (_type != QuestionType.radio) return;

      // 1. On cherche l'index de la première bonne réponse (-1 si aucune).
      var first = -1;
      for (var j = 0; j < _choices.length; j++) {
        if (_choices[j].correct) {
          first = j;
          break;
        }
      }
      // 2. Seul cet index reste coché.
      for (var j = 0; j < _choices.length; j++) {
        _choices[j].correct = j == first;
      }
    });
  }

  /// Ajoute un choix vide en fin de liste.
  void _addChoice() => setState(() => _choices.add(_ChoiceDraft('', false)));

  /// Retire le choix [i] (impossible s'il n'en reste que deux).
  void _removeChoice(int i) {
    setState(() => _choices.removeAt(i).controller.dispose());
  }

  /// Valide puis enregistre la question et revient à la liste.
  Future<void> _save() async {
    // 1. Validation métier (énoncé, temps, nombre de bonnes réponses…).
    final q = _draft();
    final error = validateQuestion(q);
    if (error != null) {
      setState(() => _error = 'Erreur : $error');
      return;
    }
    // 2. Enregistrement puis retour.
    await context.read<QuestionRepository>().save(q);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.question == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNew
              ? 'Nouvelle question · ${widget.discipline.label}'
              : 'Modifier · ${widget.discipline.label}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          // Un défilement simple (et non un ListView) : tous les blocs sont
          // construits d'un coup, le formulaire est court.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Carte « Question » : énoncé, type et temps limite.
                _FormCard(
                  icon: Icons.help_outline,
                  title: 'Question',
                  subtitle:
                      'Énoncé, type de réponse attendue et temps accordé.',
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('editor-text'),
                        controller: _text,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          labelText: 'Énoncé de la question',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildParams(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 2. Carte « Choix ».
                _FormCard(
                  icon: Icons.checklist_rounded,
                  title: 'Choix (cochez les bonnes réponses)',
                  subtitle: _type == QuestionType.radio
                      ? 'Choix unique : exactement une bonne réponse.'
                      : 'Choix multiples : au moins une bonne réponse.',
                  child: _buildChoices(),
                ),
                // 3. Erreur de validation éventuelle.
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                // 4. Bouton d'enregistrement.
                FilledButton.icon(
                  key: const Key('editor-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Champs « type » et « temps limite », côte à côte si la place le permet.
  Widget _buildParams() {
    // Une entrée de menu par type de question.
    final items = <DropdownMenuItem<QuestionType>>[];
    for (final t in QuestionType.values) {
      items.add(DropdownMenuItem(value: t, child: Text(t.label)));
    }

    final typeField = DropdownButtonFormField<QuestionType>(
      key: const Key('editor-type'),
      initialValue: _type,
      decoration: const InputDecoration(
        labelText: 'Type',
        prefixIcon: Icon(Icons.rule),
      ),
      items: items,
      onChanged: _setType,
    );
    final timeField = TextField(
      key: const Key('editor-time'),
      controller: _time,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Temps limite',
        suffixText: 's',
        prefixIcon: Icon(Icons.timer_outlined),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Écran étroit : les deux champs sont empilés.
        if (constraints.maxWidth < 440) {
          return Column(
            children: [typeField, const SizedBox(height: 10), timeField],
          );
        }
        // Écran large : type à gauche, temps à droite.
        return Row(
          children: [
            Expanded(flex: 3, child: typeField),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: timeField),
          ],
        );
      },
    );
  }

  /// Liste des choix avec leur bouton « Bonne réponse », puis le bouton
  /// « Ajouter un choix ».
  Widget _buildChoices() {
    // Une ligne par choix ; la suppression est désactivée à deux choix.
    final rows = <Widget>[];
    for (var i = 0; i < _choices.length; i++) {
      rows.add(
        _ChoiceRow(
          index: i,
          draft: _choices[i],
          canRemove: _choices.length > 2,
          onCorrectChanged: (v) => _setCorrect(i, v),
          onRemove: () => _removeChoice(i),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        TextButton.icon(
          key: const Key('editor-add-choice'),
          onPressed: _addChoice,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un choix'),
        ),
      ],
    );
  }
}

/// Carte de formulaire : un en-tête (icône, titre, sous-titre) puis le
/// contenu, avec une légère animation d'apparition.
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;

  /// Ligne d'aide sous le titre (facultative).
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SectionTitle(title: title, subtitle: subtitle),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

/// Une ligne de choix : bouton bascule « Bonne réponse » à gauche, champ
/// texte, bouton de retrait à droite. Le fond devient vert pâle et le libellé
/// du champ indique « bonne réponse » quand le choix est correct.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onCorrectChanged,
    required this.onRemove,
  });

  /// Position du choix (à partir de 0), utilisée pour les clés de test.
  final int index;
  final _ChoiceDraft draft;

  /// Faux quand il ne reste que deux choix : on ne peut plus en retirer.
  final bool canRemove;

  /// Appelé avec la nouvelle valeur « bonne réponse ».
  final ValueChanged<bool> onCorrectChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final correct = draft.correct;
    final tint = correct ? AppColors.success : AppColors.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: correct ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: correct ? 0.4 : 0.15)),
      ),
      child: Row(
        children: [
          // Bascule « Bonne réponse » : un appui inverse l'état.
          IconButton(
            key: Key('editor-correct-$index'),
            tooltip: correct ? 'Bonne réponse' : 'Marquer comme bonne réponse',
            isSelected: correct,
            selectedIcon: const Icon(Icons.check_circle),
            icon: const Icon(Icons.radio_button_unchecked),
            color: AppColors.muted,
            style: IconButton.styleFrom(
              foregroundColor: correct ? AppColors.success : AppColors.muted,
            ),
            onPressed: () => onCorrectChanged(!correct),
          ),
          Expanded(
            child: TextField(
              key: Key('editor-choice-$index'),
              controller: draft.controller,
              decoration: InputDecoration(
                labelText: correct
                    ? 'Choix ${index + 1} · bonne réponse'
                    : 'Choix ${index + 1}',
                labelStyle: TextStyle(
                  color: correct ? AppColors.success : null,
                  fontWeight: correct ? FontWeight.w700 : null,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: canRemove ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

/// Bandeau rouge pâle avec le message d'erreur de validation.
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
