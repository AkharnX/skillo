/// Écran d'inscription d'un candidat (US1).
///
/// Mise en page « encre et signal » :
/// - sur grand écran (largeur ≥ 840 px), une colonne encre à gauche (logo,
///   bouton retour et la liste « Ce que vous allez faire ») et la carte du
///   formulaire centrée à droite ;
/// - sur téléphone, un bandeau encre très court (retour + logo) au-dessus du
///   formulaire. Il est volontairement court, et le formulaire compact (nom et
///   prénom côte à côte, âge et adresse côte à côte), pour que les champs
///   tiennent sur un écran sans défiler.
///
/// Après une inscription réussie, l'utilisateur est connecté automatiquement
/// et le routeur affiche l'accueil candidat.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/motivation.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';

/// Largeur à partir de laquelle on affiche la colonne encre à gauche.
const double _kSplitWidth = 840;

/// Écran d'inscription.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /// Clé du formulaire : permet de valider tous les champs d'un coup.
  final _formKey = GlobalKey<FormState>();

  /// Contrôleurs des champs texte, un par champ.
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();

  /// Motivation choisie dans la liste déroulante (null tant que rien n'est
  /// choisi : le validateur refuse alors l'envoi).
  Motivation? _motivation;

  /// Message d'erreur renvoyé par [AuthState.register] (ex. compte en
  /// double), ou null.
  String? _error;

  /// Vrai pendant l'enregistrement en base : désactive le bouton.
  bool _busy = false;

  /// Vrai quand le mot de passe est masqué.
  bool _obscure = true;

  /// Vérification simple d'un email : "quelque chose @ quelque chose . quelque
  /// chose", sans espace. Suffisant pour un projet d'école.
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    // On libère chaque contrôleur de texte : on parcourt la liste des six
    // contrôleurs et on appelle dispose() sur chacun.
    final controllers = [
      _lastName,
      _firstName,
      _email,
      _age,
      _address,
      _password,
    ];
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Validateur commun : le champ ne doit pas être vide.
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  /// Validateur de l'email : obligatoire puis au bon format.
  String? _validateEmail(String? v) {
    // 1. Champ obligatoire.
    final required = _required(v);
    if (required != null) return required;
    // 2. Format d'email.
    return _emailRegex.hasMatch(v!.trim()) ? null : 'Email invalide';
  }

  /// Validateur de l'âge : obligatoire, entier, entre 10 et 120 ans.
  String? _validateAge(String? v) {
    // 1. Champ obligatoire.
    final required = _required(v);
    if (required != null) return required;
    // 2. Nombre entier dans une plage raisonnable.
    final n = int.tryParse(v!.trim());
    return (n == null || n < 10 || n > 120) ? 'Âge invalide' : null;
  }

  /// Valide le formulaire puis crée le compte.
  Future<void> _submit() async {
    // 1. Validation de tous les champs : on s'arrête si l'un est invalide.
    if (!_formKey.currentState!.validate()) return;

    // 2. Mode "occupé", ancienne erreur effacée.
    setState(() {
      _busy = true;
      _error = null;
    });

    // 3. Création du compte (et connexion automatique) via AuthState.
    final error = await context.read<AuthState>().register(
      lastName: _lastName.text,
      firstName: _firstName.text,
      email: _email.text,
      password: _password.text,
      age: int.parse(_age.text.trim()),
      address: _address.text,
      motivation: _motivation!,
    );

    // 4. Écran retiré pendant l'attente : on ne touche plus à rien.
    if (!mounted) return;

    // 5. Affichage de l'éventuelle erreur et réactivation du bouton.
    setState(() {
      _busy = false;
      _error = error;
    });

    // 6. Succès : l'AuthState a notifié et le routeur affiche déjà l'accueil
    //    candidat ; on ferme simplement cet écran s'il est empilé.
    if (error == null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder : la largeur disponible décide de la mise en page.
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kSplitWidth) return _buildWide();
          return _buildNarrow();
        },
      ),
    );
  }

  /// Grand écran : colonne encre fixe à gauche, formulaire centré à droite.
  Widget _buildWide() {
    return Row(
      children: [
        const SizedBox(width: 380, child: _InkColumn()),
        Expanded(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildFormCard(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Téléphone : bandeau encre court (retour + logo), puis le formulaire.
  Widget _buildNarrow() {
    return Column(
      children: [
        Container(
          color: AppColors.ink,
          child: const SafeArea(bottom: false, child: _InkTopBar()),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildFormCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construit la carte blanche avec le formulaire complet.
  ///
  /// Simple fondu à l'apparition (pas de glissement) : le formulaire doit
  /// être à sa place dès la première image pour que les champs soient
  /// cliquables immédiatement.
  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête de la carte : étiquette en capitales + titre en Syne.
              Text('NOUVEAU CANDIDAT', style: AppText.label()),
              const SizedBox(height: 6),
              Text('Créer un compte', style: AppText.display(26)),
              const SizedBox(height: 18),

              // ---- Identité : nom et prénom côte à côte ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('register-last-name'),
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('register-first-name'),
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Âge (étroit) et adresse (large) côte à côte ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const Key('register-age'),
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Âge'),
                      validator: _validateAge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: const Key('register-address'),
                      controller: _address,
                      decoration: const InputDecoration(
                        labelText: 'Adresse postale',
                      ),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Compte : email, motivation, mot de passe ----
              TextFormField(
                key: const Key('register-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Motivation>(
                key: const Key('register-motivation'),
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
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('register-password'),
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _required,
              ),

              // Erreur renvoyée par la base (ex. compte déjà existant).
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 22),

              // Bouton d'envoi, désactivé pendant l'enregistrement.
              FilledButton(
                key: const Key('register-submit'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text("S'inscrire"),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 280.ms);
  }
}

/// Bandeau encre du haut sur téléphone : bouton retour et logo, sur une
/// seule ligne (une soixantaine de pixels) pour laisser toute la place au
/// formulaire.
class _InkTopBar extends StatelessWidget {
  const _InkTopBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(6, 6, 16, 10),
      child: Row(
        children: [
          BackButton(color: Colors.white),
          SizedBox(width: 4),
          AppWordmark(onDark: true, size: 30),
        ],
      ),
    );
  }
}

/// Colonne encre affichée à gauche sur grand écran : retour, logo, puis la
/// liste « Ce que vous allez faire » en trois étapes.
class _InkColumn extends StatelessWidget {
  const _InkColumn();

  /// Les trois étapes présentées au futur candidat : icône + texte.
  static const List<(IconData, String)> _steps = [
    (Icons.person_add_alt_1_rounded, 'Créer votre compte candidat'),
    (Icons.timer_rounded, 'Passer trois tests chronométrés'),
    (Icons.insights_rounded, 'Consulter vos scores immédiatement'),
  ];

  @override
  Widget build(BuildContext context) {
    // Boucle sur les étapes : on accumule une ligne (numéro, icône, texte)
    // par étape, séparées par un espace vertical.
    final stepRows = <Widget>[];
    for (var i = 0; i < _steps.length; i++) {
      final (icon, text) = _steps[i];
      stepRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _StepRow(number: i + 1, icon: icon, text: text),
        ),
      );
    }

    return Container(
      color: AppColors.ink,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Retour vers la connexion, aligné à gauche.
              const Align(
                alignment: Alignment.centerLeft,
                child: BackButton(color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: AppWordmark(onDark: true, size: 40),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'CE QUE VOUS ALLEZ FAIRE',
                  style: AppText.label(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stepRows,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Une étape de la colonne encre : carré encre relevée avec l'icône, puis
/// le texte en blanc.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.icon,
    required this.text,
  });

  /// Numéro de l'étape (1, 2, 3), affiché en petit sous l'icône.
  final int number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.inkRaised,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppColors.accent, size: 22),
        ),
        const SizedBox(width: 14),
        Text('0$number', style: AppText.mono(13, color: AppColors.inkMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bandeau d'erreur rouge pâle avec une icône, affiché sous les champs.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  /// Texte à afficher (ex. "Un compte existe déjà…").
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
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
