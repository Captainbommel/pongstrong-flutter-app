import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/services/import_service.dart';

void main() {
  // ==========================================================================
  group('parseTeamsFromJson – nested array format', () {
    test('parses groups of teams correctly', () {
      final jsonData = [
        [
          {'name': 'Thunder', 'mem1': 'Alice', 'mem2': 'Bob'},
          {'name': 'Lightning', 'mem1': 'Charlie', 'mem2': 'Diana'},
        ],
        [
          {'name': 'Storm', 'mem1': 'Eve', 'mem2': 'Frank'},
        ],
      ];

      final (teams, groups) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams.length, 3);
      expect(teams[0].name, 'Thunder');
      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
      expect(teams[0].id, 'team_0_0');
      expect(teams[1].id, 'team_0_1');
      expect(teams[2].id, 'team_1_0');

      expect(groups.groups.length, 2);
      expect(groups.groups[0], ['team_0_0', 'team_0_1']);
      expect(groups.groups[1], ['team_1_0']);
    });

    test('handles missing mem1/mem2 fields gracefully', () {
      final jsonData = [
        [
          {'name': 'Solo'},
        ],
      ];

      final (teams, groups) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams.length, 1);
      expect(teams[0].name, 'Solo');
      expect(teams[0].member1, '');
      expect(teams[0].member2, '');
      expect(groups.groups.length, 1);
    });

    test('handles empty groups list', () {
      final jsonData = <List>[];

      final (teams, groups) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams, isEmpty);
      expect(groups.groups, isEmpty);
    });
  });

  // ==========================================================================
  group('parseTeamsFromJson – object format', () {
    test('parses teams and groups from object format', () {
      final jsonData = {
        'teams': [
          {'id': 't1', 'name': 'Alpha', 'mem1': 'A1', 'mem2': 'A2'},
          {'id': 't2', 'name': 'Beta', 'mem1': 'B1', 'mem2': 'B2'},
          {'id': 't3', 'name': 'Gamma', 'mem1': 'G1', 'mem2': 'G2'},
        ],
        'groups': [
          ['t1', 't2'],
          ['t3'],
        ],
      };

      final (teams, groups) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams.length, 3);
      expect(teams[0].id, 't1');
      expect(teams[0].name, 'Alpha');
      expect(groups.groups.length, 2);
      expect(groups.groups[0], ['t1', 't2']);
      expect(groups.groups[1], ['t3']);
    });

    test('handles missing mem fields in object format', () {
      final jsonData = {
        'teams': [
          {'id': 't1', 'name': 'Solo'},
        ],
        'groups': [
          ['t1'],
        ],
      };

      final (teams, _) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams[0].member1, '');
      expect(teams[0].member2, '');
    });
  });

  // ==========================================================================
  group('parseTeamsFlatFromJson – flat list', () {
    test('parses flat list of teams', () {
      final jsonData = [
        {'name': 'Alpha', 'mem1': 'A1', 'mem2': 'A2'},
        {'name': 'Beta', 'mem1': 'B1', 'mem2': 'B2'},
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams.length, 2);
      expect(teams[0].name, 'Alpha');
      expect(teams[0].id, 'team_0');
      expect(teams[1].name, 'Beta');
      expect(teams[1].id, 'team_1');
    });

    test('uses id from JSON when provided', () {
      final jsonData = [
        {'id': 'custom_id', 'name': 'Alpha', 'mem1': 'A1', 'mem2': 'A2'},
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams[0].id, 'custom_id');
    });

    test('handles missing mem fields', () {
      final jsonData = [
        {'name': 'Solo'},
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams[0].member1, '');
      expect(teams[0].member2, '');
    });

    test('handles empty list', () {
      final jsonData = <Map<String, dynamic>>[];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams, isEmpty);
    });
  });

  // ==========================================================================
  group('parseTeamsFlatFromJson – nested list flattening', () {
    test('flattens group-structured list into flat team list', () {
      final jsonData = [
        [
          {'name': 'A', 'mem1': 'a1', 'mem2': 'a2'},
          {'name': 'B', 'mem1': 'b1', 'mem2': 'b2'},
        ],
        [
          {'name': 'C', 'mem1': 'c1', 'mem2': 'c2'},
        ],
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams.length, 3);
      expect(teams[0].name, 'A');
      expect(teams[0].id, 'team_0');
      expect(teams[1].name, 'B');
      expect(teams[1].id, 'team_1');
      expect(teams[2].name, 'C');
      expect(teams[2].id, 'team_2');
    });
  });

  // ==========================================================================
  group('parseTeamsFlatFromJson – object format', () {
    test('parses teams from object with teams key', () {
      final jsonData = {
        'teams': [
          {'id': 't1', 'name': 'Alpha'},
          {'name': 'Beta'},
        ],
      };

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams.length, 2);
      expect(teams[0].id, 't1');
      expect(teams[0].name, 'Alpha');
      expect(teams[1].id, 'team_1');
      expect(teams[1].name, 'Beta');
    });
  });
}
