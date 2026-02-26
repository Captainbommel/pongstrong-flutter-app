import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/tournament_enums.dart';

/// A generic knockout bracket with N rounds, each containing progressively
/// fewer matches (e.g. [8, 4, 2, 1] for a Champions-style bracket).
class KnockoutBracket {
  List<List<Match>> rounds;

  /// [idPrefix] is used when generating match IDs (e.g. 'c' for Champions).
  /// [roundSizes] defines how many matches each round has.
  KnockoutBracket({List<List<Match>>? rounds}) : rounds = rounds ?? [];

  /// Creates match stubs with generated IDs.
  void instantiate(String idPrefix, List<int> roundSizes) {
    rounds = [
      for (int r = 0; r < roundSizes.length; r++)
        List.generate(
          roundSizes[r],
          (i) => Match(id: '$idPrefix${r + 1}${i + 1}'),
        ),
    ];
  }

  /// Serialises the bracket rounds to a JSON-compatible structure.
  List<List<Map<String, dynamic>>> toJson() =>
      rounds.map((round) => round.map((m) => m.toJson()).toList()).toList();

  /// Creates a [KnockoutBracket] from a Firestore JSON list.
  static KnockoutBracket fromJson(List<dynamic> json) => KnockoutBracket(
        rounds: json
            .map((round) => (round as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KnockoutBracket) return false;
    if (rounds.length != other.rounds.length) return false;
    for (int i = 0; i < rounds.length; i++) {
      if (rounds[i].length != other.rounds[i].length) return false;
      for (int j = 0; j < rounds[i].length; j++) {
        if (rounds[i][j] != other.rounds[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        rounds.map((r) => Object.hashAll(r)),
      );
}

typedef Champions = KnockoutBracket;
typedef Europa = KnockoutBracket;
typedef Conference = KnockoutBracket;

/// The Super Cup bracket with two fixed matches.
class Super {
  /// The super cup matches.
  List<Match> matches;

  Super({List<Match>? matches}) : matches = matches ?? [];

  /// Creates match stubs for the super cup.
  void instantiate() {
    matches = [
      Match(id: 's1'),
      Match(id: 's2'),
    ];
  }

  /// Serialises the super cup to a JSON list.
  List<Map<String, dynamic>> toJson() =>
      matches.map((m) => m.toJson()).toList();

  /// Creates a [Super] from a Firestore JSON list.
  static Super fromJson(List<dynamic> json) => Super(
        matches:
            json.map((m) => Match.fromJson(m as Map<String, dynamic>)).toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Super &&
          matches.length == other.matches.length &&
          _matchListEquals(matches, other.matches);

  @override
  int get hashCode => Object.hashAll(matches);

  static bool _matchListEquals(List<Match> a, List<Match> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Complete knockout phase with Champions, Europa, Conference brackets and Super Cup.
class Knockouts {
  /// The main Champions bracket (8→4→2→1).
  Champions champions;

  /// The Europa bracket (4→2→1).
  Europa europa;

  /// The Conference bracket (4→2→1).
  Conference conference;

  /// The Super Cup finals.
  Super superCup;

  /// Custom display names for each bracket.
  Map<BracketKey, String> bracketNames;

  /// Default bracket display names.
  static final Map<BracketKey, String> defaultBracketNames = {
    for (final key in BracketKey.values) key: key.defaultDisplayName,
  };

  Knockouts({
    Champions? champions,
    Europa? europa,
    Conference? conference,
    Super? superCup,
    Map<BracketKey, String>? bracketNames,
  })  : champions = champions ?? Champions(),
        europa = europa ?? Europa(),
        conference = conference ?? Conference(),
        superCup = superCup ?? Super(),
        bracketNames = bracketNames ?? Map.from(defaultBracketNames);

  /// Returns the display name for a bracket key.
  String getBracketName(BracketKey key) =>
      bracketNames[key] ?? key.defaultDisplayName;

  /// Creates all match stubs across all brackets.
  void instantiate() {
    champions.instantiate('c', [8, 4, 2, 1]);
    europa.instantiate('e', [4, 2, 1]);
    conference.instantiate('f', [4, 2, 1]);
    superCup.instantiate();
  }

  /// Finds a match by ID and updates its score.
  ///
  /// Returns `true` if the match was found and updated.
  bool updateMatchScore(String matchId, int score1, int score2) {
    // Helper function to search and update in rounds
    bool searchAndUpdate(List<List<Match>> rounds) {
      for (final round in rounds) {
        for (final match in round) {
          if (match.id == matchId) {
            match.score1 = score1;
            match.score2 = score2;
            match.done = true;
            return true;
          }
        }
      }
      return false;
    }

    // Search in all tournament structures
    if (searchAndUpdate(champions.rounds)) return true;
    if (searchAndUpdate(europa.rounds)) return true;
    if (searchAndUpdate(conference.rounds)) return true;

    // Search in super cup
    for (final match in superCup.matches) {
      if (match.id == matchId) {
        match.score1 = score1;
        match.score2 = score2;
        match.done = true;
        return true;
      }
    }

    return false;
  }

  /// Clears all matches that depend on the given match result.
  ///
  /// Used when editing a match to prevent cascading inconsistencies.
  /// Returns the IDs of cleared matches.
  List<String> clearDependentMatches(String matchId) {
    final clearedIds = <String>[];

    // Helper to find which round contains the match
    (List<List<Match>>?, int, int) findMatchLocation(List<List<Match>> rounds) {
      for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
        for (int matchIndex = 0;
            matchIndex < rounds[roundIndex].length;
            matchIndex++) {
          if (rounds[roundIndex][matchIndex].id == matchId) {
            return (rounds, roundIndex, matchIndex);
          }
        }
      }
      return (null, -1, -1);
    }

    // Helper to clear dependent matches in subsequent rounds
    void clearSubsequentRounds(
        List<List<Match>> rounds, int startRound, int matchIndex) {
      for (int roundIndex = startRound + 1;
          roundIndex < rounds.length;
          roundIndex++) {
        for (final match in rounds[roundIndex]) {
          if (match.teamId1.isNotEmpty ||
              match.teamId2.isNotEmpty ||
              match.done) {
            clearedIds.add(match.id);
            match.teamId1 = '';
            match.teamId2 = '';
            match.score1 = 0;
            match.score2 = 0;
            match.done = false;
          }
        }
      }
    }

    /// Clears super cup matches at the given [indices].
    void clearSuperCupMatches(List<int> indices) {
      for (final i in indices) {
        if (i < superCup.matches.length) {
          final m = superCup.matches[i];
          if (m.teamId1.isNotEmpty || m.teamId2.isNotEmpty || m.done) {
            clearedIds.add(m.id);
            m.teamId1 = '';
            m.teamId2 = '';
            m.score1 = 0;
            m.score2 = 0;
            m.done = false;
          }
        }
      }
    }

    // Check each bracket and handle super cup cascading
    final brackets = [
      (champions.rounds, [1]), // Champions final → clear super cup match 1
      (europa.rounds, [0, 1]), // Europa final → clear super cup matches 0, 1
      (
        conference.rounds,
        [0, 1]
      ), // Conference final → clear super cup matches 0, 1
    ];

    for (final (rounds, superCupIndices) in brackets) {
      final location = findMatchLocation(rounds);
      if (location.$1 != null) {
        clearSubsequentRounds(location.$1!, location.$2, location.$3);
        if (location.$2 == rounds.length - 1) {
          clearSuperCupMatches(superCupIndices);
        }
        return clearedIds;
      }
    }

    // Check super cup matches
    for (int i = 0; i < superCup.matches.length; i++) {
      if (superCup.matches[i].id == matchId) {
        if (i == 0) {
          clearSuperCupMatches([1]);
        }
        return clearedIds;
      }
    }

    return clearedIds;
  }

  /// Checks finished matches and advances winners to the next round.
  void update() {
    // Guard: nothing to update if champions bracket is empty
    if (champions.rounds.isEmpty || champions.rounds[0].isEmpty) return;

    if (champions.rounds[0][0].teamId1.isEmpty &&
        champions.rounds[0][0].teamId2.isEmpty) {
      return;
    }

    _updateLeagueRounds(champions.rounds);
    _updateLeagueRounds(europa.rounds);
    _updateLeagueRounds(conference.rounds);

    _updateSuperCup();
  }

  void _updateLeagueRounds(List<List<Match>> rounds) {
    for (int roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      final currentRound = rounds[roundIndex];
      final nextRound = rounds[roundIndex + 1];

      for (int matchIndex = 0; matchIndex < currentRound.length; matchIndex++) {
        final currentMatch = currentRound[matchIndex];

        // skip unfinished matches
        if (!currentMatch.done) continue;
        final winnerId = currentMatch.getWinnerId();
        if (winnerId == null || winnerId.isEmpty) continue;

        // find index of next match
        final nextMatchIndex = matchIndex ~/ 2;
        final nextMatch = nextRound[nextMatchIndex];

        // find empty slot
        final canPlaceInSlot1 =
            nextMatch.teamId1.isEmpty && winnerId != nextMatch.teamId2;
        final canPlaceInSlot2 =
            nextMatch.teamId2.isEmpty && winnerId != nextMatch.teamId1;

        if (canPlaceInSlot1) {
          nextMatch.teamId1 = winnerId;
        } else if (canPlaceInSlot2) {
          nextMatch.teamId2 = winnerId;
        }
      }
    }
  }

  void _updateSuperCup() {
    // Guard against empty super cup (e.g. KO-only mode)
    if (superCup.matches.length < 2) return;

    // Determine how many lower leagues feed into super cup match 0.
    final hasEuropa = europa.rounds.isNotEmpty;
    final hasConference = conference.rounds.isNotEmpty;
    final leagueCount = (hasEuropa ? 1 : 0) + (hasConference ? 1 : 0);

    // When only one lower league exists, super cup match 0 has no opponent —
    // auto-advance the lone league winner directly to match 1.
    if (leagueCount <= 1) {
      Match? soleLeagueFinal;
      if (hasEuropa && europa.rounds.last.isNotEmpty) {
        soleLeagueFinal = europa.rounds.last[0];
      } else if (hasConference && conference.rounds.last.isNotEmpty) {
        soleLeagueFinal = conference.rounds.last[0];
      }
      if (soleLeagueFinal != null && soleLeagueFinal.done) {
        final winnerId = soleLeagueFinal.getWinnerId();
        if (winnerId != null &&
            winnerId.isNotEmpty &&
            superCup.matches[1].teamId1.isEmpty) {
          superCup.matches[1].teamId1 = winnerId;
        }
      }
    } else {
      // Two lower leagues: play super cup match 0 between their winners.

      // Update the first super cup match if done
      if (superCup.matches[0].done) {
        final winnerId = superCup.matches[0].getWinnerId();
        if (winnerId != null && winnerId.isNotEmpty) {
          superCup.matches[1].teamId1 = winnerId;
        }
      }

      // Move league winners to the super cup match 0
      final leagueFinals = <Match>[];
      if (hasEuropa && europa.rounds.last.isNotEmpty) {
        leagueFinals.add(europa.rounds.last[0]);
      }
      if (hasConference && conference.rounds.last.isNotEmpty) {
        leagueFinals.add(conference.rounds.last[0]);
      }
      for (final leagueFinal in leagueFinals) {
        if (leagueFinal.done) {
          final winnerId = leagueFinal.getWinnerId();
          if (winnerId != null && winnerId.isNotEmpty) {
            final firstMatch = superCup.matches[0];
            if (firstMatch.teamId1.isEmpty && winnerId != firstMatch.teamId2) {
              firstMatch.teamId1 = winnerId;
            } else if (firstMatch.teamId2.isEmpty &&
                winnerId != firstMatch.teamId1) {
              firstMatch.teamId2 = winnerId;
            }
          }
        }
      }
    }

    // Move champions league winner to the second super cup match
    if (champions.rounds.isNotEmpty &&
        champions.rounds.last.isNotEmpty &&
        champions.rounds.last[0].done) {
      final winnerId = champions.rounds.last[0].getWinnerId();
      if (winnerId != null &&
          winnerId.isNotEmpty &&
          superCup.matches[1].teamId2.isEmpty &&
          superCup.matches[1].teamId1.isNotEmpty) {
        superCup.matches[1].teamId2 = winnerId;
      }
    }
  }

  /// Serialises all knockout brackets to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        BracketKey.gold.name: champions.toJson(),
        BracketKey.silver.name: europa.toJson(),
        BracketKey.bronze.name: conference.toJson(),
        BracketKey.extra.name: superCup.toJson(),
        'bracketNames': {
          for (final entry in bracketNames.entries) entry.key.name: entry.value,
        },
      };

  /// Creates a deep copy of this Knockouts.
  Knockouts clone() {
    final cloned = Knockouts.fromJson(toJson());
    cloned.bracketNames = Map.from(bracketNames);
    return cloned;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Knockouts &&
          champions == other.champions &&
          europa == other.europa &&
          conference == other.conference &&
          superCup == other.superCup;

  @override
  int get hashCode => Object.hash(champions, europa, conference, superCup);

  /// Creates a [Knockouts] from a Firestore JSON map.
  factory Knockouts.fromJson(Map<String, dynamic> json) {
    final names = json['bracketNames'] as Map<String, dynamic>?;
    Map<BracketKey, String>? parsedNames;
    if (names != null) {
      parsedNames = {};
      for (final entry in names.entries) {
        final key = BracketKey.values.where((k) => k.name == entry.key);
        if (key.isNotEmpty) {
          parsedNames[key.first] = entry.value.toString();
        }
      }
    }
    return Knockouts(
      champions:
          KnockoutBracket.fromJson((json[BracketKey.gold.name] as List?) ?? []),
      europa: KnockoutBracket.fromJson(
          (json[BracketKey.silver.name] as List?) ?? []),
      conference: KnockoutBracket.fromJson(
          (json[BracketKey.bronze.name] as List?) ?? []),
      superCup: Super.fromJson((json[BracketKey.extra.name] as List?) ?? []),
      bracketNames: parsedNames,
    );
  }
}

// mapTables maps the tables to the Knockout matches
void mapTables(Knockouts knock) {
  const champTables = [
    [1, 2, 3, 4, 5, 6, 1, 2],
    [3, 4, 5, 6],
    [1, 2],
    [3]
  ];
  for (int i = 0; i < knock.champions.rounds.length; i++) {
    for (int j = 0; j < knock.champions.rounds[i].length; j++) {
      knock.champions.rounds[i][j].tableNumber = champTables[i][j];
    }
  }

  const euroTables = [
    [1, 2, 3, 4],
    [5, 6],
    [4]
  ];
  for (int i = 0; i < knock.europa.rounds.length; i++) {
    for (int j = 0; j < knock.europa.rounds[i].length; j++) {
      knock.europa.rounds[i][j].tableNumber = euroTables[i][j];
    }
  }

  const confTables = [
    [5, 6, 1, 2],
    [3, 4],
    [5]
  ];
  for (int i = 0; i < knock.conference.rounds.length; i++) {
    for (int j = 0; j < knock.conference.rounds[i].length; j++) {
      knock.conference.rounds[i][j].tableNumber = confTables[i][j];
    }
  }

  const superTables = [6, 1];
  for (int i = 0; i < knock.superCup.matches.length; i++) {
    knock.superCup.matches[i].tableNumber = superTables[i];
  }
}
