/// Écran de connexion (US4) : un même formulaire pour les candidats et
/// l'administrateur, le rôle étant lu en base après authentification.
///
/// Mise en page : un bloc "logo + nom de l'application" au-dessus d'une carte
/// blanche centrée (largeur maximale 440 px) qui contient le formulaire.
/// Sur téléphone la carte occupe toute la largeur, sur grand écran elle
/// reste centrée et étroite pour rester lisible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import 'register_screen.dart';

/// Écran de connexion.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Clé du formulaire : permet de lancer la validation de tous les champs.
  final _formKey = GlobalKey<FormState>();

  /// Contrôleur du champ email.
  final _email = TextEditingController();

  /// Contrôleur du champ mot de passe.
  final _password = TextEditingController();

  /// Message d'erreur renvoyé par [AuthState.login], ou null si tout va bien.
  String? _error;

  /// Vrai pendant l'appel à la base : désactive le bouton pour éviter un
  /// double envoi.
  bool _busy = false;

  /// Vrai quand le mot de passe est masqué (œil barré).
  bool _obscure = true;

  @override
  void dispose() {
    // On libère les contrôleurs de texte pour ne pas fuir de mémoire.
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Valide le formulaire puis tente la connexion.
  ///
  /// En cas d'échec, le message est affiché sous les champs. En cas de
  /// succès, [AuthState] notifie ses écouteurs et le routeur d'accueil
  /// remplace cet écran : il n'y a rien à naviguer ici.
  Future<void> _submit() async {
    // 1. Validation des champs (obligatoires) : on s'arrête si invalide.
    if (!_formKey.currentState!.validate()) return;

    // 2. On passe en mode "occupé" et on efface l'ancienne erreur.
    setState(() {
      _busy = true;
      _error = null;
    });

    // 3. Appel à l'état d'authentification (lecture en base).
    final error = await context.read<AuthState>().login(
      _email.text,
      _password.text,
    );

    // 4. Si l'écran a été retiré pendant l'attente, on ne touche plus à rien.
    if (!mounted) return;

    // 5. On affiche l'éventuelle erreur et on réactive le bouton.
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  /// Ouvre l'écran d'inscription par-dessus celui-ci.
  void _goToRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Bloc logo + nom + sous-titre, apparition en fondu.
                  const _BrandBlock()
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),

                  // 2. Carte blanche contenant le formulaire, avec un léger
                  //    décalage d'apparition pour un effet "en cascade".
                  _buildFormCard()
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 12),

                  // 3. Lien vers l'inscription, sous la carte.
                  TextButton(
                    key: const Key('login-go-register'),
                    onPressed: _goToRegister,
                    child: const Text('Créer un compte candidat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construit la carte blanche avec le formulaire de connexion.
  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre de la carte.
              const Text(
                'Connexion',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Entrez vos identifiants pour continuer.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // Champ email.
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 12),

              // Champ mot de passe, avec un bouton pour afficher/masquer.
              TextFormField(
                key: const Key('login-password'),
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
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                // Entrée au clavier = même action que le bouton.
                onFieldSubmitted: (_) => _submit(),
              ),

              // Message d'erreur (identifiants incorrects), seulement s'il y
              // en a un.
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),

              // Bouton principal : désactivé pendant l'appel à la base.
              FilledButton(
                key: const Key('login-submit'),
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
                    : const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloc d'identité visuelle : icône dans un carré arrondi violet, nom de
/// l'application et sous-titre. Réutilisé en haut de la connexion.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Carré arrondi de la couleur principale avec l'icône "école".
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Skillo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "Plateforme d'évaluation",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ],
    );
  }
}

/// Bandeau d'erreur rouge pâle avec une icône, affiché sous les champs.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  /// Texte à afficher (ex. "Email ou mot de passe incorrect").
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
