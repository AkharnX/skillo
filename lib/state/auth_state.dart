/// État d'authentification partagé dans toute l'application.
///
/// Un seul objet [AuthState] est créé dans `app.dart` et fourni par
/// `Provider`. Les écrans lisent `context.watch<AuthState>()` : dès que
/// l'utilisateur connecté change (login, logout, profil modifié),
/// `notifyListeners()` les fait se reconstruire, et `HomeRouter` affiche
/// l'écran correspondant.
library;

import 'package:flutter/foundation.dart';

import '../data/user_repository.dart';
import '../models/motivation.dart';
import '../models/user.dart';

/// Utilisateur connecté, partagé dans toute l'application via Provider.
///
/// Les méthodes [login] et [register] retournent un message d'erreur à
/// afficher, ou null si tout s'est bien passé : l'écran n'a pas à connaître
/// les exceptions de la couche données.
class AuthState extends ChangeNotifier {
  /// Reçoit le repository des utilisateurs, seul accès à la table `users`.
  AuthState(this._users);

  final UserRepository _users;

  /// Utilisateur connecté, null si personne.
  AppUser? _user;

  /// Utilisateur connecté, null si personne.
  AppUser? get user => _user;

  /// True si quelqu'un est connecté.
  bool get isLoggedIn => _user != null;

  /// Tente la connexion. Retourne null si OK, sinon le message à afficher.
  Future<String?> login(String email, String password) async {
    // 1. Vérification email + mot de passe par le repository.
    final found = await _users.login(email, password);
    if (found == null) return 'Email ou mot de passe incorrect';

    // 2. Succès : on mémorise l'utilisateur et on prévient les écrans.
    _user = found;
    notifyListeners();
    return null;
  }

  /// Crée un compte candidat puis le connecte directement (US1).
  /// Retourne null si OK, sinon le message à afficher (compte en double).
  Future<String?> register({
    required String lastName,
    required String firstName,
    required String email,
    required String password,
    required int age,
    required String address,
    required Motivation motivation,
  }) async {
    // 1. Création en base ; un doublon Nom + Email est une erreur attendue.
    try {
      _user = await _users.register(
        lastName: lastName,
        firstName: firstName,
        email: email,
        password: password,
        age: age,
        address: address,
        motivation: motivation,
      );
    } on DuplicateAccountException catch (e) {
      return e.toString();
    }

    // 2. Succès : l'utilisateur est connecté.
    notifyListeners();
    return null;
  }

  /// Relit l'utilisateur en base (après modification du profil, US3) pour
  /// que les écrans affichent les nouvelles valeurs.
  Future<void> refresh() async {
    final id = _user?.id;
    if (id == null) return;
    _user = await _users.byId(id);
    notifyListeners();
  }

  /// Déconnecte : plus d'utilisateur, HomeRouter revient à l'écran de login.
  void logout() {
    _user = null;
    notifyListeners();
  }
}
