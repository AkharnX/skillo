/// Passage d'un test (US2) : une question à la fois, compte à rebours par
/// question, passage automatique à la suivante quand le temps est écoulé.
///
/// Les questions sont chargées une fois pour toutes avant d'ouvrir l'écran.
/// En haut : une barre encre pleine largeur avec la discipline et le compte à
/// rebours en pastille jaune signal (orange sous 10 s, rouge sous 5 s). Sous
/// la barre, sur le fond clair : « Question i / n » en chasse fixe et une
/// barre de progression encre. Au centre : la question dans une carte, puis
/// les réponses sous forme de cartes cliquables (lettre A, B, C… à gauche,
/// bord encre + fond jaune pâle quand la réponse est cochée). En bas : le
/// bouton « Valider ».
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
import '../../theme/app_text.dart';
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

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final total = widget.questions.length;
    final isLast = _index + 1 >= total;
    return PopScope(
      canPop: false, // pas de retour arrière pendant un test
      child: Scaffold(
        body: Column(
          children: [
            // 1. Barre encre pleine largeur : discipline + chrono.
            _buildTopBar(),

            // 2. Le reste, centré et limité à 640 px de large.
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        // 2a. « Question i / n » et barre de progression.
                        _buildProgress(total),

                        // 2b. Question et réponses (défilables).
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            children: [
                              // La carte question + les réponses
                              // réapparaissent en fondu à chaque changement
                              // de question (clé = index).
                              _QuestionFadeIn(
                                key: ValueKey(_index),
                                child: _buildQuestionBlock(q),
                              ),
                            ],
                          ),
                        ),

                        // 2c. Bouton de validation, toujours visible en bas.
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
                            label: Text(
                              isLast ? 'Terminer le test' : 'Valider',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre encre du haut : avatar + « Test Java » en Syne blanc à gauche, le
  /// compte à rebours en pastille à droite. La couleur encre monte derrière
  /// la barre d'état ; le contenu est aligné sur la colonne de 640 px.
  Widget _buildTopBar() {
    return Container(
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  DisciplineAvatar(discipline: widget.discipline, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Test ${widget.discipline.label}',
                      style: AppText.display(20, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CountdownPill(remaining: _remaining),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sous la barre : « Question i / n » (numéro en chasse fixe), le
  /// pourcentage d'avancement à droite, et une barre de progression encre.
  Widget _buildProgress(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Un seul Text.rich : le mot en gris, le numéro en chasse fixe.
              // Les tests cherchent le texte « Question 1 / … » d'un bloc.
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Question ',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                    TextSpan(
                      text: '${_index + 1} / $total',
                      style: AppText.mono(15, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${((_index + 1) * 100 / total).round()} %',
                style: AppText.mono(13, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 6,
              color: AppColors.ink,
              backgroundColor: AppColors.border,
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
                  color: AppColors.ink,
                ),
                const SizedBox(height: 14),
                // Syne 22 avec un interlignage un peu plus large que celui
                // des titres : un énoncé tient souvent sur plusieurs lignes.
                Text(q.text, style: AppText.display(22).copyWith(height: 1.25)),
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

/// Compte à rebours en forme de pastille : icône chrono + « 12 s » en chasse
/// fixe (les chiffres ont tous la même largeur : rien ne bouge en décomptant).
///
/// Couleurs selon l'urgence : jaune signal avec texte encre normalement,
/// orange sous 10 s, rouge avec texte blanc sous 5 s. Le changement est animé
/// pour attirer l'œil sans brutalité.
class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.remaining});

  /// Secondes restantes.
  final int remaining;

  /// Couleur de fond selon les secondes restantes.
  Color get _background {
    if (remaining <= 5) return AppColors.danger;
    if (remaining <= 10) return AppColors.warning;
    return AppColors.accent;
  }

  /// Couleur du texte et de l'icône : blanc sur rouge, encre sinon.
  Color get _foreground => remaining <= 5 ? Colors.white : AppColors.ink;

  @override
  Widget build(BuildContext context) {
    final fg = _foreground;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            '$remaining s',
            style: AppText.mono(18, color: fg, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Carte cliquable d'une réponse.
///
/// De gauche à droite : la lettre du choix ([ChoiceLetter], qui passe en
/// encre + jaune quand il est coché), le texte, puis le contrôle natif (radio
/// ou case) qui garde la sémantique d'accessibilité. Toute la carte réagit
/// au clic, et la sélection est soulignée par un bord encre et un fond jaune
/// pâle. Pour une question radio, le [Radio] s'inscrit automatiquement dans
/// le [RadioGroup] parent ; pour une question à choix multiples, on utilise
/// un [Checkbox].
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
    final borderColor = selected ? AppColors.ink : AppColors.border;
    final fillColor = selected ? AppColors.accentSoft : AppColors.surface;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Un clic sur la carte : une radio se coche toujours, une case bascule.
        onTap: () => onToggle(isRadio ? true : !selected),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.8 : 1),
          ),
          child: Row(
            children: [
              ChoiceLetter(index: index, selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Le contrôle natif garde la sémantique (accessibilité) et
              // l'état visuel standard.
              if (isRadio)
                Radio<int>(value: index)
              else
                Checkbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
