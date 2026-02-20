import 'dart:ui';

// ═══════════════════════════════════════════════════════════════
//  App-wide generic UI colors
//
//  Surfaces, text, shadows, neutrals & feedback states.
//  Change a value here to update the entire app at once.
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._(); // prevent instantiation

  // ─── Surfaces & backgrounds ────────────────────────────────
  /// Primary surface (cards, dialogs, dropdowns, text-field fills)
  static const surface = Color(0xFFFFFFFF);

  /// Page / scaffold background
  static const scaffoldBackground = Color(0xFFF5F5F5);

  /// Fully transparent
  static const transparent = Color(0x00000000);

  // ─── Text & icons ─────────────────────────────────────────
  /// Main body text & strong icons  (≈ black 87 %)
  static const textPrimary = Color(0xDD000000);

  /// Secondary / supporting text     (≈ black 54 %)
  static const textSecondary = Color(0x8A000000);

  /// Text & icons shown on a coloured background
  static const textOnColored = Color(0xFFFFFFFF);

  /// Disabled / placeholder text & icons
  static const textDisabled = Color(0xFF9E9E9E);

  /// Subtle labels, subtitles          (grey 600)
  static const textSubtle = Color(0xFF757575);

  // ─── Shadows & overlays ──────────────────────────────────
  /// Pure black – used as shadow source colour
  static const shadow = Color(0xFF000000);

  /// 10 % black – light card shadow
  static const shadowLight = Color(0x1A000000);

  /// 60 % black – modal overlays, swipe hints
  static const overlay = Color(0x99000000);

  // ─── Neutral greys ───────────────────────────────────────
  static const grey50 = Color(0xFFFAFAFA);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey200 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFE0E0E0);
  static const grey400 = Color(0xFFBDBDBD);
  static const grey500 = Color(0xFF9E9E9E);
  static const grey600 = Color(0xFF757575);
  static const grey700 = Color(0xFF616161);

  // ─── Feedback: Error / destructive ─────────────────────
  static const error = Color(0xFFF44336);
  static const errorLight = Color(0xFFFFEBEE);

  // ─── Feedback: Success ─────────────────────────────────
  static const success = Color(0xFF4CAF50);
  static const successLight = Color(0xFFE8F5E9);
  static const successBorder = Color(0xFFA5D6A7);

  // ─── Feedback: Warning (orange) ────────────────────────
  static const warning = Color(0xFFFF9800);

  // ─── Feedback: Caution (amber) ─────────────────────────
  static const caution = Color(0xFFFFC107);
  static const cautionLight = Color(0xFFFFF8E1);

  // ─── Feedback: Info (blue) ─────────────────────────────
  static const info = Color(0xFF2196F3);
  static const infoLight = Color(0xFFE3F2FD);
  static const infoBorder = Color(0xFF90CAF9);
}

// ═══════════════════════════════════════════════════════════════
//  Playing field colors
// ═══════════════════════════════════════════════════════════════

class FieldColors {
  static const tomato = Color.fromARGB(255, 255, 99, 71);
  static const springgreen = Color.fromARGB(255, 0, 255, 127);
  static const skyblue = Color.fromARGB(255, 135, 206, 235);
  static const darkSkyblue = Color.fromARGB(255, 109, 160, 180);
  static const backgroundblue = Color.fromARGB(240, 169, 216, 255);
  static const fieldbackground = Color.fromARGB(50, 128, 128, 128);
}

// ═══════════════════════════════════════════════════════════════
//  Table assignment colors (one per physical table)
// ═══════════════════════════════════════════════════════════════

class TableColors {
  static const blue = Color.fromARGB(255, 28, 67, 151);
  static const green = Color.fromARGB(255, 98, 160, 93);
  static const purple = Color.fromARGB(255, 192, 47, 185);
  static const orange = Color.fromARGB(255, 222, 97, 14);
  static const gold = Color.fromARGB(255, 208, 157, 28);
  static const turquoise = Color.fromARGB(255, 32, 218, 209);

  static Color forIndex(int i) =>
      <Color>[blue, green, purple, orange, gold, turquoise][i % 6];
}

// ═══════════════════════════════════════════════════════════════
//  Knockout tree / bracket phase colors
// ═══════════════════════════════════════════════════════════════

class TreeColors {
  static const cornsilk = Color.fromARGB(255, 255, 248, 220);
  static const rebeccapurple = Color.fromARGB(255, 102, 51, 153);
  static const royalblue = Color.fromARGB(255, 65, 105, 225);
  static const yellowgreen = Color.fromARGB(255, 154, 205, 50);
  static const hotpink = Color.fromARGB(255, 255, 105, 180);
}

// ═══════════════════════════════════════════════════════════════
//  Group phase overview colors
// ═══════════════════════════════════════════════════════════════

class GroupPhaseColors {
  static const steelblue = Color.fromARGB(255, 70, 130, 180);
  static const grouppurple = Color.fromARGB(240, 180, 70, 130);
  static const cupred = Color.fromARGB(255, 213, 35, 70);
}
