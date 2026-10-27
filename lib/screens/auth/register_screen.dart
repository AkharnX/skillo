/// Écran d'inscription d'un candidat (US1).
///
/// Le logo de l'application est dans la barre du haut, puis une carte
/// blanche centrée (largeur maximale 440 px) contient le formulaire en deux
/// parties : "Identité" (nom, prénom, âge, adresse) et "Compte" (email,
/// motivation, mot de passe). Le formulaire est volontairement compact (nom
/// et prénom côte à côte) pour tenir sur un écran sans défiler. Après une
/// inscription réussie, l'utilisateur est connecté automatiquement et le
/// routeur affiche l'accueil candidat.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/motivation.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';

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
    return Scaffold(
      appBar: AppBar(
        // Logo de l'application à gauche du titre.
        title: const Row(
          children: [
            _LogoSquare(),
            SizedBox(width: 12),
            // Expanded + ellipsis : le titre ne déborde jamais, même sur un
            // écran étroit.
            Expanded(
              child: Text('Créer un compte', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            // Carte du formulaire, en simple fondu (pas de glissement : le
            // formulaire doit rester à sa place dès la première image pour
            // que le champ mot de passe ne provoque pas de défilement).
            child: _buildFormCard().animate().fadeIn(duration: 300.ms),
          ),
        ),
      ),
    );
  }

  /// Construit la carte blanche avec le formulaire complet.
  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Partie 1 : identité ----
              const _GroupLabel(icon: Icons.badge_outlined, text: 'Identité'),
              const SizedBox(height: 8),
              // Nom et prénom côte à côte pour raccourcir le formulaire.
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
              TextFormField(
                key: const Key('register-age'),
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Âge',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: _validateAge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('register-address'),
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse postale',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 20),

              // ---- Partie 2 : compte ----
              const _GroupLabel(
                icon: Icons.account_circle_outlined,
                text: 'Compte',
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),

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
    );
  }
}

/// Petit carré arrondi violet avec l'icône « école » : le logo de
/// l'application, affiché dans la barre du haut.
class _LogoSquare extends StatelessWidget {
  const _LogoSquare();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school_rounded, size: 22, color: Colors.white),
    );
  }
}

/// Libellé de groupe de champs ("Identité", "Compte") : icône + texte en
/// violet, pour structurer visuellement le long formulaire.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.3,
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
