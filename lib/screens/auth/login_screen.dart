/// Écran de connexion (US4) : un même formulaire pour les candidats et
/// l'administrateur, le rôle étant lu en base après authentification.
///
/// Mise en page « encre et signal » :
/// - sur grand écran (largeur ≥ 840 px), deux moitiés côte à côte : à gauche
///   un panneau encre (logo, accroche en Syne, faux terminal qui liste les
///   trois disciplines), à droite la carte blanche du formulaire ;
/// - sur téléphone, un bandeau encre compact (logo + une ligne d'accroche)
///   au-dessus du formulaire, qui défile si le clavier prend de la place.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/discipline.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/widgets.dart';
import 'register_screen.dart';

/// Largeur à partir de laquelle on passe à la mise en page en deux moitiés.
const double _kSplitWidth = 840;

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
    // LayoutBuilder : on lit la largeur disponible pour choisir entre la mise
    // en page en deux moitiés (bureau) et la mise en page empilée (mobile).
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kSplitWidth) return _buildWide();
          return _buildNarrow();
        },
      ),
    );
  }

  /// Grand écran : panneau encre à gauche, formulaire centré à droite.
  Widget _buildWide() {
    return Row(
      children: [
        const Expanded(child: _InkPanel(compact: false)),
        Expanded(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildFormColumn(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Téléphone : bandeau encre compact en haut, puis le formulaire qui
  /// défile en dessous.
  Widget _buildNarrow() {
    return Column(
      children: [
        // Le bandeau encre monte jusqu'en haut de l'écran (SafeArea à
        // l'intérieur de la couleur) : la barre d'état est sur fond encre.
        Container(
          color: AppColors.ink,
          child: const SafeArea(bottom: false, child: _InkPanel(compact: true)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildFormColumn(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Carte du formulaire suivie du lien vers l'inscription. Apparition en
  /// fondu + léger glissement, commune aux deux mises en page.
  Widget _buildFormColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFormCard()
            .animate()
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.04, end: 0),
        const SizedBox(height: 10),
        TextButton(
          key: const Key('login-go-register'),
          onPressed: _goToRegister,
          child: const Text('Créer un compte candidat'),
        ),
      ],
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
              // Titre de la carte en Syne, puis une ligne d'explication.
              Text('Connexion', style: AppText.display(26)),
              const SizedBox(height: 6),
              const Text(
                'Entrez vos identifiants pour continuer.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),

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

              // Bouton principal (encre) : désactivé pendant l'appel à la base.
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

/// Panneau encre de présentation.
///
/// Deux variantes :
/// - [compact] = false (bureau) : logo, grande accroche en Syne, phrase
///   d'explication et faux terminal listant les disciplines ;
/// - [compact] = true (mobile) : logo et une seule ligne d'accroche, pour
///   laisser la place au formulaire.
class _InkPanel extends StatelessWidget {
  const _InkPanel({required this.compact});

  /// Vrai pour la version courte affichée en haut sur téléphone.
  final bool compact;

  /// Description affichée dans le terminal pour chaque discipline : nombre
  /// de questions et fourchette de temps par question, tels que livrés dans
  /// `assets/questions/<code>.json`.
  static const Map<Discipline, String> _specs = {
    Discipline.java: '8 questions · 20-30 s/question',
    Discipline.algo: '8 questions · 15-30 s/question',
    Discipline.htmlCss: '8 questions · 15-30 s/question',
  };

  /// Lignes du faux terminal : la commande, une ligne colorée par discipline,
  /// puis la règle « une tentative » en jaune signal.
  List<TerminalLine> _terminalLines() {
    // On commence par la commande tapée, en blanc.
    final lines = <TerminalLine>[const TerminalLine(r'$ skillo test --list')];

    // Boucle sur les disciplines : on ajoute une ligne « code  description »
    // dans la couleur de la discipline. Le code est complété à 12 caractères
    // pour que les descriptions soient alignées (police à chasse fixe).
    for (final d in Discipline.values) {
      lines.add(
        TerminalLine(
          '${d.code.padRight(12)}${_specs[d]}',
          color: AppColors.forDiscipline(d),
        ),
      );
    }

    // Dernière ligne : la règle du jeu, en accent.
    lines.add(
      const TerminalLine(
        '✓ 1 tentative par discipline',
        color: AppColors.accent,
      ),
    );
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return _buildFull();
  }

  /// Version mobile : logo + une ligne d'accroche.
  Widget _buildCompact() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppWordmark(onDark: true, size: 34),
          const SizedBox(height: 14),
          Text(
            'Évaluez vos compétences en conditions réelles.',
            style: AppText.display(21, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Version bureau : contenu centré verticalement ; si la fenêtre est trop
  /// basse, le panneau défile au lieu de déborder.
  Widget _buildFull() {
    return Container(
      color: AppColors.ink,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppWordmark(onDark: true, size: 44),
                    const SizedBox(height: 44),
                    Text(
                      'Évaluez vos compétences en conditions réelles.',
                      style: AppText.display(36, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Trois disciplines, un chrono par question, une seule '
                      'tentative. Le résultat est affiché dès la dernière '
                      'réponse.',
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 15.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TerminalCard(lines: _terminalLines()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms);
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
