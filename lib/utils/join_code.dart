import 'dart:math';

/// Utility for generating and validating short tournament join codes.
///
/// Codes are 4-character uppercase alphanumeric strings using the
/// characters `A-Z` (minus ambiguous `I`, `L`, `O`) and `2-9`
/// (minus ambiguous `0`, `1`).
///
/// Every code is guaranteed to contain at least one letter so it
/// cannot be confused with a pure number.
class JoinCode {
  JoinCode._();

  /// Characters allowed in a join code (23 letters + 8 digits = 31).
  static const String _letters = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  static const String _digits = '23456789';
  static const String _allChars = '$_letters$_digits';

  /// Length of a join code.
  static const int codeLength = 4;

  /// Generates a random join code guaranteed to contain at least one letter.
  static String generate() {
    final rng = Random.secure();
    String code;
    do {
      code = String.fromCharCodes(
        List.generate(codeLength,
            (_) => _allChars.codeUnitAt(rng.nextInt(_allChars.length))),
      );
    } while (!_hasLetter(code));
    return code;
  }

  /// Whether [code] is syntactically valid (4 chars from the allowed set,
  /// at least one letter).
  static bool isValid(String code) {
    if (code.length != codeLength) return false;
    if (!code.split('').every((c) => _allChars.contains(c))) return false;
    return _hasLetter(code);
  }

  /// Normalises user input: trims whitespace and uppercases.
  static String normalise(String input) => input.trim().toUpperCase();

  static bool _hasLetter(String code) =>
      code.split('').any((c) => _letters.contains(c));
}
