import '../models/models.dart';

class ImportService {
  /// Parse teams from JSON data
  /// Expected JSON format (nested array of groups):
  /// [
  ///   [
  ///     {"name": "Thunder", "mem1": "Alice", "mem2": "Bob"},
  ///     {"name": "Lightning", "mem1": "Charlie", "mem2": "Diana"},
  ///     ...
  ///   ],
  ///   [next group],
  ///   ...
  /// ]
  /// OR alternative format with teams and groups objects:
  /// {
  ///   "teams": [...],
  ///   "groups": [["team_id1", ...], ...]
  /// }
  static (List<Team>, Groups) parseTeamsFromJson(dynamic jsonData) {
    final allTeams = <Team>[];
    final groupTeamIds = <List<String>>[];

    // Check if it's the nested array format (array of groups)
    if (jsonData is List) {
      for (int groupIndex = 0; groupIndex < jsonData.length; groupIndex++) {
        final group = jsonData[groupIndex] as List;
        final groupIds = <String>[];

        for (int teamIndex = 0; teamIndex < group.length; teamIndex++) {
          final teamJson = group[teamIndex] as Map<String, dynamic>;
          final teamId = 'team_${groupIndex}_$teamIndex';

          final team = Team(
            id: teamId,
            name: teamJson['name'] as String,
            mem1: teamJson['mem1'] as String? ?? '',
            mem2: teamJson['mem2'] as String? ?? '',
          );
          allTeams.add(team);
          groupIds.add(teamId);
        }
        groupTeamIds.add(groupIds);
      }
    } else if (jsonData is Map<String, dynamic>) {
      // Handle the alternative format with separate teams and groups
      final teamsList = jsonData['teams'] as List;

      for (var teamJson in teamsList) {
        final team = Team(
          id: teamJson['id'] as String,
          name: teamJson['name'] as String,
          mem1: teamJson['mem1'] as String? ?? '',
          mem2: teamJson['mem2'] as String? ?? '',
        );
        allTeams.add(team);
      }

      final groupsList = (jsonData['groups'] as List)
          .map((group) => (group as List).map((id) => id.toString()).toList())
          .toList();
      groupTeamIds.addAll(groupsList);
    }

    final groups = Groups(groups: groupTeamIds);
    return (allTeams, groups);
  }
}
