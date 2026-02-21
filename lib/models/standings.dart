// Group standings evaluation.
//
// Evaluates match results within groups to produce ranked standings tables.
import 'package:pongstrong/models/gruppenphase.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/tabellen.dart';

/// Evaluates a list of [matches] and returns a ranked standings table.
///
/// Builds a [TableRow] for each unique team, aggregating points, cup
/// difference, and total cups from all finished matches.
List<TableRow> evaluate(List<Match> matches) {
  // Count unique teams first
  final uniqueTeams = <String>{};
  for (final match in matches) {
    uniqueTeams.add(match.teamId1);
    uniqueTeams.add(match.teamId2);
  }
  final teamCount = uniqueTeams.length;

  final table = List.generate(teamCount, (_) => TableRow());

  // Build a map of teamId -> table index by scanning all matches
  final teamIndexMap = <String, int>{};
  for (final match in matches) {
    if (!teamIndexMap.containsKey(match.teamId1)) {
      teamIndexMap[match.teamId1] = teamIndexMap.length;
    }
    if (!teamIndexMap.containsKey(match.teamId2)) {
      teamIndexMap[match.teamId2] = teamIndexMap.length;
    }
  }

  // Set team IDs in table based on their assigned indices
  for (final entry in teamIndexMap.entries) {
    table[entry.value].teamId = entry.key;
  }

  // Calculate standings for each finished match
  for (final match in matches) {
    if (match.done) {
      final t1 = teamIndexMap[match.teamId1]!;
      final t2 = teamIndexMap[match.teamId2]!;

      final points = match.getPoints();
      if (points != null) {
        table[t1].points += points.$1;
        table[t2].points += points.$2;
      }

      int cups(int n) {
        switch (n) {
          case -1:
            return 10;
          case -2:
            return 16;
          default:
            return n;
        }
      }

      if (points != null) {
        table[t1].difference += cups(match.score1) - cups(match.score2);
        table[t2].difference += cups(match.score2) - cups(match.score1);

        table[t1].cups += cups(match.score1);
        table[t2].cups += cups(match.score2);
      }
    }
  }

  return table;
}

/// Evaluates all groups in a [Gruppenphase] and returns sorted [Tabellen].
///
/// Uses head-to-head match results as the final tiebreaker when points,
/// cup difference, and total cups are all equal.
Tabellen evalGruppen(Gruppenphase gruppenphase) {
  final tables = <List<TableRow>>[];
  for (final group in gruppenphase.groups) {
    tables.add(evaluate(group));
  }
  final tabellen = Tabellen(tables: tables);
  tabellen.sortTables(groupMatches: gruppenphase.groups);
  return tabellen;
}
