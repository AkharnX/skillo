import 'motivation.dart';

/// Utilisateur de l'application : candidat ou administrateur.
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

  final int id;
  final String role; // 'candidate' ou 'admin'
  final String lastName;
  final String firstName;
  final String email;
  final int age;
  final String address;
  final Motivation? motivation; // null pour l'admin

  bool get isAdmin => role == 'admin';
  String get fullName => '$firstName $lastName';

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
