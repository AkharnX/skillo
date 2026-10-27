/// Profil candidat (US3) : identité, scores par discipline, modification de
/// l'adresse et de la motivation.
///
/// En haut, un en-tête encre ([InkHeader]) avec un bouton retour, le nom
/// complet, l'email, les initiales dans un carré et deux tuiles (âge, tests
/// réussis). En dessous : une carte « Mes informations » avec le formulaire
/// d'adresse et de motivation, puis une carte « Mes résultats » (une ligne
/// par discipline, passée ou non). Nom, prénom, email et âge ne sont pas
/// modifiables (cahier des charges).
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../data/user_repository.dart';
import '../../models/discipline.dart';
import '../../models/motivation.dart';
import '../../models/test_result.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';

/// Écran de profil du candidat connecté.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Clé du formulaire d'informations.
  final _formKey = GlobalKey<FormState>();

  /// Contrôleur du champ adresse, pré-rempli avec l'adresse actuelle.
  late final TextEditingController _address;

  /// Motivation sélectionnée (pré-remplie avec celle du profil).
  Motivation? _motivation;

  /// Résultats du candidat, lus en base une fois à l'ouverture.
  late Future<List<TestResult>> _results;

  /// Vrai pendant l'enregistrement : désactive le bouton.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // On initialise le formulaire avec les valeurs actuelles du profil et on
    // lance la lecture des résultats.
    final user = context.read<AuthState>().user!;
    _address = TextEditingController(text: user.address);
    _motivation = user.motivation;
    _results = context.read<ResultRepository>().forUser(user.id);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  /// Valide puis enregistre l'adresse et la motivation.
  Future<void> _save() async {
    // 1. Validation du formulaire.
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    // 2. Mise à jour en base.
    final auth = context.read<AuthState>();
    await context.read<UserRepository>().updateProfile(
      auth.user!.id,
      address: _address.text,
      motivation: _motivation,
    );

    // 3. On relit l'utilisateur pour que toute l'application voie la
    //    nouvelle valeur (AuthState notifie ses écouteurs).
    await auth.refresh();
    if (!mounted) return;

    // 4. Retour visuel.
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
  }

  /// Transforme la liste des résultats en map « discipline → résultat ».
  ///
  /// On parcourt chaque résultat et on le range sous sa discipline ; à la fin
  /// la map contient au plus un résultat par discipline.
  Map<Discipline, TestResult> _indexByDiscipline(List<TestResult> list) {
    final byDiscipline = <Discipline, TestResult>{};
    for (final result in list) {
      byDiscipline[result.discipline] = result;
    }
    return byDiscipline;
  }

  /// Compte les tests réussis parmi les résultats.
  int _countPassed(Map<Discipline, TestResult> byDiscipline) {
    // Boucle sur les résultats : on accumule le nombre de ceux marqués
    // « réussi ».
    var passed = 0;
    for (final result in byDiscipline.values) {
      if (result.passed) passed++;
    }
    return passed;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    return Scaffold(
      body: FutureBuilder<List<TestResult>>(
        future: _results,
        builder: (context, snapshot) {
          // Tant que la base n'a pas répondu, la liste est vide : les lignes
          // affichent « Non passé » et la tuile « Réussis » vaut 0.
          final byDiscipline = _indexByDiscipline(
            snapshot.data ?? const <TestResult>[],
          );
          return Column(
            children: [
              // 1. En-tête encre avec bouton retour et identité.
              _buildHeader(user, _countPassed(byDiscipline)),

              // 2. Contenu défilable, centré sur grand écran. Un
              //    SingleChildScrollView (et non une ListView paresseuse) :
              //    les deux cartes sont toujours construites, le formulaire
              //    reste accessible même s'il dépasse de l'écran.
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle(
                            title: 'Mes informations',
                            subtitle: 'Adresse et motivation modifiables',
                          ),
                          const SizedBox(height: 12),
                          _buildFormCard()
                              .animate()
                              .fadeIn(duration: 280.ms)
                              .slideY(begin: 0.04, end: 0),
                          const SizedBox(height: 24),
                          const SectionTitle(
                            title: 'Mes résultats',
                            subtitle: 'Un test par discipline',
                          ),
                          const SizedBox(height: 12),
                          _buildResultsCard(byDiscipline)
                              .animate(delay: 80.ms)
                              .fadeIn(duration: 280.ms)
                              .slideY(begin: 0.04, end: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// En-tête : la couleur encre est posée sur un conteneur englobant pour
  /// couvrir aussi la barre d'état et la ligne « retour », puis [InkHeader]
  /// affiche l'étiquette, le nom, l'email, les initiales et deux tuiles.
  Widget _buildHeader(AppUser user, int passedCount) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Ligne « retour », en blanc sur l'encre, alignée sur la même
            // colonne de 640 px que le reste de l'écran.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(10, 4, 4, 0),
                  child: Row(children: [BackButton(color: Colors.white)]),
                ),
              ),
            ),
            InkHeader(
              maxContentWidth: 640,
              eyebrow: 'Mon profil',
              title: user.fullName,
              subtitle: user.email,
              trailing: _InitialsAvatar(fullName: user.fullName),
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Âge',
                      value: '${user.age}',
                      icon: Icons.cake_outlined,
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
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  /// Carte des résultats : une ligne par discipline.
  Widget _buildResultsCard(Map<Discipline, TestResult> byDiscipline) {
    // Une ligne par discipline, séparées par un trait fin. On parcourt les
    // disciplines dans l'ordre et on accumule ligne + séparateur.
    final rows = <Widget>[];
    for (var i = 0; i < Discipline.values.length; i++) {
      final d = Discipline.values[i];
      if (i > 0) rows.add(const Divider(height: 1, indent: 16));
      rows.add(_ResultRow(discipline: d, result: byDiscipline[d]));
    }
    return Card(child: Column(children: rows));
  }

  /// Carte du formulaire : adresse + motivation + bouton Enregistrer.
  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('profile-address'),
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse postale',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Motivation>(
                key: const Key('profile-motivation'),
                initialValue: _motivation,
                // isExpanded : le champ prend toute la largeur disponible et
                // le libellé choisi ne déborde jamais sur un écran étroit.
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Motivation',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                // Un élément de menu par motivation possible.
                items: [
                  for (final m in Motivation.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _motivation = m),
                validator: (m) =>
                    m == null ? 'Choisissez une motivation' : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('profile-save'),
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carré encre relevée avec les initiales du candidat en jaune signal
/// (ex. « JD »).
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.fullName});

  final String fullName;

  /// Calcule les initiales : première lettre de chaque mot du nom complet,
  /// deux lettres au maximum.
  String _initials() {
    // On parcourt les mots du nom et on accumule leur première lettre.
    final words = fullName.trim().split(' ');
    var initials = '';
    for (final word in words) {
      if (word.isEmpty || initials.length >= 2) continue;
      initials += word[0].toUpperCase();
    }
    return initials;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inkRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _initials(),
        style: AppText.display(18, color: AppColors.accent),
      ),
    );
  }
}

/// Ligne de résultat d'une discipline : avatar, nom, date, score et badge.
///
/// Si le test n'a pas été passé, on affiche « Non passé » à droite et
/// « En attente » sous le nom.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.discipline, required this.result});

  final Discipline discipline;
  final TestResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          DisciplineAvatar(discipline: discipline, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(discipline.label, style: AppText.display(16)),
                const SizedBox(height: 3),
                Text(
                  r == null
                      ? 'En attente'
                      : 'Passé le ${dateFormat.format(r.takenAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Côté droit : score en Space Grotesk + badge, ou « Non passé ».
          if (r == null)
            const Text(
              'Non passé',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${r.score} / ${r.total} (${r.percent.round()} %)',
                  style: AppText.number(15, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                StatusChip.passFail(r.passed),
              ],
            ),
        ],
      ),
    );
  }
}
