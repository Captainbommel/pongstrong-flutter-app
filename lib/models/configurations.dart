import 'package:pongstrong/utils/app_logger.dart';

class Configurations {
  /// Generates round-robin match pairings for any team count bigger than 1.
  static List<List<int>> generateMatchPairings(int teamCount) {
    if (teamCount < 2) {
      throw ArgumentError('Team count must be at least 2.');
    }

    final List<List<int>> pairings = [];
    final List<int> teams = List.generate(teamCount, (i) => i);
    var effectiveCount = teamCount;
    bool hasDummy = false;
    if (effectiveCount % 2 != 0) {
      teams.add(-1); // Dummy
      hasDummy = true;
      effectiveCount++;
    }

    final int rounds = effectiveCount - 1;
    final int matchesPerRound = effectiveCount ~/ 2;
    for (int round = 0; round < rounds; round++) {
      for (int i = 0; i < matchesPerRound; i++) {
        final int t1 = teams[i];
        final int t2 = teams[effectiveCount - 1 - i];
        if (t1 == -1 || t2 == -1) {
          // Dummy round
          pairings.add([t1, t2]);
        } else {
          pairings.add([t1, t2]);
        }
      }
      // Rotate teams for next round
      teams.insert(1, teams.removeLast());
    }

    // Remove dummy rounds from pairings
    if (hasDummy) {
      pairings.removeWhere((pair) => pair.contains(-1));
    }

    return pairings;
  }

  /// Generates table configuration for groups with even distribution.
  static List<List<int>>? generateTableConfiguration(
    int groupCount,
    int teamCount,
    int tableCount,
  ) {
    // Evenly distribute teams into groups
    if (teamCount % groupCount != 0) return null;
    final int groupSize = teamCount ~/ groupCount;

    // Calculate matches per group: n*(n-1)/2
    final int matchesPerGroup = groupSize * (groupSize - 1) ~/ 2;
    final List<List<int>> configuration = List.generate(
      groupCount,
      (_) => List.filled(matchesPerGroup, 0),
    );

    if (tableCount > groupCount) {
      Logger.warning(
        "More tables than groups. Matchmaking will be suboptimal.",
        tag: 'Configurations',
      );
    }

    int tableId = 0;
    int periodicTableNumber() {
      return tableId = (tableId % tableCount) + 1;
    }

    for (int i = 0; i < groupCount; i++) {
      for (int j = 0; j < matchesPerGroup; j++) {
        configuration[i][j] = periodicTableNumber();
      }
      tableId = i % tableCount + 1;
    }

    return configuration;
  }
}
