/// Profil candidat (US3) : identité, scores par discipline, modification de
/// l'adresse et de la motivation.
///
/// En haut, un en-tête en dégradé avec un bouton retour, le nom complet,
/// l'email et l'âge. En dessous : une carte « Mes informations » avec le
/// formulaire d'adresse et de motivation, puis une carte « Mes résultats »
/// (une ligne par discipline, passée ou non). Nom, prénom, email et âge ne
/// sont pas modifiables (cahier des charges).
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
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    return Scaffold(
      body: Column(
        children: [
          // 1. En-tête en dégradé avec bouton retour et identité.
          _buildHeader(user.fullName, user.email, user.age),

          // 2. Contenu défilable, centré sur grand écran. Un
          //    SingleChildScrollView (et non une ListView paresseuse) : les
          //    deux cartes sont toujours construites, le formulaire reste
          //    accessible même s'il dépasse de l'écran.
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
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 24),
                      const SectionTitle(
                        title: 'Mes résultats',
                        subtitle: 'Un test par discipline',
                      ),
                      const SizedBox(height: 12),
                      _buildResultsCard()
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// En-tête : le dégradé est posé sur un conteneur englobant pour couvrir
  /// aussi la barre d'état et la ligne « retour », puis [GradientHeader]
  /// affiche le nom, l'email et l'âge.
  Widget _buildHeader(String fullName, String email, int age) {
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
        child: Column(
          children: [
            // Ligne « retour » + titre de l'écran, en blanc sur le dégradé.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  const Text(
                    'Mon profil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            GradientHeader(
              title: fullName,
              subtitle: email,
              trailing: _InitialsAvatar(fullName: fullName),
              child: Row(
                children: [
                  _InfoPill(icon: Icons.cake_outlined, label: '$age ans'),
                  const SizedBox(width: 8),
                  const _InfoPill(
                    icon: Icons.school_outlined,
                    label: 'Candidat',
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
  Widget _buildResultsCard() {
    return Card(
      child: FutureBuilder<List<TestResult>>(
        future: _results,
        builder: (context, snapshot) {
          final byDiscipline = _indexByDiscipline(
            snapshot.data ?? const <TestResult>[],
          );

          // Une ligne par discipline, séparées par un trait fin. On parcourt
          // les disciplines dans l'ordre et on accumule ligne + séparateur.
          final rows = <Widget>[];
          for (var i = 0; i < Discipline.values.length; i++) {
            final d = Discipline.values[i];
            if (i > 0) rows.add(const Divider(height: 1, indent: 16));
            rows.add(_ResultRow(discipline: d, result: byDiscipline[d]));
          }
          return Column(children: rows);
        },
      ),
    );
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

/// Rond blanc translucide avec les initiales du candidat (ex. « JD »).
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
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        _initials(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Petite pastille translucide (icône + texte) posée sur le dégradé.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

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
                Text(
                  discipline.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
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
          // Côté droit : score + badge, ou simple mention « Non passé ».
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
