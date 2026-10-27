/// Passage d'un test (US2) : une question à la fois, compte à rebours par
/// question, passage automatique à la suivante quand le temps est écoulé.
///
/// Les questions sont chargées une fois pour toutes avant d'ouvrir l'écran.
/// En haut : la discipline, un compte à rebours bien visible (qui passe en
/// orange sous 10 s puis en rouge sous 5 s) et une barre de progression
/// « question i / n ». Au centre : la question dans une carte, puis les
/// réponses sous forme de cartes cliquables (bord violet + fond pâle quand
/// la réponse est cochée). En bas : le bouton « Valider ».
///
/// Le retour arrière est bloqué (PopScope) : on ne quitte un test qu'en le
/// terminant.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../logic/scoring.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'test_result_screen.dart';

/// Écran de passage d'un test.
class TestScreen extends StatefulWidget {
  const TestScreen({
    super.key,
    required this.discipline,
    required this.questions,
  });

  /// Discipline du test (sert au titre, à la couleur et au résultat).
  final Discipline discipline;

  /// Questions à poser, dans l'ordre. Jamais vide (vérifié par l'accueil).
  final List<Question> questions;

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  /// Index de la question affichée dans [TestScreen.questions].
  int _index = 0;

  /// Secondes restantes pour la question courante.
  late int _remaining;

  /// Index des réponses cochées pour la question courante.
  final Set<int> _selected = {};

  /// Réponses données, une entrée par question déjà validée (même ordre que
  /// les questions). Sert au calcul du score à la fin.
  final List<Set<int>> _answers = [];

  /// Chrono de la question : décrémente [_remaining] chaque seconde.
  Timer? _timer;

  /// Verrou court (300 ms) posé après chaque validation : un double clic sur
  /// « Valider » ne doit pas sauter une question.
  Timer? _tapLock;

  /// Vrai dès que le test est en cours d'enregistrement : plus aucune
  /// validation n'est acceptée.
  bool _finishing = false;

  /// Question courante.
  Question get _question => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    // On arrête les deux timers pour ne pas appeler setState après la
    // destruction de l'écran.
    _timer?.cancel();
    _tapLock?.cancel();
    super.dispose();
  }

  /// Prépare la question courante : remet les cases à zéro et relance le
  /// compte à rebours avec le temps limite de cette question.
  void _startQuestion() {
    // 1. On arrête l'ancien chrono et on vide la sélection.
    _timer?.cancel();
    _selected.clear();
    _remaining = _question.timeLimitS;

    // 2. Nouveau chrono : chaque seconde on décrémente ; à zéro on passe à
    //    la question suivante automatiquement.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _next();
    });
  }

  /// Enregistre la réponse courante et passe à la question suivante
  /// (ou termine le test).
  void _next() {
    // 1. Refus si le test se termine déjà ou si un clic vient d'être traité.
    if (_finishing || _tapLock != null) return;

    // 2. Verrou court : un double clic sur « Valider » ne saute pas de
    //    question.
    _tapLock = Timer(const Duration(milliseconds: 300), () => _tapLock = null);

    // 3. On fige la réponse (copie du Set, car _selected sera vidé).
    _timer?.cancel();
    _answers.add(Set.of(_selected));

    // 4. Question suivante, ou fin du test.
    if (_index + 1 < widget.questions.length) {
      setState(() => _index++);
      _startQuestion();
    } else {
      _finish();
    }
  }

  /// Calcule le résultat, l'enregistre et affiche l'écran de résultat.
  Future<void> _finish() async {
    _finishing = true;

    // 1. Calcul du score à partir des réponses données.
    final user = context.read<AuthState>().user!;
    final result = computeResult(
      userId: user.id,
      discipline: widget.discipline,
      questions: widget.questions,
      answers: _answers,
      now: DateTime.now(),
    );

    // 2. Enregistrement en base (une seule tentative par discipline).
    final results = context.read<ResultRepository>();
    try {
      await results.save(result);
    } on AlreadyTakenException {
      // Déjà enregistré (double clic, etc.) : on affiche quand même le résultat.
    }
    if (!mounted) return;

    // 3. On remplace l'écran de test par l'écran de résultat : impossible de
    //    revenir sur le test.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestResultScreen(result: result)),
    );
  }

  /// Coche ou décoche la réponse [i].
  ///
  /// Pour une question à choix unique, cocher une réponse remplace la
  /// précédente. Pour une question à choix multiples, [value] indique si on
  /// ajoute ou retire l'index.
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

  /// Couleur du compte à rebours selon l'urgence : normale, orange sous 10 s,
  /// rouge sous 5 s.
  Color _timerColor() {
    if (_remaining <= 5) return AppColors.danger;
    if (_remaining <= 10) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final total = widget.questions.length;
    final isLast = _index + 1 >= total;
    return PopScope(
      canPop: false, // pas de retour arrière pendant un test
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  // 1. Bandeau du haut : discipline, chrono, progression.
                  _buildTopBar(total),

                  // 2. Question et réponses (défilables).
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        // La carte question + les réponses réapparaissent en
                        // fondu à chaque changement de question (clé = index).
                        _QuestionFadeIn(
                          key: ValueKey(_index),
                          child: _buildQuestionBlock(q),
                        ),
                      ],
                    ),
                  ),

                  // 3. Bouton de validation, toujours visible en bas.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      key: const Key('test-validate'),
                      onPressed: _next,
                      icon: Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(isLast ? 'Terminer le test' : 'Valider'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bandeau du haut : avatar + nom de la discipline, compte à rebours,
  /// puis « Question i / n » avec une barre de progression.
  Widget _buildTopBar(int total) {
    final color = AppColors.forDiscipline(widget.discipline);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DisciplineAvatar(discipline: widget.discipline, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Test ${widget.discipline.label}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CountdownPill(remaining: _remaining, color: _timerColor()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Question ${_index + 1} / $total',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              Text(
                '${((_index + 1) * 100 / total).round()} %',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte de la question suivie des cartes de réponse.
  Widget _buildQuestionBlock(Question q) {
    final isRadio = q.type == QuestionType.radio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Énoncé de la question + rappel du type de réponse attendu.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusChip(
                  label: isRadio
                      ? 'Une seule réponse'
                      : 'Plusieurs réponses possibles',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  q.text,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Réponses : un groupe radio ou des cases à cocher, mais toujours
        // présentées comme des cartes cliquables.
        if (isRadio)
          RadioGroup<int>(
            groupValue: _selected.isEmpty ? null : _selected.first,
            onChanged: (v) => _toggle(v!, true),
            child: Column(children: _buildChoiceCards(q)),
          )
        else
          Column(children: _buildChoiceCards(q)),
      ],
    );
  }

  /// Construit une carte par réponse possible.
  ///
  /// On parcourt les choix de la question (avec leur index, nécessaire pour
  /// cocher/décocher) et on accumule une carte par choix ; le résultat est la
  /// liste des cartes à afficher dans l'ordre.
  List<Widget> _buildChoiceCards(Question q) {
    final cards = <Widget>[];
    for (var i = 0; i < q.choices.length; i++) {
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceCard(
            index: i,
            text: q.choices[i].text,
            isRadio: q.type == QuestionType.radio,
            selected: _selected.contains(i),
            onToggle: (value) => _toggle(i, value),
          ),
        ),
      );
    }
    return cards;
  }
}

