import 'match.dart';

class Champions {
  List<List<Match>> rounds;

  Champions({List<List<Match>>? rounds}) : rounds = rounds ?? [];

  void instantiate() {
    rounds = [
      List.generate(8, (i) => Match(id: 'c1${i + 1}')),
      List.generate(4, (i) => Match(id: 'c2${i + 1}')),
      List.generate(2, (i) => Match(id: 'c3${i + 1}')),
      List.generate(1, (i) => Match(id: 'c4${i + 1}')),
    ];
  }

  List<List<Map<String, dynamic>>> toJson() =>
      rounds.map((round) => round.map((m) => m.toJson()).toList()).toList();

  static Champions fromJson(List<dynamic> json) => Champions(
        rounds: json
            .map((round) => (round as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}

class Europa {
  List<List<Match>> rounds;

  Europa({List<List<Match>>? rounds}) : rounds = rounds ?? [];

  void instantiate() {
    rounds = [
      List.generate(4, (i) => Match(id: 'e1${i + 1}')),
      List.generate(2, (i) => Match(id: 'e2${i + 1}')),
      List.generate(1, (i) => Match(id: 'e3${i + 1}')),
    ];
  }

  List<List<Map<String, dynamic>>> toJson() =>
      rounds.map((round) => round.map((m) => m.toJson()).toList()).toList();

  static Europa fromJson(List<dynamic> json) => Europa(
        rounds: json
            .map((round) => (round as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}

class Conference {
  List<List<Match>> rounds;

  Conference({List<List<Match>>? rounds}) : rounds = rounds ?? [];

  void instantiate() {
    rounds = [
      List.generate(4, (i) => Match(id: 'f1${i + 1}')),
      List.generate(2, (i) => Match(id: 'f2${i + 1}')),
      List.generate(1, (i) => Match(id: 'f3${i + 1}')),
    ];
  }

  List<List<Map<String, dynamic>>> toJson() =>
      rounds.map((round) => round.map((m) => m.toJson()).toList()).toList();

  static Conference fromJson(List<dynamic> json) => Conference(
        rounds: json
            .map((round) => (round as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}

class Super {
  List<Match> matches;

  Super({List<Match>? matches}) : matches = matches ?? [];

  void instantiate() {
    matches = [
      Match(id: 's1'),
      Match(id: 's2'),
    ];
  }

  List<Map<String, dynamic>> toJson() =>
      matches.map((m) => m.toJson()).toList();

  static Super fromJson(List<dynamic> json) => Super(
        matches:
            json.map((m) => Match.fromJson(m as Map<String, dynamic>)).toList(),
      );
}

class Knockouts {
  Champions champions;
  Europa europa;
  Conference conference;
  Super superCup;

  Knockouts({
    Champions? champions,
    Europa? europa,
    Conference? conference,
    Super? superCup,
  })  : champions = champions ?? Champions(),
        europa = europa ?? Europa(),
        conference = conference ?? Conference(),
        superCup = superCup ?? Super();

  void instantiate() {
    champions.instantiate();
    europa.instantiate();
    conference.instantiate();
    superCup.instantiate();
  }

  // updateMatchScore finds a match by ID and updates its score
  // Returns true if the match was found and updated, false otherwise
  bool updateMatchScore(String matchId, int score1, int score2) {
    // Helper function to search and update in rounds
    bool searchAndUpdate(List<List<Match>> rounds) {
      for (var round in rounds) {
        for (var match in round) {
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
    for (var match in superCup.matches) {
      if (match.id == matchId) {
        match.score1 = score1;
        match.score2 = score2;
        match.done = true;
        return true;
      }
    }

    return false;
  }

  // clearDependentMatches clears all matches that depend on the given match
  // This is used when editing a match result to prevent cascading inconsistencies
  // Returns the list of cleared match IDs
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
      // Clear all subsequent rounds starting from the next round
      for (int roundIndex = startRound + 1;
          roundIndex < rounds.length;
          roundIndex++) {
        // In knockout, each match in round N feeds into match at index N/2 in next round
        // We need to clear matches that could be affected by this chain
        for (var match in rounds[roundIndex]) {
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

    // Check champions rounds
    var location = findMatchLocation(champions.rounds);
    if (location.$1 != null) {
      clearSubsequentRounds(location.$1!, location.$2, location.$3);
      // Also need to check super cup if this was a final
      if (location.$2 == champions.rounds.length - 1) {
        // Champions league final was changed, clear second super cup match
        if (superCup.matches.length > 1 &&
            (superCup.matches[1].teamId1.isNotEmpty ||
                superCup.matches[1].teamId2.isNotEmpty ||
                superCup.matches[1].done)) {
          clearedIds.add(superCup.matches[1].id);
          superCup.matches[1].teamId1 = '';
          superCup.matches[1].teamId2 = '';
          superCup.matches[1].score1 = 0;
          superCup.matches[1].score2 = 0;
          superCup.matches[1].done = false;
        }
      }
      return clearedIds;
    }

    // Check europa rounds
    location = findMatchLocation(europa.rounds);
    if (location.$1 != null) {
      clearSubsequentRounds(location.$1!, location.$2, location.$3);
      // If europa final, clear super cup first match
      if (location.$2 == europa.rounds.length - 1 &&
          superCup.matches.isNotEmpty) {
        if (superCup.matches[0].teamId1.isNotEmpty ||
            superCup.matches[0].teamId2.isNotEmpty ||
            superCup.matches[0].done) {
          clearedIds.add(superCup.matches[0].id);
          superCup.matches[0].teamId1 = '';
          superCup.matches[0].teamId2 = '';
          superCup.matches[0].score1 = 0;
          superCup.matches[0].score2 = 0;
          superCup.matches[0].done = false;
        }
        // And also second super cup match
        if (superCup.matches.length > 1 &&
            (superCup.matches[1].teamId1.isNotEmpty ||
                superCup.matches[1].teamId2.isNotEmpty ||
                superCup.matches[1].done)) {
          clearedIds.add(superCup.matches[1].id);
          superCup.matches[1].teamId1 = '';
          superCup.matches[1].teamId2 = '';
          superCup.matches[1].score1 = 0;
          superCup.matches[1].score2 = 0;
          superCup.matches[1].done = false;
        }
      }
      return clearedIds;
    }

    // Check conference rounds
    location = findMatchLocation(conference.rounds);
    if (location.$1 != null) {
      clearSubsequentRounds(location.$1!, location.$2, location.$3);
      // If conference final, clear super cup first match
      if (location.$2 == conference.rounds.length - 1 &&
          superCup.matches.isNotEmpty) {
        if (superCup.matches[0].teamId1.isNotEmpty ||
            superCup.matches[0].teamId2.isNotEmpty ||
            superCup.matches[0].done) {
          clearedIds.add(superCup.matches[0].id);
          superCup.matches[0].teamId1 = '';
          superCup.matches[0].teamId2 = '';
          superCup.matches[0].score1 = 0;
          superCup.matches[0].score2 = 0;
          superCup.matches[0].done = false;
        }
        // And also second super cup match
        if (superCup.matches.length > 1 &&
            (superCup.matches[1].teamId1.isNotEmpty ||
                superCup.matches[1].teamId2.isNotEmpty ||
                superCup.matches[1].done)) {
          clearedIds.add(superCup.matches[1].id);
          superCup.matches[1].teamId1 = '';
          superCup.matches[1].teamId2 = '';
          superCup.matches[1].score1 = 0;
          superCup.matches[1].score2 = 0;
          superCup.matches[1].done = false;
        }
      }
      return clearedIds;
    }

    // Check super cup matches
    for (int i = 0; i < superCup.matches.length; i++) {
      if (superCup.matches[i].id == matchId) {
        // If first super cup match edited, clear second
        if (i == 0 && superCup.matches.length > 1) {
          if (superCup.matches[1].teamId1.isNotEmpty ||
              superCup.matches[1].teamId2.isNotEmpty ||
              superCup.matches[1].done) {
            clearedIds.add(superCup.matches[1].id);
            superCup.matches[1].teamId1 = '';
            superCup.matches[1].teamId2 = '';
            superCup.matches[1].score1 = 0;
            superCup.matches[1].score2 = 0;
            superCup.matches[1].done = false;
          }
        }
        return clearedIds;
      }
    }

    return clearedIds;
  }

  // update checks for finished matches and moves teams to the next round
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

    // Update the first super cup match if done
    if (superCup.matches[0].done) {
      final winnerId = superCup.matches[0].getWinnerId();
      if (winnerId != null && winnerId.isNotEmpty) {
        superCup.matches[1].teamId1 = winnerId;
      }
    }

    // Move league winners to the super cup
    final leagueFinals = <Match>[];
    if (europa.rounds.isNotEmpty && europa.rounds.last.isNotEmpty) {
      leagueFinals.add(europa.rounds.last[0]);
    }
    if (conference.rounds.isNotEmpty && conference.rounds.last.isNotEmpty) {
      leagueFinals.add(conference.rounds.last[0]);
    }
    for (var leagueFinal in leagueFinals) {
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

  Map<String, dynamic> toJson() => {
        'champions': champions.toJson(),
        'europa': europa.toJson(),
        'conference': conference.toJson(),
        'super': superCup.toJson(),
      };

  /// Creates a deep copy of this Knockouts.
  Knockouts clone() => Knockouts.fromJson(toJson());

  factory Knockouts.fromJson(Map<String, dynamic> json) => Knockouts(
        champions: Champions.fromJson(json['champions'] ?? []),
        europa: Europa.fromJson(json['europa'] ?? []),
        conference: Conference.fromJson(json['conference'] ?? []),
        superCup: Super.fromJson(json['super'] ?? []),
      );
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
      knock.champions.rounds[i][j].tischNr = champTables[i][j];
    }
  }

  const euroTables = [
    [1, 2, 3, 4],
    [5, 6],
    [4]
  ];
  for (int i = 0; i < knock.europa.rounds.length; i++) {
    for (int j = 0; j < knock.europa.rounds[i].length; j++) {
      knock.europa.rounds[i][j].tischNr = euroTables[i][j];
    }
  }

  const confTables = [
    [5, 6, 1, 2],
    [3, 4],
    [5]
  ];
  for (int i = 0; i < knock.conference.rounds.length; i++) {
    for (int j = 0; j < knock.conference.rounds[i].length; j++) {
      knock.conference.rounds[i][j].tischNr = confTables[i][j];
    }
  }

  const superTables = [6, 1];
  for (int i = 0; i < knock.superCup.matches.length; i++) {
    knock.superCup.matches[i].tischNr = superTables[i];
  }
}
