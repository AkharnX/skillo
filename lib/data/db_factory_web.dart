/// Implémentation « web » de [platformDatabaseFactory].
///
/// Dans le navigateur il n'y a pas de SQLite natif : on utilise une version
/// compilée en WebAssembly (fichiers `sqlite3.wasm` et `sqflite_sw.js` dans
/// `web/`). Les données sont conservées dans le stockage du navigateur.
library;

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Fabrique SQLite pour le web (WebAssembly).
DatabaseFactory platformDatabaseFactory() => databaseFactoryFfiWeb;
