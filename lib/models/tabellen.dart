import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/scoring.dart';

/// A single row in a group standings table.
class TableRow {
  /// The team's unique identifier.
  String teamId;

  /// Accumulated points from group matches.
  int points;

  /// Cup difference (scored minus conceded).
  int difference;

  /// Total cups scored.
  int cups;

  /// Head-to-head comparison results against other teams.
  List<String> headToHead;

  TableRow({
    this.teamId = '',
    this.points = 0,
    this.difference = 0,
    this.cups = 0,
    List<String>? headToHead,
  }) : headToHead = headToHead ?? List.filled(4, '');

  /// Serialises this row to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'teamId': teamId,
        'punkte': points,
        'differenz': difference,
        'becher': cups,
        'vergleich': headToHead,
      };

  /// Creates a [TableRow] from a Firestore JSON map.
  factory TableRow.fromJson(Map<String, dynamic> json) => TableRow(
        teamId: (json['teamId'] as String?) ?? '',
        points: (json['punkte'] as int?) ?? 0,
        difference: (json['differenz'] as int?) ?? 0,
        cups: (json['becher'] as int?) ?? 0,
        headToHead:
            (json['vergleich'] as List?)?.map((e) => e.toString()).toList() ??
                List.filled(4, ''),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableRow &&
          teamId == other.teamId &&
          points == other.points &&
          difference == other.difference &&
          cups == other.cups &&
          _stringListEquals(headToHead, other.headToHead);

  @override
  int get hashCode =>
      Object.hash(teamId, points, difference, cups, Object.hashAll(headToHead));

  static bool _stringListEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Collection of group standings tables, one per group.
class Tabellen {
  /// Nested list of [TableRow]s, one inner list per group.
  List<List<TableRow>> tables;

  Tabellen({List<List<TableRow>>? tables}) : tables = tables ?? [];

  /// Sorts a group standings table by points, then difference, then cups,
  /// then head-to-head result between the two tied teams.
  ///
  /// When [matches] is provided, the direct match result is used as the
  /// final tiebreaker before falling back to alphabetical team ID.
  static void sortTable(List<TableRow> table, {List<Match>? matches}) {
    table.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      if (a.difference != b.difference) {
        return b.difference.compareTo(a.difference);
      }
      if (a.cups != b.cups) return b.cups.compareTo(a.cups);
      // Head-to-head: check which team won the direct match
      if (matches != null) {
        final h2h = headToHeadResult(a.teamId, b.teamId, matches);
        if (h2h != 0) return h2h;
      }
      return a.teamId.compareTo(b.teamId);
    });
  }

  /// Returns the head-to-head comparison result between [teamA] and [teamB]
  /// from the given [matches].
  ///
  /// Returns a negative value if teamA won (should rank higher),
  /// a positive value if teamB won, or 0 if no decisive result was found.
  static int headToHeadResult(String teamA, String teamB, List<Match> matches) {
    for (final match in matches) {
      if (!match.done) continue;
      final isMatchup = (match.teamId1 == teamA && match.teamId2 == teamB) ||
          (match.teamId1 == teamB && match.teamId2 == teamA);
      if (!isMatchup) continue;

      final winner = determineWinner(match.score1, match.score2);
      if (winner == null) continue;

      final winnerId = winner == 1 ? match.teamId1 : match.teamId2;
      if (winnerId == teamA) return -1; // teamA ranks higher
      if (winnerId == teamB) return 1; // teamB ranks higher
    }
    return 0;
  }

  /// Sorts all standings tables using the corresponding group matches
  /// for head-to-head tiebreaking.
  ///
  /// When [groupMatches] is provided, each element corresponds to the
  /// matches of the group at the same index.
  void sortTables({List<List<Match>>? groupMatches}) {
    for (int i = 0; i < tables.length; i++) {
      final matches = (groupMatches != null && i < groupMatches.length)
          ? groupMatches[i]
          : null;
      sortTable(tables[i], matches: matches);
    }
  }

  /// Serialises all tables to a JSON-compatible structure.
  List<List<Map<String, dynamic>>> toJson() =>
      tables.map((table) => table.map((row) => row.toJson()).toList()).toList();

  /// Creates [Tabellen] from a Firestore JSON list.
  static Tabellen fromJson(List<dynamic> json) => Tabellen(
        tables: json
            .map((table) => (table as List)
                .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
                .toList())
            .toList(),
      );

  /// Creates a deep copy of this Tabellen.
  /// Note: This uses JSON serialization and should be used sparingly for performance reasons.
  Tabellen clone() => Tabellen.fromJson(toJson());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Tabellen) return false;
    if (tables.length != other.tables.length) return false;
    for (int i = 0; i < tables.length; i++) {
      if (tables[i].length != other.tables[i].length) return false;
      for (int j = 0; j < tables[i].length; j++) {
        if (tables[i][j] != other.tables[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        tables.map((t) => Object.hashAll(t)),
      );
}
