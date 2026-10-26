import 'package:sqflite_common/sqlite_api.dart';

import '../models/motivation.dart';
import '../models/user.dart';
import 'password.dart';

/// Levée quand un compte existe déjà pour la même combinaison Nom + Email (US1).
class DuplicateAccountException implements Exception {
  @override
  String toString() => 'Un compte existe déjà avec ce nom et cet email.';
}

/// Accès à la table `users` : inscription, connexion, profil.
class UserRepository {
  UserRepository(this._db);

  final Database _db;

  /// Normalise l'email pour que « Jean@Dupont.FR » et « jean@dupont.fr »
  /// désignent le même compte.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<AppUser> register({
    required String lastName,
    required String firstName,
    required String email,
    required String password,
    required int age,
    required String address,
    required Motivation motivation,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final existing = await _db.query(
      'users',
      columns: ['id'],
      where: 'last_name = ? COLLATE NOCASE AND email = ? COLLATE NOCASE',
      whereArgs: [lastName.trim(), normalizedEmail],
    );
    if (existing.isNotEmpty) throw DuplicateAccountException();

    final id = await _db.insert('users', {
      'role': 'candidate',
      'last_name': lastName.trim(),
      'first_name': firstName.trim(),
      'email': normalizedEmail,
      'password_hash': hashPassword(password),
      'age': age,
      'address': address.trim(),
      'motivation': motivation.label,
      'created_at': DateTime.now().toIso8601String(),
    });
    return (await byId(id))!;
  }

  /// Retourne l'utilisateur si email + mot de passe correspondent, sinon null.
  Future<AppUser?> login(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [normalizeEmail(email), hashPassword(password)],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromRow(rows.single);
  }

  Future<AppUser?> byId(int id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromRow(rows.single);
  }

  /// US3 : le candidat ne peut modifier que son adresse et sa motivation.
  Future<AppUser> updateProfile(
    int id, {
    String? address,
    Motivation? motivation,
  }) async {
    await _db.update(
      'users',
      {
        if (address != null) 'address': address.trim(),
        if (motivation != null) 'motivation': motivation.label,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await byId(id))!;
  }
}
