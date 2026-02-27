import 'package:pongstrong/models/tournament_enums.dart';

/// Parsed tournament metadata shared between admin and viewer states.
///
/// Both [AdminPanelState] and [TournamentDataState] load metadata from
/// Firestore.  This model centralises the raw-map → typed-field parsing
/// so the logic lives in exactly one place.
class TournamentMetadata {
  final String name;
  final TournamentPhase phase;
  final TournamentStyle style;
  final String? selectedRuleset;
  final int numberOfTables;
  final bool splitTables;
  final int? targetTeamCount;
  final Set<String> reserveTeamIds;
  final String? joinCode;

  const TournamentMetadata({
    this.name = '',
    this.phase = TournamentPhase.notStarted,
    this.style = TournamentStyle.groupsAndKnockouts,
    this.selectedRuleset = 'bmt-cup',
    this.numberOfTables = 6,
    this.splitTables = false,
    this.targetTeamCount,
    this.reserveTeamIds = const {},
    this.joinCode,
  });

  /// Parses tournament metadata from a raw Firestore document map.
  ///
  /// Works with both the full document (from `getTournamentMetadata`) and the
  /// curated subset (from `getTournamentInfo`) — missing keys fall back to
  /// sensible defaults.
  factory TournamentMetadata.fromMap(Map<String, dynamic> map) {
    final phase = TournamentPhaseX.fromFirestore(map['phase'] as String?);
    final style =
        TournamentStyleX.fromFirestore(map['tournamentStyle'] as String?);

    final selectedRuleset = map.containsKey('selectedRuleset')
        ? map['selectedRuleset'] as String?
        : 'bmt-cup';

    final numberOfTables =
        ((map['numberOfTables'] as num?)?.toInt() ?? 6).clamp(1, 100);
    final splitTables = map['splitTables'] == true;

    final tc = (map['targetTeamCount'] as num?)?.toInt();

    final reserveList = map['reserveTeamIds'];
    final reserveTeamIds =
        reserveList is List ? reserveList.cast<String>().toSet() : <String>{};

    final joinCode = map['joinCode'] as String?;
    final name = (map['name'] as String?) ?? '';

    return TournamentMetadata(
      name: name,
      phase: phase,
      style: style,
      selectedRuleset: selectedRuleset,
      numberOfTables: numberOfTables,
      splitTables: splitTables,
      targetTeamCount: tc,
      reserveTeamIds: reserveTeamIds,
      joinCode: joinCode,
    );
  }

  /// The Firestore string key for [style].
  String get styleFirestoreKey => style.firestoreKey;
}

/// Firestore serialisation helpers for [TournamentPhase].
extension TournamentPhaseX on TournamentPhase {
  /// The string stored in Firestore for this phase.
  String get firestoreKey => switch (this) {
        TournamentPhase.notStarted => 'notStarted',
        TournamentPhase.groupPhase => 'groups',
        TournamentPhase.knockoutPhase => 'knockouts',
        TournamentPhase.finished => 'finished',
      };

  /// Parses a Firestore phase string into the corresponding enum value.
  static TournamentPhase fromFirestore(String? value) => switch (value) {
        'groups' => TournamentPhase.groupPhase,
        'knockouts' => TournamentPhase.knockoutPhase,
        'finished' => TournamentPhase.finished,
        _ => TournamentPhase.notStarted,
      };
}

/// Firestore serialisation helpers for [TournamentStyle].
extension TournamentStyleX on TournamentStyle {
  /// The string stored in Firestore for this style.
  String get firestoreKey => switch (this) {
        TournamentStyle.groupsAndKnockouts => 'groupsAndKnockouts',
        TournamentStyle.knockoutsOnly => 'knockoutsOnly',
        TournamentStyle.everyoneVsEveryone => 'everyoneVsEveryone',
      };

  /// Parses a Firestore style string into the corresponding enum value.
  static TournamentStyle fromFirestore(String? value) => switch (value) {
        'knockoutsOnly' => TournamentStyle.knockoutsOnly,
        'everyoneVsEveryone' => TournamentStyle.everyoneVsEveryone,
        _ => TournamentStyle.groupsAndKnockouts,
      };
}
