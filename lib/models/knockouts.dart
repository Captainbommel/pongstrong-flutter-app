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

  // update checks for finished matches and moves teams to the next round
  void update() {
    //TODO: improve or remove this check
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
    // Update the first super cup match if done
    if (superCup.matches[0].done) {
      final winnerId = superCup.matches[0].getWinnerId();
      if (winnerId != null && winnerId.isNotEmpty) {
        superCup.matches[1].teamId1 = winnerId;
      }
    }

    // Move league winners to the super cup
    for (var leagueFinal in [
      europa.rounds.last[0],
      conference.rounds.last[0]
    ]) {
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
    if (champions.rounds.last[0].done) {
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
