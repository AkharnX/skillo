/// Sélection de l'implémentation SQLite selon la plateforme.
///
/// Le package `sqflite_common` définit une interface commune (`Database`,
/// `DatabaseFactory`), mais le « moteur » réel change selon la cible :
///  - web      -> `sqflite_common_ffi_web` (SQLite compilé en WebAssembly) ;
///  - mobile   -> `sqflite` (SQLite natif Android/iOS) ;
///  - desktop  -> `sqflite_common_ffi` (SQLite via FFI).
///
/// L'import conditionnel ci-dessous choisit le bon fichier **à la
/// compilation** : si la bibliothèque `dart:js_interop` existe (donc on
/// compile pour le web) on prend `db_factory_web.dart`, sinon
/// `db_factory_io.dart`. Les deux fichiers exposent la même fonction.
library;

import 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart'
    as impl;

import 'package:sqflite_common/sqlite_api.dart';

/// Retourne la fabrique de bases de données adaptée à la plateforme courante.
/// Le reste de l'application n'a pas à savoir sur quelle plateforme il tourne.
DatabaseFactory platformDatabaseFactory() => impl.platformDatabaseFactory();
