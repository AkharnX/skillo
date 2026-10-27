/// Hachage des mots de passe.
///
/// Un mot de passe n'est **jamais** écrit en clair dans la base : on en stocke
/// seulement l'empreinte SHA-256. À la connexion, on hache le mot de passe
/// saisi et on compare les deux empreintes (voir `UserRepository.login`).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Transforme un mot de passe en empreinte SHA-256 écrite en hexadécimal
/// (64 caractères).
///
/// Pourquoi SHA-256 ? C'est une fonction « à sens unique » : à partir de
/// l'empreinte, on ne peut pas retrouver le mot de passe. Si quelqu'un lit la
/// base, il ne voit donc jamais les vrais mots de passe. Le même mot de passe
/// donne toujours la même empreinte, ce qui permet la comparaison au login.
///
/// Étapes : 1. le texte est converti en octets UTF-8 ; 2. SHA-256 calcule
/// l'empreinte ; 3. `toString()` l'écrit en hexadécimal.
String hashPassword(String raw) => sha256.convert(utf8.encode(raw)).toString();
