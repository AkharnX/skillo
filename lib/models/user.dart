/// Modèle d'un utilisateur : une ligne de la table `users`.
library;

import 'motivation.dart';

/// Utilisateur de l'application : candidat ou administrateur.
///
/// Le mot de passe (ou son hash) n'est volontairement **pas** dans ce modèle :
/// il ne sert qu'à la connexion, dans `UserRepository`, et ne doit jamais
/// circuler dans l'interface.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.lastName,
    required this.firstName,
    required this.email,
    required this.age,
    required this.address,
    required this.motivation,
  });

  /// Id en base.
  final int id;

  /// 'candidate' ou 'admin' (contrainte CHECK en base).
  final String role;

  /// Nom de famille.
  final String lastName;

  /// Prénom.
  final String firstName;

  /// Email normalisé (minuscules, sans espaces autour).
  final String email;

  /// Âge déclaré à l'inscription (0 pour l'admin).
  final int age;

  /// Adresse postale, modifiable depuis le profil (US3).
  final String address;

  /// Motivation choisie à l'inscription, modifiable depuis le profil (US3).
  /// Null pour l'admin, qui n'en a pas.
  final Motivation? motivation;

  /// True pour le compte administrateur : décide de l'écran d'accueil.
  bool get isAdmin => role == 'admin';

  /// « Prénom Nom », utilisé dans les en-têtes et le tableau de bord.
  String get fullName => '$firstName $lastName';

  /// Construit un utilisateur à partir d'une ligne SQL de la table `users`.
  factory AppUser.fromRow(Map<String, Object?> row) => AppUser(
    id: row['id'] as int,
    role: row['role'] as String,
    lastName: row['last_name'] as String,
    firstName: row['first_name'] as String,
    email: row['email'] as String,
    age: row['age'] as int,
    address: row['address'] as String,
    motivation: Motivation.fromLabel(row['motivation'] as String),
  );
}
