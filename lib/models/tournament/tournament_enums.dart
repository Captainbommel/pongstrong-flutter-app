// Enums representing tournament lifecycle and format.

/// The current phase of a tournament's lifecycle.
enum TournamentPhase {
  /// Tournament created but not yet started.
  notStarted,

  /// Group phase matches are being played.
  groupPhase,

  /// Knockout rounds are in progress.
  knockoutPhase,

  /// Tournament has concluded.
  finished,
}

/// The format/style of a tournament.
enum TournamentStyle {
  /// Group phase followed by knockout brackets.
  groupsAndKnockouts,

  /// Single-elimination knockout only.
  knockoutsOnly,

  /// Round-robin: every team plays against every other team.
  everyoneVsEveryone,
}

/// Identifies one of the four knockout brackets.
enum BracketKey {
  /// The top-tier bracket (default name: Gold Liga).
  gold('Gold Liga'),

  /// The second-tier bracket (default name: Silber Liga).
  silver('Silber Liga'),

  /// The third-tier bracket (default name: Bronze Liga).
  bronze('Bronze Liga'),

  /// The cross-bracket final (default name: Extra Liga).
  extra('Extra Liga');

  /// The default display name for this bracket.
  final String defaultDisplayName;

  const BracketKey(this.defaultDisplayName);
}
