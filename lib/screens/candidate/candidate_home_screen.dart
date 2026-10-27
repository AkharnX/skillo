/// Accueil candidat : les trois disciplines, à passer ou déjà passées.
///
/// En haut, un en-tête encre ([InkHeader]) salue le candidat et résume ses
/// tests dans deux tuiles (combien passés, combien réussis). En dessous, une
/// carte par discipline : la pastille de la discipline, son nom en Syne, une
/// ligne en chasse fixe (nombre de questions et temps par question, ou le
/// score obtenu) et, à droite, le bouton « Passer le test » ou le badge
/// Réussi / Échoué avec la date. Un test ne peut être passé qu'une seule
/// fois : le résultat est créé en base *avant* d'ouvrir l'écran de test, ce
/// qui rend l'application résistante à un rechargement.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../data/result_repository.dart';
import '../../models/discipline.dart';
import '../../models/question.dart';
import '../../models/test_result.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';
import 'profile_screen.dart';
import 'test_screen.dart';

/// Écran d'accueil du candidat connecté.
class CandidateHomeScreen extends StatefulWidget {
  const CandidateHomeScreen({super.key});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

/// Résumé d'une discipline pour la ligne d'information de sa carte : nombre
/// de questions et fourchette de temps par question.
class _DisciplineInfo {
  const _DisciplineInfo({
    required this.count,
    required this.minTimeS,
    required this.maxTimeS,
  });

  /// Nombre de questions disponibles en base pour la discipline.
  final int count;

  /// Plus petit et plus grand temps limite (en secondes) parmi ces questions.
  final int minTimeS;
  final int maxTimeS;

  /// Calcule le résumé à partir de la liste des questions.
  factory _DisciplineInfo.fromQuestions(List<Question> questions) {
    // Boucle sur les questions : on garde le plus petit et le plus grand
    // temps limite rencontrés. Pour une liste vide, les deux valent 0.
    var minTime = 0;
    var maxTime = 0;
    for (final q in questions) {
      if (minTime == 0 || q.timeLimitS < minTime) minTime = q.timeLimitS;
      if (q.timeLimitS > maxTime) maxTime = q.timeLimitS;
    }
    return _DisciplineInfo(
      count: questions.length,
      minTimeS: minTime,
      maxTimeS: maxTime,
    );
  }

  /// Texte affiché : « 8 questions · 20-30 s / question » (ou une seule
  /// valeur si toutes les questions ont le même temps).
  String get line {
    if (count == 0) return 'Aucune question disponible';
    final time = minTimeS == maxTimeS ? '$minTimeS' : '$minTimeS-$maxTimeS';
    return '$count question${count > 1 ? 's' : ''} · $time s / question';
  }
}

/// Tout ce que l'écran lit en base à l'ouverture : les résultats du candidat
/// (indexés par discipline) et le résumé des questions de chaque discipline.
class _HomeData {
  const _HomeData({required this.results, required this.infos});

  /// Résultats du candidat ; une discipline absente = test pas encore passé.
  final Map<Discipline, TestResult> results;

  /// Résumé (nombre de questions, temps) par discipline.
  final Map<Discipline, _DisciplineInfo> infos;
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  /// Données de l'écran, lues en base et affichées par un [FutureBuilder].
  late Future<_HomeData> _data;

  /// Verrou anti double-tap : vrai entre le clic sur « Passer le test » et
  /// le retour de l'écran de test. Tant qu'il est vrai, les boutons sont
  /// désactivés et [_start] refuse de relancer un test.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// (Re)lance la lecture des données en base.
  void _load() {
    _data = _loadData();
  }

  /// Lit les résultats du candidat puis le résumé des questions de chaque
  /// discipline.
  Future<_HomeData> _loadData() async {
    // 1. On récupère l'utilisateur et les dépôts avant toute attente.
    final user = context.read<AuthState>().user!;
    final resultRepository = context.read<ResultRepository>();
    final questionRepository = context.read<QuestionRepository>();

    // 2. Résultats du candidat, rangés par discipline.
    final results = _indexByDiscipline(await resultRepository.forUser(user.id));

    // 3. Boucle sur les disciplines : pour chacune on charge ses questions et
    //    on en tire le résumé. À la fin, `infos` a une entrée par discipline.
    final infos = <Discipline, _DisciplineInfo>{};
    for (final d in Discipline.values) {
      final questions = await questionRepository.forDiscipline(d);
      infos[d] = _DisciplineInfo.fromQuestions(questions);
    }
    return _HomeData(results: results, infos: infos);
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
      body: FutureBuilder<_HomeData>(
        future: _data,
        builder: (context, snapshot) {
          // Tant que les données ne sont pas chargées, `data` est null :
          // l'en-tête s'affiche sans compteur et la liste montre un spinner.
          final data = snapshot.data;
          return Column(
            children: [
              // 1. En-tête encre : salutation, actions, résumé.
              _buildHeader(auth, data?.results),

              // 2. Liste des disciplines (ou spinner de chargement).
              Expanded(
                child: data == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildList(data),
              ),
            ],
          );
        },
      ),
    );
  }