/// Apparition en fondu + léger glissement de la question courante.
///
/// On n'utilise pas flutter_animate ici : il programme un `Future.delayed`
/// à chaque apparition, ce qui laisse une minuterie en attente quand une
/// question change juste avant la fin d'un test de widget. Un
/// [TweenAnimationBuilder] n'a besoin que d'un ticker, sans minuterie, et
/// la question précédente disparaît immédiatement (pas de fondu sortant).
class _QuestionFadeIn extends StatelessWidget {
  const _QuestionFadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
      // `value` va de 0 à 1 : opacité croissante, décalage vertical de 12 px
      // qui se résorbe.
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
    );
  }
}

/// Compte à rebours en forme de pastille : icône chrono + « 12 s ».
///
/// La couleur est fournie par l'écran (violet, orange ou rouge) et le
/// changement de couleur est animé pour attirer l'œil sans brutalité.
class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.remaining, required this.color});

  /// Secondes restantes.
  final int remaining;

  /// Couleur d'urgence (texte et fond pâle).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            '$remaining s',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte cliquable d'une réponse.
///
/// Toute la carte réagit au clic (pas seulement le bouton radio ou la case),
/// et la sélection est soulignée par un bord violet et un fond pâle. Pour une
/// question radio, le [Radio] s'inscrit automatiquement dans le [RadioGroup]
/// parent ; pour une question à choix multiples, on utilise un [Checkbox].
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.index,
    required this.text,
    required this.isRadio,
    required this.selected,
    required this.onToggle,
  });

  /// Index du choix dans la question (valeur du radio / de la case).
  final int index;

  /// Texte de la réponse.
  final String text;

  /// Vrai pour une question à choix unique.
  final bool isRadio;

  /// Vrai si cette réponse est cochée.
  final bool selected;

  /// Appelé avec la nouvelle valeur (cochée ou non) quand on clique.
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary
        : AppColors.muted.withValues(alpha: 0.25);
    final fillColor = selected
        ? AppColors.primary.withValues(alpha: 0.08)
        : AppColors.surface;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Un clic sur la carte : une radio se coche toujours, une case bascule.
        onTap: () => onToggle(isRadio ? true : !selected),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
          ),
          child: Row(
            children: [
              // Le contrôle natif garde la sémantique (accessibilité) et
              // l'état visuel standard.
              if (isRadio)
                Radio<int>(value: index)
              else
                Checkbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
