// Sélection de l'implémentation SQLite selon la plateforme :
//  - web      -> sqflite_common_ffi_web (sqlite compilé en WebAssembly)
//  - mobile   -> sqflite (SQLite natif Android/iOS)
//  - desktop  -> sqflite_common_ffi
import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart'
    as impl;
import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory platformDatabaseFactory() => impl.platformDatabaseFactory();
