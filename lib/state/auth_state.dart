import 'package:flutter/foundation.dart';

import '../data/user_repository.dart';
import '../models/motivation.dart';
import '../models/user.dart';

/// Utilisateur connecté, partagé dans toute l'application via Provider.
/// Les méthodes retournent un message d'erreur à afficher, ou null si OK.
class AuthState extends ChangeNotifier {
  AuthState(this._users);

  final UserRepository _users;

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<String?> login(String email, String password) async {
    final found = await _users.login(email, password);
    if (found == null) return 'Email ou mot de passe incorrect';
    _user = found;
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String lastName,
    required String firstName,
    required String email,
    required String password,
    required int age,
    required String address,
    required Motivation motivation,
  }) async {
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
    notifyListeners();
    return null;
  }

  /// Relit l'utilisateur en base (après modification du profil).
  Future<void> refresh() async {
    final id = _user?.id;
    if (id == null) return;
    _user = await _users.byId(id);
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
