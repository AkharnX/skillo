/// Accueil candidat : les trois disciplines, à passer ou déjà passées.
///
/// En haut, un en-tête en dégradé salue le candidat et résume ses tests
/// (combien passés, combien réussis). En dessous, une carte par discipline :
/// un bouton « Passer le test » si le test n'a pas encore été fait, sinon le
/// score obtenu avec un badge Réussi / Échoué. Un test ne peut être passé
/// qu'une seule fois : le résultat est créé en base *avant* d'ouvrir l'écran
/// de test, ce qui rend l'application résistante à un rechargement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../data/result_repository.dart';
import '../../models/discipline.dart';
import '../../models/test_result.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'profile_screen.dart';
import 'test_screen.dart';

/// Écran d'accueil du candidat connecté.
class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  /// Résultats du candidat, indexés par discipline (une discipline absente de
  /// la map = test pas encore passé). C'est un Future : la liste est lue en
  /// base et affichée par un [FutureBuilder].
  late Future<Map<Discipline, TestResult>> _results;

  /// Verrou anti double-tap : vrai entre le clic sur « Passer le test » et
  /// le retour de l'écran de test. Tant qu'il est vrai, les boutons sont
  /// désactivés et [_start] refuse de relancer un test.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// (Re)lance la lecture des résultats en base.
  void _load() {
    final user = context.read<AuthState>().user!;
    _results = context
        .read<ResultRepository>()
        .forUser(user.id)
        .then(_indexByDiscipline);
  }

  /// Transforme la liste des résultats en une map « discipline → résultat ».
  ///
  /// On parcourt chaque résultat de la liste et on le range dans la map sous
  /// sa discipline. À la fin, la map contient au plus un résultat par
  /// discipline (la base garantit déjà l'unicité).
  Map<Discipline, TestResult> _indexByDiscipline(List<TestResult> list) {
    final byDiscipline = <Discipline, TestResult>{};
    for (final result in list) {
      byDiscipline[result.discipline] = result;
    }
    return byDiscipline;
  }

  /// Démarre le test d'une discipline.
  ///
  /// Étapes : charger les questions, marquer le test comme « commencé » en
  /// base (une seule tentative), ouvrir l'écran de test, puis recharger les
  /// résultats au retour. Le verrou [_starting] empêche un double clic de
  /// lancer deux tests.
  Future<void> _start(Discipline d) async {
    if (_starting) return; // évite un double tap
    setState(() => _starting = true);
    try {
      // 1. On charge les questions de la discipline.
      final user = context.read<AuthState>().user!;
      final questions = await context.read<QuestionRepository>().forDiscipline(
        d,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        _snack('Aucune question disponible pour ${d.label}.');
        return;
      }

      // 2. Le test est marqué « commencé » avant d'ouvrir l'écran : un
      //    rechargement en cours de test ne permet pas de le repasser.
      try {
        await context.read<ResultRepository>().start(
          user.id,
          d,
          questions.length,
          DateTime.now(),
        );
      } on AlreadyTakenException {
        if (mounted) _snack('Vous avez déjà passé le test ${d.label}.');
        return;
      }
      if (!mounted) return;

      // 3. On ouvre l'écran de test et on attend sa fermeture.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TestScreen(discipline: d, questions: questions),
        ),
      );
    } finally {
      // 4. Quoi qu'il arrive, on libère le verrou et on recharge les scores.
      if (mounted) {
        setState(() {
          _starting = false;
          _load();
        });
      }
    }
  }

  /// Ouvre le profil, puis recharge les résultats au retour.
  Future<void> _openProfile() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (mounted) setState(_load);
  }

  /// Affiche un message temporaire en bas de l'écran.
  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      body: FutureBuilder<Map<Discipline, TestResult>>(
        future: _results,
        builder: (context, snapshot) {
          // Tant que les résultats ne sont pas chargés, `results` est null :
          // l'en-tête s'affiche sans compteur et la liste montre un spinner.
          final results = snapshot.data;
          return Column(
            children: [
              // 1. En-tête en dégradé : salutation, actions, résumé.
              _buildHeader(auth, results),

              // 2. Liste des disciplines (ou spinner de chargement).
              Expanded(
                child: results == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildList(results),
              ),
            ],
          );
        },
      ),
    );
  }

  /// En-tête : « Bonjour Prénom », boutons profil / déconnexion et, quand les
  /// résultats sont connus, deux compteurs (passés, réussis).
  Widget _buildHeader(AuthState auth, Map<Discipline, TestResult>? results) {
    // Le dégradé est répété derrière la zone de la barre d'état (SafeArea)
    // pour que la couleur monte jusqu'en haut de l'écran sur téléphone.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: GradientHeader(
          title: 'Bonjour ${auth.user!.firstName}',
          subtitle: 'Choisissez une évaluation',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('go-profile'),
                tooltip: 'Mon profil',
                color: Colors.white,
                icon: const Icon(Icons.person_rounded),
                onPressed: _openProfile,
              ),
              IconButton(
                tooltip: 'Se déconnecter',
                color: Colors.white,
                icon: const Icon(Icons.logout_rounded),
                onPressed: auth.logout,
              ),
            ],
          ),
          child: results == null ? null : _buildSummary(results),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Deux pastilles de résumé : nombre de tests passés et nombre réussis.
  Widget _buildSummary(Map<Discipline, TestResult> results) {
    // On parcourt les résultats et on compte ceux marqués « réussi ».
    var passedCount = 0;
    for (final result in results.values) {
      if (result.passed) passedCount++;
    }
    final takenCount = results.length;
    final totalCount = Discipline.values.length;

    // Wrap : si l'écran est trop étroit, la seconde pastille passe à la ligne
    // au lieu de déborder.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SummaryPill(
          icon: Icons.task_alt_rounded,
          label: '$takenCount / $totalCount tests passés',
        ),
        _SummaryPill(
          icon: Icons.emoji_events_rounded,
          label: '$passedCount réussi${passedCount > 1 ? 's' : ''}',
        ),
      ],
    );
  }

  /// Liste centrée (largeur maximale 640 px) des cartes de discipline.
  Widget _buildList(Map<Discipline, TestResult> results) {
    // Une carte par discipline, dans l'ordre de l'énumération, avec une
    // apparition en cascade (délai croissant de 60 ms par carte).
    final cards = <Widget>[];
    for (var i = 0; i < Discipline.values.length; i++) {
      final d = Discipline.values[i];
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              _DisciplineCard(
                    discipline: d,
                    result: results[d],
                    onStart: _starting ? null : () => _start(d),
                  )
                  .animate(delay: (60 * i).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const SectionTitle(
              title: 'Mes évaluations',
              subtitle: 'Une seule tentative par discipline',
            ),
            const SizedBox(height: 16),
            ...cards,
          ],
        ),
      ),
    );
  }
}

