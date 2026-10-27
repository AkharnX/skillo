/// Ajout ou édition d'une question (US5).
///
/// Le formulaire est découpé en deux cartes : la question (énoncé, type et
/// temps limite) et la liste des choix. Devant chaque choix, la lettre (A, B,
/// C…) sert de bouton « Bonne réponse » : encre et jaune quand le choix est
/// coché, comme sur l'écran de test du candidat. En mode choix unique, cocher
/// un choix décoche les autres. La validation métier est faite par
/// `validateQuestion` avant l'enregistrement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../logic/question_json.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
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
      // Le thème met le titre en Space Grotesk.
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
          // construits d'un coup, le formulaire est court. Le bloc « Question »
          // reste compact pour que les deux premiers choix soient visibles
          // sans défiler sur un petit écran.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Carte « Question » : énoncé, type et temps limite.
                _FormCard(
                  title: 'Question',
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
                      const SizedBox(height: 10),
                      _buildParams(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 2. Carte « Choix ».
                _FormCard(
                  title: 'Choix',
                  hint: _type == QuestionType.radio
                      ? 'Touchez la lettre pour marquer la bonne réponse '
                            '(une seule).'
                      : 'Touchez les lettres pour marquer les bonnes réponses.',
                  child: _buildChoices(),
                ),
                // 3. Erreur de validation éventuelle.
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                // 4. Bouton d'enregistrement (encre via le thème).
                FilledButton.icon(
                  key: const Key('editor-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
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
      // Le menu prend toute la largeur du champ : le libellé le plus long ne
      // déborde jamais sur un téléphone.
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Type',
        prefixIcon: Icon(Icons.rule),
      ),
      items: items,
      onChanged: _setType,
    );
    // Le temps se saisit en chiffres : chasse fixe.
    final timeField = TextField(
      key: const Key('editor-time'),
      controller: _time,
      keyboardType: TextInputType.number,
      style: AppText.mono(15),
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

  /// Liste des choix avec leur lettre-bascule, puis le bouton « Ajouter un
  /// choix ».
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const Key('editor-add-choice'),
          onPressed: _addChoice,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un choix'),
        ),
      ],
    );
  }
}

/// Carte de formulaire : titre en Space Grotesk, ligne d'aide optionnelle, puis le
/// contenu, avec une légère animation d'apparition.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, this.hint, required this.child});

  final String title;

  /// Ligne d'aide sous le titre (facultative).
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(18)),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(
                hint!,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }
}

/// Une ligne de choix : lettre-bascule « Bonne réponse » à gauche (encre et
/// jaune quand cochée), champ texte, bouton de retrait à droite.
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
    final letter = String.fromCharCode('A'.codeUnitAt(0) + index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Bascule « Bonne réponse » : un appui inverse l'état. La zone
          // tactile est plus large que la lettre (48 px).
          Tooltip(
            message: correct ? 'Bonne réponse' : 'Marquer comme bonne réponse',
            child: Semantics(
              button: true,
              toggled: correct,
              child: InkWell(
                key: Key('editor-correct-$index'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onCorrectChanged(!correct),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ChoiceLetter(
                    index: index,
                    selected: correct,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: Key('editor-choice-$index'),
              controller: draft.controller,
              decoration: InputDecoration(
                labelText: correct
                    ? 'Choix $letter · bonne réponse'
                    : 'Choix $letter',
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
            color: AppColors.muted,
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
