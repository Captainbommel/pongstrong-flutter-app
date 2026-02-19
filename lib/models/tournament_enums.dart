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
