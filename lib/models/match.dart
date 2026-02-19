import 'package:pongstrong/models/evaluation.dart';

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
  // Uses modular logic from evaluation.dart
  String? getWinnerId() {
    final winner = determineWinner(score1, score2);

    if (winner == 1) {
      return teamId1;
    } else if (winner == 2) {
      return teamId2;
    }

    return null;
  }

  // points gibt die Punkte der beiden beteiligten Teams zurück
  // Uses modular logic from evaluation.dart
  (int, int)? getPoints() {
    return calculatePoints(score1, score2);
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
        teamId1: (json['teamId1'] as String?) ?? '',
        teamId2: (json['teamId2'] as String?) ?? '',
        score1: (json['score1'] as int?) ?? 0,
        score2: (json['score2'] as int?) ?? 0,
        tischNr: (json['tischnummer'] as int?) ?? 0,
        id: (json['id'] as String?) ?? '',
        done: (json['done'] as bool?) ?? false,
      );
}
