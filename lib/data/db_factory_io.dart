/// Implémentation « non web » de [platformDatabaseFactory] : mobile et bureau.
///
/// Ce fichier n'est compilé que lorsque `dart:io` est disponible (voir
/// l'import conditionnel dans `db_factory.dart`).
library;

import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Choisit le moteur SQLite :
///  - Android / iOS : le plugin natif `sqflite` ;
///  - Windows / macOS / Linux : SQLite chargé via FFI. `sqfliteFfiInit()`
///    doit être appelé une fois avant la première ouverture.
DatabaseFactory platformDatabaseFactory() {
  // 1. Sur mobile, le plugin natif est le plus simple et le plus rapide.
  if (Platform.isAndroid || Platform.isIOS) {
    return sqflite.databaseFactory;
  }
  // 2. Sur bureau, on initialise FFI puis on renvoie sa fabrique.
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
