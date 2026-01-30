import 'match.dart';
import 'groups.dart';

class Gruppenphase {
  List<List<Match>> groups;

  Gruppenphase({List<List<Match>>? groups}) : groups = groups ?? [];

  // create expects 6 Groups of 4 teams each at the moment
  static Gruppenphase create(Groups teamGroups) {
    final length = teamGroups.groups.length;
    final groups = List<List<Match>>.generate(length, (_) => []);

    // use pairing pattern to generate matches
    const pattern = [0, 1, 2, 3, 0, 2, 1, 3, 3, 0, 1, 2];
    for (int i = 0; i < length; i++) {
      for (int j = 0; j < pattern.length; j += 2) {
        groups[i].add(Match(
          teamId1: teamGroups.groups[i][pattern[j]],
          teamId2: teamGroups.groups[i][pattern[j + 1]],
          id: 'g${i + 1}${(j ~/ 2) + 1}',
        ));
      }
    }

    // use table blueprint to set the matches desks
    const blueprint = [
      [1, 2, 3, 4, 5, 6],
      [2, 3, 4, 5, 6, 1],
      [3, 4, 5, 6, 1, 2],
      [4, 5, 6, 1, 2, 3],
      [5, 6, 1, 2, 3, 4],
      [6, 1, 2, 3, 4, 5],
    ];

    for (int i = 0; i < blueprint[0].length; i++) {
      for (int j = 0; j < length; j++) {
        groups[j][i].tischNr = blueprint[j][i];
      }
    }

    return Gruppenphase(groups: groups);
  }

  List<Map<String, dynamic>> toJson() => groups
      .map((group) => {'matches': group.map((m) => m.toJson()).toList()})
      .toList();

  static Gruppenphase fromJson(List<dynamic> json) => Gruppenphase(
        groups: json
            .map((group) => (group['matches'] as List)
                .map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList())
            .toList(),
      );
}
