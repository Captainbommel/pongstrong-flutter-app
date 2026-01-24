class Match {
  String teamId1;
  String teamId2;
  int score1;
  int score2;
  int tischNr;
  String id;
  bool done;

  Match({
    this.teamId1 = '',
    this.teamId2 = '',
    this.score1 = 0,
    this.score2 = 0,
    this.tischNr = 0,
    this.id = '',
    this.done = false,
  });

  // winner gibt das gewinnerteam zurück
  String? getWinnerId() {
    // deathcup
    if (score1 < 0) {
      return teamId1;
    } else if (score2 < 0) {
      return teamId2;
    }
    // normal
    if (score1 > score2) {
      return teamId1;
    } else if (score2 > score1) {
      return teamId2;
    }
    return null; // invalid or tie
  }

  // points gibt die Punkte der beiden beteiligten Teams zurück
  (int, int)? getPoints() {
    if (score1 == 0 && score2 == 0) {
      return null;
    }

    const winner = [3, 2, 4, 3];
    const looser = [0, 1, 0, 1];

    // deathcup
    if (score1 == -1) {
      return (winner[2], looser[2]);
    } else if (score2 == -1) {
      return (looser[2], winner[2]);
    }
    // deathcup overtime
    if (score1 == -2) {
      return (winner[3], looser[3]);
    } else if (score2 == -2) {
      return (looser[3], winner[3]);
    }
    // normal
    if (score1 == 10 && score2 < 10) {
      return (winner[0], looser[0]);
    } else if (score2 == 10 && score1 < 10) {
      return (looser[0], winner[0]);
    }
    // overtime
    if (score1 >= 10 && score2 >= 10 && score1 > score2) {
      return (winner[1], looser[1]);
    } else if (score1 >= 10 && score2 >= 10 && score2 > score1) {
      return (looser[1], winner[1]);
    }
    return null; // invalid scores
  }

  Map<String, dynamic> toJson() => {
        'teamId1': teamId1,
        'teamId2': teamId2,
        'score1': score1,
        'score2': score2,
        'tischnummer': tischNr,
        'id': id,
        'done': done,
      };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        teamId1: json['teamId1'] ?? '',
        teamId2: json['teamId2'] ?? '',
        score1: json['score1'] ?? 0,
        score2: json['score2'] ?? 0,
        tischNr: json['tischnummer'] ?? 0,
        id: json['id'] ?? '',
        done: json['done'] ?? false,
      );
}
