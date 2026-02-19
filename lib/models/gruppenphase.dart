import 'package:pongstrong/models/configurations.dart';
import 'package:pongstrong/models/groups.dart';
import 'package:pongstrong/models/match.dart';

/// The group phase of a tournament, containing all group matches.
class Gruppenphase {
  /// Nested list of matches, one inner list per group.
  List<List<Match>> groups;

  Gruppenphase({List<List<Match>>? groups}) : groups = groups ?? [];

  /// Creates a [Gruppenphase] from team [Groups] using round-robin pairings.
  static Gruppenphase create(Groups teamGroups, {int tableCount = 6}) {
    final groupCount = teamGroups.groups.length;
    final groups = List<List<Match>>.generate(groupCount, (_) => []);

    final teamsPerGroup =
        teamGroups.groups.isNotEmpty ? teamGroups.groups[0].length : 4;
    final matchPattern = Configurations.generateMatchPairings(teamsPerGroup);
    for (int i = 0; i < groupCount; i++) {
      for (int j = 0; j < matchPattern.length; j++) {
        groups[i].add(Match(
          teamId1: teamGroups.groups[i][matchPattern[j][0]],
          teamId2: teamGroups.groups[i][matchPattern[j][1]],
          id: 'g${i + 1}${j + 1}',
        ));
      }
    }

    final teamCount = groupCount * teamsPerGroup;
    final tablePattern = Configurations.generateTableConfiguration(
        groupCount, teamCount, tableCount)!;
    for (int i = 0; i < tablePattern[0].length; i++) {
      for (int j = 0; j < groupCount; j++) {
        groups[j][i].tableNumber = tablePattern[j][i];
      }
    }

    return Gruppenphase(groups: groups);
  }

  List<Map<String, dynamic>> toJson() => groups
      .map((group) => {'matches': group.map((m) => m.toJson()).toList()})
      .toList();

  /// Creates a deep copy of this Gruppenphase.
  Gruppenphase clone() => Gruppenphase.fromJson(toJson());

  static Gruppenphase fromJson(List<dynamic> json) => Gruppenphase(
        groups: json
            .map((group) => ((group as Map<String, dynamic>)['matches'] as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Gruppenphase) return false;
    if (groups.length != other.groups.length) return false;
    for (int i = 0; i < groups.length; i++) {
      if (groups[i].length != other.groups[i].length) return false;
      for (int j = 0; j < groups[i].length; j++) {
        if (groups[i][j] != other.groups[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        groups.map((g) => Object.hashAll(g)),
      );
}
