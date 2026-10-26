import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/result_repository.dart';
import '../../data/user_repository.dart';
import '../../models/discipline.dart';
import '../../models/motivation.dart';
import '../../models/test_result.dart';
import '../../state/auth_state.dart';

/// Profil candidat (US3) : scores par discipline, modification de l'adresse
/// et de la motivation.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  Motivation? _motivation;
  late Future<List<TestResult>> _results;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    await context.read<UserRepository>().updateProfile(
          auth.user!.id,
          address: _address.text,
          motivation: _motivation,
        );
    await auth.refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis à jour')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user!;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.fullName),
                subtitle: Text(user.email),
                trailing: Text('${user.age} ans'),
              ),
              const Divider(),
              Text('Mes résultats', style: Theme.of(context).textTheme.titleMedium),
              FutureBuilder<List<TestResult>>(
                future: _results,
                builder: (context, snapshot) {
                  final byDiscipline = {
                    for (final r in snapshot.data ?? const <TestResult>[]) r.discipline: r,
                  };
                  return Column(
                    children: [
                      for (final d in Discipline.values)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            byDiscipline[d] == null
                                ? Icons.radio_button_unchecked
                                : byDiscipline[d]!.passed
                                    ? Icons.check_circle
                                    : Icons.cancel,
                            color: byDiscipline[d] == null
                                ? null
                                : byDiscipline[d]!.passed
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          title: Text(d.label),
                          subtitle: byDiscipline[d] == null
                              ? null
                              : Text('Passé le ${dateFormat.format(byDiscipline[d]!.takenAt)}'),
                          trailing: Text(
                            byDiscipline[d] == null
                                ? 'Non passé'
                                : '${byDiscipline[d]!.score} / ${byDiscipline[d]!.total} (${byDiscipline[d]!.percent.round()} %)',
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(),
              Text('Mes informations', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('profile-address'),
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Adresse postale'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Motivation>(
                      key: const Key('profile-motivation'),
                      initialValue: _motivation,
                      decoration: const InputDecoration(labelText: 'Motivation'),
                      items: [
                        for (final m in Motivation.values)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (m) => setState(() => _motivation = m),
                      validator: (m) => m == null ? 'Choisissez une motivation' : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('profile-save'),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
