import 'package:pongstrong/models/configurations.dart';

import 'match.dart';
import 'groups.dart';

class Gruppenphase {
  List<List<Match>> groups;

  Gruppenphase({List<List<Match>>? groups}) : groups = groups ?? [];

  // create expects groups with equal team counts
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
        groups[j][i].tischNr = tablePattern[j][i];
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
            .map((group) => (group['matches'] as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}
