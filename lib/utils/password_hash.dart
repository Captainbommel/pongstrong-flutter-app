import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility for secure password hashing
class PasswordHash {
  /// Hashes a password using SHA-256
  /// This is a one-way hash - passwords cannot be decrypted
  static String hash(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain text password matches a hashed password
  static bool verify(String plainPassword, String hashedPassword) {
    return hash(plainPassword) == hashedPassword;
  }
}
