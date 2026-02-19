import 'package:pongstrong/models/scoring.dart';

/// A single match between two teams with score tracking.
class Match {
  String teamId1;
  String teamId2;
  int score1;
  int score2;
  int tableNumber;
  String id;
  bool done;

  Match({
    this.teamId1 = '',
    this.teamId2 = '',
    this.score1 = 0,
    this.score2 = 0,
    this.tableNumber = 0,
    this.id = '',
    this.done = false,
  });

  /// Returns the winner's team ID, or null if undecided.
  String? getWinnerId() {
    final winner = determineWinner(score1, score2);

    if (winner == 1) {
      return teamId1;
    } else if (winner == 2) {
      return teamId2;
    }

    return null;
  }

  /// Returns (team1Points, team2Points) or null if match is not finished.
  (int, int)? getPoints() {
    return calculatePoints(score1, score2);
  }

  /// Serialises this match to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'teamId1': teamId1,
        'teamId2': teamId2,
        'score1': score1,
        'score2': score2,
        'tischnummer': tableNumber,
        'id': id,
        'done': done,
      };

  /// Creates a [Match] from a Firestore JSON map.
  factory Match.fromJson(Map<String, dynamic> json) => Match(
        teamId1: (json['teamId1'] as String?) ?? '',
        teamId2: (json['teamId2'] as String?) ?? '',
        score1: (json['score1'] as int?) ?? 0,
        score2: (json['score2'] as int?) ?? 0,
        tableNumber: (json['tischnummer'] as int?) ?? 0,
        id: (json['id'] as String?) ?? '',
        done: (json['done'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Match &&
          id == other.id &&
          teamId1 == other.teamId1 &&
          teamId2 == other.teamId2 &&
          score1 == other.score1 &&
          score2 == other.score2 &&
          tableNumber == other.tableNumber &&
          done == other.done;

  @override
  int get hashCode =>
      Object.hash(id, teamId1, teamId2, score1, score2, tableNumber, done);
}
