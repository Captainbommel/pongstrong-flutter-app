import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Utility for secure password hashing using HMAC-SHA256 with a random salt.
///
/// Stored format: `<hex-salt>:<hex-hash>` (64 + 1 + 64 = 129 chars).
/// The salt prevents rainbow-table attacks and ensures identical passwords
/// produce different hashes.
class PasswordHash {
  static const int _saltLength = 32;
  static const int _iterations = 10000;

  /// Hashes a [password] with a freshly generated random salt.
  ///
  /// Returns a string in the format `salt:hash` suitable for storage.
  static String hash(String password) {
    final salt = _generateSalt();
    final hash = _deriveKey(password, salt);
    return '${_bytesToHex(salt)}:${_bytesToHex(hash)}';
  }

  /// Verifies that [plainPassword] matches the given [hashedPassword].
  ///
  /// [hashedPassword] must be in the `salt:hash` format produced by [hash].
  static bool verify(String plainPassword, String hashedPassword) {
    final parts = hashedPassword.split(':');
    if (parts.length != 2) return false;

    final salt = _hexToBytes(parts[0]);
    final storedHash = parts[1];
    final computedHash = _bytesToHex(_deriveKey(plainPassword, salt));
    return _constantTimeEquals(computedHash, storedHash);
  }

  /// Derives a key from [password] and [salt] using iterated HMAC-SHA256.
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    var result = Uint8List.fromList([...salt, ...passwordBytes]);
    for (var i = 0; i < _iterations; i++) {
      final hmac = Hmac(sha256, passwordBytes);
      result = Uint8List.fromList(hmac.convert(result).bytes);
    }
    return result;
  }

  /// Generates a cryptographically random salt.
  static Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Constant-time string comparison to prevent timing attacks.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
