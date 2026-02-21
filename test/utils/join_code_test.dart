import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/utils/join_code.dart';

void main() {
  group('JoinCode', () {
    test('generate produces a 4-character code', () {
      final code = JoinCode.generate();
      expect(code.length, JoinCode.codeLength);
    });

    test('generate produces only allowed characters', () {
      const allowed = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
      for (var i = 0; i < 100; i++) {
        final code = JoinCode.generate();
        for (final c in code.split('')) {
          expect(allowed.contains(c), isTrue,
              reason: 'Character "$c" in "$code" is not allowed');
        }
      }
    });

    test('generate always includes at least one letter', () {
      for (var i = 0; i < 200; i++) {
        final code = JoinCode.generate();
        final hasLetter =
            code.split('').any((c) => 'ABCDEFGHJKMNPQRSTUVWXYZ'.contains(c));
        expect(hasLetter, isTrue, reason: 'Code "$code" has no letters');
      }
    });

    test('generate produces different codes (not always the same)', () {
      final codes = List.generate(20, (_) => JoinCode.generate()).toSet();
      // With 31^4 possibilities, 20 codes should not all be the same
      expect(codes.length, greaterThan(1));
    });

    group('isValid', () {
      test('accepts valid codes', () {
        expect(JoinCode.isValid('K7X2'), isTrue);
        expect(JoinCode.isValid('ABCD'), isTrue);
        expect(JoinCode.isValid('A234'), isTrue);
        expect(JoinCode.isValid('Z9Z9'), isTrue);
      });

      test('rejects codes without letters (all digits)', () {
        expect(JoinCode.isValid('2345'), isFalse);
        expect(JoinCode.isValid('9999'), isFalse);
      });

      test('rejects wrong length', () {
        expect(JoinCode.isValid('ABC'), isFalse);
        expect(JoinCode.isValid('ABCDE'), isFalse);
        expect(JoinCode.isValid(''), isFalse);
      });

      test('rejects ambiguous characters', () {
        // O, I, L, 0, 1 are excluded
        expect(JoinCode.isValid('O234'), isFalse);
        expect(JoinCode.isValid('I234'), isFalse);
        expect(JoinCode.isValid('L234'), isFalse);
        expect(JoinCode.isValid('A0BC'), isFalse);
        expect(JoinCode.isValid('A1BC'), isFalse);
      });

      test('rejects lowercase', () {
        expect(JoinCode.isValid('k7x2'), isFalse);
      });

      test('rejects special characters', () {
        expect(JoinCode.isValid('AB-C'), isFalse);
        expect(JoinCode.isValid('AB C'), isFalse);
      });
    });

    group('normalise', () {
      test('uppercases input', () {
        expect(JoinCode.normalise('k7x2'), 'K7X2');
      });

      test('trims whitespace', () {
        expect(JoinCode.normalise(' K7X2 '), 'K7X2');
      });

      test('handles mixed case and whitespace', () {
        expect(JoinCode.normalise('  aB3d  '), 'AB3D');
      });
    });

    test('generated codes always pass isValid', () {
      for (var i = 0; i < 100; i++) {
        final code = JoinCode.generate();
        expect(JoinCode.isValid(code), isTrue,
            reason: 'Generated code "$code" failed isValid');
      }
    });
  });
}
