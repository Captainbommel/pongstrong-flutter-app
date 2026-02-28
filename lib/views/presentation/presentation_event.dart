import 'package:flutter/material.dart';

/// Describes a noteworthy tournament event that the presentation screen
/// should display as a dedicated "flash" slide before resuming the normal
/// cycle.
///
/// Events are enqueued by [PresentationState] whenever the incoming Firestore
/// data indicates something interesting happened (match finished, bracket
/// winner decided, group placements finalised, …).
enum PresentationEventType {
  /// A match was completed.
  matchFinished,

  /// A knockout bracket has a winner (final match is done).
  bracketWinner,

  /// All placements in a group are decided (all group matches done).
  groupDecided,

  /// The tournament has transitioned to the knockout phase.
  knockoutPhaseStarted,

  /// The entire tournament is finished.
  tournamentFinished,
}

class PresentationEvent {
  final PresentationEventType type;

  /// Human-readable headline, e.g. "Spiel beendet" or "Gold Liga Sieger".
  final String headline;

  /// Multi-line body text with details (team names, scores, …).
  final String body;

  /// Optional: the bracket/group this event relates to.
  final String? context;

  /// Optional accent color for this event (e.g. table color for matchFinished).
  final Color? color;

  const PresentationEvent({
    required this.type,
    required this.headline,
    required this.body,
    this.context,
    this.color,
  });

  @override
  String toString() => 'PresentationEvent($type, "$headline")';
}
