import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/motivation.dart';
import '../../state/auth_state.dart';

/// Inscription d'un candidat (US1).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  Motivation? _motivation;
  String? _error;
  bool _busy = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_lastName, _firstName, _email, _age, _address, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AuthState>().register(
          lastName: _lastName.text,
          firstName: _firstName.text,
          email: _email.text,
          password: _password.text,
          age: int.parse(_age.text.trim()),
          address: _address.text,
          motivation: _motivation!,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    // Succès : l'AuthState notifie et le routeur affiche l'accueil candidat.
    if (error == null && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('register-last-name'),
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('register-first-name'),
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('register-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final req = _required(v);
                      if (req != null) return req;
                      return _emailRegex.hasMatch(v!.trim()) ? null : 'Email invalide';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('register-age'),
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Âge'),
                    validator: (v) {
                      final req = _required(v);
                      if (req != null) return req;
                      final n = int.tryParse(v!.trim());
                      return (n == null || n < 10 || n > 120) ? 'Âge invalide' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('register-address'),
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Adresse postale'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Motivation>(
                    key: const Key('register-motivation'),
                    initialValue: _motivation,
                    decoration: const InputDecoration(labelText: 'Motivation'),
                    items: [
                      for (final m in Motivation.values)
                        DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged: (m) => setState(() => _motivation = m),
                    validator: (m) => m == null ? 'Choisissez une motivation' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('register-password'),
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe'),
                    validator: _required,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('register-submit'),
                    onPressed: _busy ? null : _submit,
                    child: const Text("S'inscrire"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
