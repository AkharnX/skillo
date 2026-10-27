/// Point d'entrée de l'application Reine.
///
/// Ce fichier fait une seule chose : ouvrir la base de données locale puis
/// lancer l'application racine [ReineApp] en lui passant cette base. Toute la
/// logique (écrans, état, thème) vit dans `lib/app.dart` et ses imports.
library;

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';

/// Démarre l'application.
///
/// La fonction est `async` parce que l'ouverture de la base (création des
/// tables, insertion des questions de départ) est asynchrone et doit être
/// terminée avant d'afficher le premier écran : les écrans supposent que
/// la base est prête.
Future<void> main() async {
  // 1. On s'assure que le moteur Flutter est initialisé : obligatoire avant
  //    tout appel à une API de plateforme (ici l'accès au fichier SQLite).
  WidgetsFlutterBinding.ensureInitialized();

  // 2. On ouvre (ou crée) la base de données locale.
  final db = await openAppDatabase();

  // 3. On lance l'interface avec cette base partagée par tous les écrans.
  runApp(ReineApp(db: db));
}