  /// En-tête : « Bonjour Prénom », boutons profil / déconnexion et, quand les
  /// résultats sont connus, deux tuiles (tests passés, réussis).
  Widget _buildHeader(AuthState auth, Map<Discipline, TestResult>? results) {
    // La couleur encre est répétée derrière la zone de la barre d'état
    // (SafeArea) pour monter jusqu'en haut de l'écran sur téléphone.
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: InkHeader(
          eyebrow: 'Espace candidat',
          title: 'Bonjour ${auth.user!.firstName}',
          subtitle: 'Une seule tentative par discipline',
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

  /// Deux tuiles de résumé : nombre de tests passés et nombre réussis.
  Widget _buildSummary(Map<Discipline, TestResult> results) {
    // On parcourt les résultats et on compte ceux marqués « réussi ».
    var passedCount = 0;
    for (final result in results.values) {
      if (result.passed) passedCount++;
    }
    final takenCount = results.length;
    final totalCount = Discipline.values.length;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Tests passés',
            value: '$takenCount / $totalCount',
            icon: Icons.task_alt_rounded,
            onDark: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            label: 'Réussis',
            value: '$passedCount',
            icon: Icons.emoji_events_rounded,
            onDark: true,
          ),
        ),
      ],
    );
  }

  /// Liste centrée (largeur maximale 640 px) des cartes de discipline.
  Widget _buildList(_HomeData data) {
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
                    result: data.results[d],
                    info: data.infos[d],
                    onStart: _starting ? null : () => _start(d),
                  )
                  .animate(delay: (60 * i).ms)
                  .fadeIn(duration: 280.ms)
                  .slideY(begin: 0.04, end: 0),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const SectionTitle(title: 'Mes évaluations'),
            const SizedBox(height: 14),
            ...cards,
          ],
        ),
      ),
    );
  }
}

/// Carte d'une discipline sur l'accueil.
///
/// Deux états :
/// - test non passé : avatar, nom, ligne « 8 questions · 20-30 s / question »
///   et bouton « Passer le test » (clé `start-<code>` utilisée par les tests) ;
/// - test passé : avatar, nom, ligne « Score : 3 / 4 (75 %) », badge
///   Réussi / Échoué, date, et une fine barre de progression colorée à hauteur
///   du pourcentage en bas de la carte.
///
/// Sur un écran étroit (moins de 440 px pour la carte), le bouton ou le badge
/// passe sous le texte au lieu de rester à droite.
class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({
    required this.discipline,
    required this.result,
    required this.info,
    required this.onStart,
  });

  final Discipline discipline;

  /// Résultat déjà enregistré, ou null si le test n'a pas été passé.
  final TestResult? result;

  /// Résumé des questions (nombre, temps), ou null s'il n'est pas connu.
  final _DisciplineInfo? info;

  /// Action du bouton « Passer le test » ; null = bouton désactivé (un autre
  /// test est déjà en cours de lancement).
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final color = AppColors.forDiscipline(discipline);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Carte étroite : l'action passe sous le texte.
        final compact = constraints.maxWidth < 440;
        return Card(
          // Le bord arrondi coupe la barre de progression collée en bas.
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Ligne principale : avatar, nom + ligne d'info et,
                    //    si la carte est assez large, l'action à droite.
                    Row(
                      children: [
                        DisciplineAvatar(discipline: discipline, size: 52),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTitleColumn(r)),
                        if (!compact) ...[
                          const SizedBox(width: 12),
                          _buildTrailing(r, compact: false),
                        ],
                      ],
                    ),
                    // 2. Carte étroite : l'action sur sa propre ligne.
                    if (compact) ...[
                      const SizedBox(height: 14),
                      _buildTrailing(r, compact: true),
                    ],
                  ],
                ),
              ),
              // 3. Test passé : fine barre colorée à hauteur du pourcentage.
              if (r != null)
                LinearProgressIndicator(
                  value: (r.percent / 100).clamp(0.0, 1.0),
                  minHeight: 4,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Nom de la discipline en Syne et ligne d'information en chasse fixe :
  /// le score si le test est passé, sinon le nombre de questions et le temps.
  Widget _buildTitleColumn(TestResult? r) {
    final String line;
    if (r != null) {
      line = 'Score : ${r.score} / ${r.total} (${r.percent.round()} %)';
    } else {
      line = info?.line ?? '';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(discipline.label, style: AppText.display(20)),
        const SizedBox(height: 5),
        Text(
          line,
          style: AppText.mono(
            13,
            color: AppColors.muted,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Côté action : le bouton « Passer le test » (encre) si le test n'est pas
  /// passé, sinon le badge Réussi / Échoué et la date.
  Widget _buildTrailing(TestResult? r, {required bool compact}) {
    if (r == null) {
      return FilledButton(
        key: Key('start-${discipline.code}'),
        onPressed: onStart,
        style: FilledButton.styleFrom(
          // En mode compact le bouton prend toute la largeur ; sinon il reste
          // à sa taille naturelle, un peu moins haut que le bouton standard.
          minimumSize: compact ? const Size.fromHeight(48) : const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: const Text('Passer le test'),
      );
    }

    final date = DateFormat('dd/MM/yyyy').format(r.takenAt);
    final dateText = Text(
      'Passé le $date',
      style: AppText.mono(12, color: AppColors.muted, weight: FontWeight.w500),
    );
    if (compact) {
      return Row(
        children: [StatusChip.passFail(r.passed), const Spacer(), dateText],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        StatusChip.passFail(r.passed),
        const SizedBox(height: 6),
        dateText,
      ],
    );
  }
}
