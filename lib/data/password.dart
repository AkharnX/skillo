import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hache un mot de passe en SHA-256 (hexadécimal).
/// On ne stocke jamais le mot de passe en clair en base.
String hashPassword(String raw) => sha256.convert(utf8.encode(raw)).toString();
