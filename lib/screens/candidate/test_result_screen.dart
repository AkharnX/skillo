import 'package:flutter/material.dart';

import '../../models/test_result.dart';

/// Écran de fin de test : score, pourcentage, réussite.
class TestResultScreen extends StatelessWidget {
  const TestResultScreen({super.key, required this.result});

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.passed ? Colors.green : Colors.red;
    return Scaffold(
      appBar: AppBar(title: Text('Résultat ${result.discipline.label}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(result.passed ? Icons.emoji_events : Icons.sentiment_dissatisfied, size: 96, color: color),
              const SizedBox(height: 16),
              Text('${result.score} / ${result.total}',
                  style: Theme.of(context).textTheme.displayMedium),
              Text('${result.percent.round()} %', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(result.passed ? 'Test réussi !' : 'Test échoué',
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text("Retour à l'accueil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
