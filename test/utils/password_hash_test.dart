import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/utils/password_hash.dart';

void main() {
  group('PasswordHash', () {
    test('hash returns a non-empty string', () {
      final hashed = PasswordHash.hash('password123');
      expect(hashed, isNotEmpty);
    });

    test('hash produces unique output per call (random salt)', () {
      final hash1 = PasswordHash.hash('test');
      final hash2 = PasswordHash.hash('test');
      // Different salts → different stored strings, but both verify
      expect(hash1, isNot(hash2));
      expect(PasswordHash.verify('test', hash1), isTrue);
      expect(PasswordHash.verify('test', hash2), isTrue);
    });

    test('hash returns different output for different inputs', () {
      final hash1 = PasswordHash.hash('password1');
      final hash2 = PasswordHash.hash('password2');
      expect(hash1, isNot(hash2));
    });

    test('hash produces salt:hash format (129 chars)', () {
      final hashed = PasswordHash.hash('anything');
      // Format: 64 hex salt + ':' + 64 hex hash = 129
      expect(hashed.length, 129);
      expect(hashed.contains(':'), isTrue);
      final parts = hashed.split(':');
      expect(parts.length, 2);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[0]), isTrue);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[1]), isTrue);
    });

    test('hash handles empty string', () {
      final hashed = PasswordHash.hash('');
      expect(hashed, isNotEmpty);
      expect(hashed.length, 129);
      expect(PasswordHash.verify('', hashed), isTrue);
    });

    test('hash handles unicode characters', () {
      final hashed = PasswordHash.hash('Bïér Pöng 🍺');
      expect(hashed, isNotEmpty);
      expect(hashed.length, 129);
      expect(PasswordHash.verify('Bïér Pöng 🍺', hashed), isTrue);
    });

    test('verify returns true for matching password', () {
      final hashed = PasswordHash.hash('secret');
      expect(PasswordHash.verify('secret', hashed), isTrue);
    });

    test('verify returns false for wrong password', () {
      final hashed = PasswordHash.hash('secret');
      expect(PasswordHash.verify('wrong', hashed), isFalse);
    });

    test('verify returns false for empty password against non-empty hash', () {
      final hashed = PasswordHash.hash('secret');
      expect(PasswordHash.verify('', hashed), isFalse);
    });

    test('verify is case-sensitive', () {
      final hashed = PasswordHash.hash('Password');
      expect(PasswordHash.verify('password', hashed), isFalse);
      expect(PasswordHash.verify('PASSWORD', hashed), isFalse);
    });
  });
}
