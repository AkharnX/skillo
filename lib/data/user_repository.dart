/// Accès à la table `users` : inscription, connexion, profil.
///
/// Les mots de passe ne sont jamais manipulés en clair au-delà de ce fichier :
/// ils sont hachés par `hashPassword` avant toute écriture ou comparaison.
library;

import 'package:sqflite_common/sqlite_api.dart';

import '../models/motivation.dart';
import '../models/user.dart';
import 'password.dart';

/// Levée quand un compte existe déjà pour la même combinaison Nom + Email (US1).
class DuplicateAccountException implements Exception {
  /// Message affiché tel quel à l'utilisateur.
  @override
  String toString() => 'Un compte existe déjà avec ce nom et cet email.';
}

/// Accès à la table `users` : inscription, connexion, profil.
class UserRepository {
  /// Reçoit la base déjà ouverte par `openAppDatabase`.
  UserRepository(this._db);

  final Database _db;

  /// Normalise l'email pour que « Jean@Dupont.FR » et « jean@dupont.fr »
  /// désignent le même compte : on enlève les espaces autour et on passe en
  /// minuscules. Utilisé à l'inscription **et** à la connexion, pour que les
  /// deux côtés comparent la même chose.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// Crée un compte candidat (US1) et retourne l'utilisateur créé.
  ///
  /// Lève [DuplicateAccountException] si un compte existe déjà avec le même
  /// nom **et** le même email (comparaison insensible à la casse). Le même
  /// email avec un autre nom est autorisé, conformément au cahier des charges.
  Future<AppUser> register({
    required String lastName,
    required String firstName,
    required String email,
    required String password,
    required int age,
    required String address,
    required Motivation motivation,
  }) async {
    // 1. Recherche d'un doublon Nom + Email. `COLLATE NOCASE` fait la
    //    comparaison sans tenir compte des majuscules, comme l'index unique.
    final normalizedEmail = normalizeEmail(email);
    final existing = await _db.query(
      'users',
      columns: ['id'],
      where: 'last_name = ? COLLATE NOCASE AND email = ? COLLATE NOCASE',
      whereArgs: [lastName.trim(), normalizedEmail],
    );
    if (existing.isNotEmpty) throw DuplicateAccountException();

    // 2. Insertion. Le mot de passe est remplacé par son hash SHA-256 ; la
    //    motivation est stockée par son libellé lisible.
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

    // 3. Relecture de la ligne pour renvoyer un AppUser complet.
    return (await byId(id))!;
  }

  /// Retourne l'utilisateur si email + mot de passe correspondent, sinon null.
  ///
  /// On ne déchiffre jamais rien : on hache le mot de passe saisi et on
  /// cherche une ligne qui a exactement cet email et ce hash.
  Future<AppUser?> login(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [normalizeEmail(email), hashPassword(password)],
      limit: 1,
    );
    return rows.isEmpty ? null : AppUser.fromRow(rows.single);
  }

  /// Utilisateur par id, ou null s'il n'existe pas.
  Future<AppUser?> byId(int id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : AppUser.fromRow(rows.single);
  }

  /// US3 : le candidat ne peut modifier que son adresse et sa motivation.
  /// Un paramètre laissé à null n'est pas modifié. Retourne l'utilisateur
  /// relu après la mise à jour.
  Future<AppUser> updateProfile(
    int id, {
    String? address,
    Motivation? motivation,
  }) async {
    // 1. On ne met dans la requête UPDATE que les colonnes fournies.
    final changes = <String, Object?>{};
    if (address != null) changes['address'] = address.trim();
    if (motivation != null) changes['motivation'] = motivation.label;

    // 2. Mise à jour de la ligne de cet utilisateur.
    await _db.update('users', changes, where: 'id = ?', whereArgs: [id]);

    // 3. Relecture pour renvoyer les valeurs à jour.
    return (await byId(id))!;
  }
}
