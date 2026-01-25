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
    if (champions.rounds[0][0].teamId1.isEmpty &&
        champions.rounds[0][0].teamId2.isEmpty) {
      return;
    }

    //TODO: the same team gets moved multiple times into the next round

    // champ
    for (int i = 0; i < champions.rounds.length - 1; i++) {
      for (int j = 0; j < champions.rounds[i].length; j++) {
        if (champions.rounds[i][j].done &&
            champions.rounds[i + 1][j ~/ 2].teamId1.isEmpty) {
          champions.rounds[i + 1][j ~/ 2].teamId1 =
              champions.rounds[i][j].getWinnerId()!;
        } else if (champions.rounds[i][j].done &&
            champions.rounds[i + 1][j ~/ 2].teamId2.isEmpty) {
          champions.rounds[i + 1][j ~/ 2].teamId2 =
              champions.rounds[i][j].getWinnerId()!;
        }
      }
    }

    // euro
    for (int i = 0; i < europa.rounds.length - 1; i++) {
      for (int j = 0; j < europa.rounds[i].length; j++) {
        if (europa.rounds[i][j].done &&
            europa.rounds[i + 1][j ~/ 2].teamId1.isEmpty) {
          europa.rounds[i + 1][j ~/ 2].teamId1 =
              europa.rounds[i][j].getWinnerId()!;
        } else if (europa.rounds[i][j].done &&
            europa.rounds[i + 1][j ~/ 2].teamId2.isEmpty) {
          europa.rounds[i + 1][j ~/ 2].teamId2 =
              europa.rounds[i][j].getWinnerId()!;
        }
      }
    }

    // conf
    for (int i = 0; i < conference.rounds.length - 1; i++) {
      for (int j = 0; j < conference.rounds[i].length; j++) {
        if (conference.rounds[i][j].done &&
            conference.rounds[i + 1][j ~/ 2].teamId1.isEmpty) {
          conference.rounds[i + 1][j ~/ 2].teamId1 =
              conference.rounds[i][j].getWinnerId()!;
        } else if (conference.rounds[i][j].done &&
            conference.rounds[i + 1][j ~/ 2].teamId2.isEmpty) {
          conference.rounds[i + 1][j ~/ 2].teamId2 =
              conference.rounds[i][j].getWinnerId()!;
        }
      }
    }

    // super
    if (superCup.matches[0].done) {
      superCup.matches[1].teamId1 = superCup.matches[0].getWinnerId()!;
    }

    // move league winners to super
    if (europa.rounds.last[0].done) {
      final winnerId = europa.rounds.last[0].getWinnerId()!;
      if (superCup.matches[0].teamId1.isEmpty) {
        superCup.matches[0].teamId1 = winnerId;
      } else if (superCup.matches[0].teamId2.isEmpty) {
        superCup.matches[0].teamId2 = winnerId;
      }
    }
    if (conference.rounds.last[0].done) {
      final winnerId = conference.rounds.last[0].getWinnerId()!;
      if (superCup.matches[0].teamId1.isEmpty) {
        superCup.matches[0].teamId1 = winnerId;
      } else if (superCup.matches[0].teamId2.isEmpty) {
        superCup.matches[0].teamId2 = winnerId;
      }
    }
    if (champions.rounds.last[0].done) {
      final winnerId = champions.rounds.last[0].getWinnerId()!;
      if (superCup.matches[1].teamId2.isEmpty &&
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