/// Petite pastille translucide (icône + texte) posée sur le dégradé.
class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une discipline sur l'accueil.
///
/// Deux états :
/// - test non passé : avatar, nom, mention « Pas encore passé » et bouton
///   « Passer le test » (clé `start-<code>` utilisée par les tests) ;
/// - test passé : avatar, nom, score, date, badge Réussi / Échoué et une
///   barre de progression colorée à hauteur du pourcentage.
class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.discipline,
    required this.result,
    required this.onStart,
  });

  final Discipline discipline;

  /// Résultat déjà enregistré, ou null si le test n'a pas été passé.
  final TestResult? result;

  /// Action du bouton « Passer le test » ; null = bouton désactivé (un autre
  /// test est déjà en cours de lancement).
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final color = AppColors.forDiscipline(discipline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Ligne principale : avatar, nom + sous-titre, badge éventuel.
            Row(
              children: [
                DisciplineAvatar(discipline: discipline, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discipline.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (r == null)
                        const Text(
                          'Pas encore passé',
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        Text(
                          'Score : ${r.score} / ${r.total} (${r.percent.round()} %)',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (r != null) ...[
                  const SizedBox(width: 8),
                  StatusChip.passFail(r.passed),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // 2. Pied de carte : bouton de lancement, ou barre de score.
            if (r == null)
              _buildStartRow(color)
            else
              _buildScoreBar(context, r, color),
          ],
        ),
      ),
    );
  }

  /// Pied de carte quand le test n'est pas passé : rappel « chrono » à gauche
  /// et bouton « Passer le test » à droite. Un Wrap plutôt qu'un Row : sur
  /// un écran très étroit, le bouton passe simplement à la ligne.
  Widget _buildStartRow(Color color) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
            SizedBox(width: 4),
            Text(
              'Chrono par question',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
        FilledButton.icon(
          key: Key('start-${discipline.code}'),
          onPressed: onStart,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: const Text('Passer le test'),
        ),
      ],
    );
  }

  /// Pied de carte quand le test est passé : barre de pourcentage + date.
  Widget _buildScoreBar(BuildContext context, TestResult r, Color color) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (r.percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Passé le ${dateFormat.format(r.takenAt)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}
