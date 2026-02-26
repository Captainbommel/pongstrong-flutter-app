import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/import_service.dart';

void main() {
  // ==========================================================================
  // JSON TEAM PARSING (existing tests)
  // ==========================================================================

  group('parseTeamsFromJson – nested array format', () {
    test('parses groups of teams correctly', () {
      final jsonData = [
        [
          {'name': 'Thunder', 'member1': 'Alice', 'member2': 'Bob'},
          {'name': 'Lightning', 'member1': 'Charlie', 'member2': 'Diana'},
        ],
        [
          {'name': 'Storm', 'member1': 'Eve', 'member2': 'Frank'},
        ],
      ];

      final (teams, groups) = ImportService.parseTeamsFromJson(jsonData);

      expect(teams.length, 3);
      expect(teams[0].name, 'Thunder');
      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
      expect(teams[0].id, 'team-0-0');
      expect(teams[1].id, 'team-0-1');
      expect(teams[2].id, 'team-1-0');

      expect(groups.groups.length, 2);
      expect(groups.groups[0], ['team-0-0', 'team-0-1']);
      expect(groups.groups[1], ['team-1-0']);
    });

    test('handles missing member1/member2 fields gracefully', () {
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
          {'id': 't1', 'name': 'Alpha', 'member1': 'A1', 'member2': 'A2'},
          {'id': 't2', 'name': 'Beta', 'member1': 'B1', 'member2': 'B2'},
          {'id': 't3', 'name': 'Gamma', 'member1': 'G1', 'member2': 'G2'},
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
        {'name': 'Alpha', 'member1': 'A1', 'member2': 'A2'},
        {'name': 'Beta', 'member1': 'B1', 'member2': 'B2'},
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams.length, 2);
      expect(teams[0].name, 'Alpha');
      expect(teams[0].id, 'team-0');
      expect(teams[1].name, 'Beta');
      expect(teams[1].id, 'team-1');
    });

    test('uses id from JSON when provided', () {
      final jsonData = [
        {'id': 'custom_id', 'name': 'Alpha', 'member1': 'A1', 'member2': 'A2'},
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
          {'name': 'A', 'member1': 'a1', 'member2': 'a2'},
          {'name': 'B', 'member1': 'b1', 'member2': 'b2'},
        ],
        [
          {'name': 'C', 'member1': 'c1', 'member2': 'c2'},
        ],
      ];

      final teams = ImportService.parseTeamsFlatFromJson(jsonData);

      expect(teams.length, 3);
      expect(teams[0].name, 'A');
      expect(teams[0].id, 'team-0');
      expect(teams[1].name, 'B');
      expect(teams[1].id, 'team-1');
      expect(teams[2].name, 'C');
      expect(teams[2].id, 'team-2');
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
      expect(teams[1].id, 'team-1');
      expect(teams[1].name, 'Beta');
    });
  });

  // ==========================================================================
  // CSV TEAM PARSING
  // ==========================================================================

  group('parseTeamsFromCsv – grouped format', () {
    test('parses teams with group assignments', () {
      const csv = 'group,name,member1,member2\n'
          '1,Thunder,Alice,Bob\n'
          '1,Lightning,Charlie,Diana\n'
          '2,Storm,Eve,Frank\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 3);
      expect(teams[0].name, 'Thunder');
      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
      expect(teams[1].name, 'Lightning');
      expect(teams[2].name, 'Storm');

      expect(groups.groups.length, 2);
      expect(groups.groups[0].length, 2); // group 1 has 2 teams
      expect(groups.groups[1].length, 1); // group 2 has 1 team
    });

    test('handles missing member1/member2 columns', () {
      const csv = 'group,name\n'
          '1,Solo\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 1);
      expect(teams[0].name, 'Solo');
      expect(teams[0].member1, '');
      expect(teams[0].member2, '');
      expect(groups.groups.length, 1);
    });

    test('handles empty CSV', () {
      const csv = '';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams, isEmpty);
      expect(groups.groups, isEmpty);
    });

    test('throws when name column is missing', () {
      const csv = 'group,player1,player2\n'
          '1,Alice,Bob\n';

      expect(
        () => ImportService.parseTeamsFromCsv(csv),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when group column is missing', () {
      const csv = 'name,member1,member2\n'
          'Thunder,Alice,Bob\n';

      expect(
        () => ImportService.parseTeamsFromCsv(csv),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles multiple groups sorted correctly', () {
      const csv = 'group,name,member1,member2\n'
          '3,Team C,c1,c2\n'
          '1,Team A,a1,a2\n'
          '2,Team B,b1,b2\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 3);
      expect(groups.groups.length, 3);
      // Groups ordered by first appearance: 3 first, then 1, then 2
      final group0TeamIds = groups.groups[0];
      final group0Team = teams.firstWhere((t) => t.id == group0TeamIds[0]);
      expect(group0Team.name, 'Team C');
    });

    test('handles text group labels', () {
      const csv = 'group,name,member1,member2\n'
          'Gruppe A,Thunder,Alice,Bob\n'
          'Gruppe A,Lightning,Charlie,Diana\n'
          'Gruppe B,Storm,Eve,Frank\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 3);
      expect(groups.groups.length, 2);
      expect(groups.groups[0].length, 2); // Gruppe A
      expect(groups.groups[1].length, 1); // Gruppe B
    });

    test('parses member1/member2 headers', () {
      const csv = 'group,name,member1,member2\n'
          '1,Thunder,Alice,Bob\n';

      final (teams, _) = ImportService.parseTeamsFromCsv(csv);

      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
    });

    test('handles quoted fields with commas', () {
      const csv = 'group,name,member1,member2\n'
          '1,"Team, One",Alice,Bob\n';

      final (teams, _) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 1);
      expect(teams[0].name, 'Team, One');
    });

    test('handles quoted fields with double quotes', () {
      const csv = 'group,name,member1,member2\n'
          '1,"Team ""Best""",Alice,Bob\n';

      final (teams, _) = ImportService.parseTeamsFromCsv(csv);

      expect(teams[0].name, 'Team "Best"');
    });

    test('handles Windows-style line endings', () {
      const csv = 'group,name,member1,member2\r\n'
          '1,Thunder,Alice,Bob\r\n'
          '2,Storm,Eve,Frank\r\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 2);
      expect(groups.groups.length, 2);
    });

    test('skips empty lines', () {
      const csv = 'group,name,member1,member2\n'
          '\n'
          '1,Thunder,Alice,Bob\n'
          '\n'
          '2,Storm,Eve,Frank\n';

      final (teams, groups) = ImportService.parseTeamsFromCsv(csv);

      expect(teams.length, 2);
      expect(groups.groups.length, 2);
    });
  });

  // ==========================================================================
  group('parseTeamsFlatFromCsv – flat format', () {
    test('parses flat team list', () {
      const csv = 'name,member1,member2\n'
          'Thunder,Alice,Bob\n'
          'Lightning,Charlie,Diana\n';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams.length, 2);
      expect(teams[0].name, 'Thunder');
      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
      expect(teams[0].id, 'team-0');
      expect(teams[1].name, 'Lightning');
      expect(teams[1].id, 'team-1');
    });

    test('handles missing mem columns', () {
      const csv = 'name\n'
          'Solo\n';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams.length, 1);
      expect(teams[0].name, 'Solo');
      expect(teams[0].member1, '');
      expect(teams[0].member2, '');
    });

    test('handles empty CSV', () {
      const csv = '';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams, isEmpty);
    });

    test('throws when name column is missing', () {
      const csv = 'player1,player2\n'
          'Alice,Bob\n';

      expect(
        () => ImportService.parseTeamsFlatFromCsv(csv),
        throwsA(isA<FormatException>()),
      );
    });

    test('ignores group column if present', () {
      // A CSV with a group column should still parse flat (without errors)
      const csv = 'group,name,member1,member2\n'
          '1,Thunder,Alice,Bob\n'
          '2,Lightning,Charlie,Diana\n';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams.length, 2);
      expect(teams[0].name, 'Thunder');
      expect(teams[1].name, 'Lightning');
    });

    test('handles header with different casing', () {
      const csv = 'NAME,MEMBER1,MEMBER2\n'
          'Thunder,Alice,Bob\n';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams.length, 1);
      expect(teams[0].name, 'Thunder');
    });

    test('parses member1/member2 headers', () {
      const csv = 'name,member1,member2\n'
          'Thunder,Alice,Bob\n';

      final teams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(teams[0].member1, 'Alice');
      expect(teams[0].member2, 'Bob');
    });
  });

  // ==========================================================================
  // CSV EXPORT
  // ==========================================================================

  group('exportTeamsToCsv', () {
    test('exports teams with groups to CSV', () {
      final teams = [
        Team(id: 't1', name: 'Thunder', member1: 'Alice', member2: 'Bob'),
        Team(id: 't2', name: 'Lightning', member1: 'Charlie', member2: 'Diana'),
        Team(id: 't3', name: 'Storm', member1: 'Eve', member2: 'Frank'),
      ];
      final groups = Groups(groups: [
        ['t1', 't2'],
        ['t3'],
      ]);

      final csv = ImportService.exportTeamsToCsv(teams, groups);

      final lines = csv.trim().split('\n');
      expect(lines.length, 4); // header + 3 teams
      expect(lines[0], 'group,name,member1,member2');
      expect(lines[1], '1,Thunder,Alice,Bob');
      expect(lines[2], '1,Lightning,Charlie,Diana');
      expect(lines[3], '2,Storm,Eve,Frank');
    });

    test('escapes names with commas', () {
      final teams = [
        Team(id: 't1', name: 'Team, One', member1: 'A', member2: 'B'),
      ];
      final groups = Groups(groups: [
        ['t1'],
      ]);

      final csv = ImportService.exportTeamsToCsv(teams, groups);

      expect(csv.contains('"Team, One"'), isTrue);
    });

    test('escapes names with double quotes', () {
      final teams = [
        Team(id: 't1', name: 'Team "Best"', member1: 'A', member2: 'B'),
      ];
      final groups = Groups(groups: [
        ['t1'],
      ]);

      final csv = ImportService.exportTeamsToCsv(teams, groups);

      expect(csv.contains('"Team ""Best"""'), isTrue);
    });
  });

  // ==========================================================================
  group('exportTeamsFlatToCsv', () {
    test('exports flat team list to CSV', () {
      final teams = [
        Team(id: 't1', name: 'Thunder', member1: 'Alice', member2: 'Bob'),
        Team(id: 't2', name: 'Lightning', member1: 'Charlie', member2: 'Diana'),
      ];

      final csv = ImportService.exportTeamsFlatToCsv(teams);

      final lines = csv.trim().split('\n');
      expect(lines.length, 3); // header + 2 teams
      expect(lines[0], 'name,member1,member2');
      expect(lines[1], 'Thunder,Alice,Bob');
      expect(lines[2], 'Lightning,Charlie,Diana');
    });

    test('handles empty team list', () {
      final csv = ImportService.exportTeamsFlatToCsv([]);

      final lines = csv.trim().split('\n');
      expect(lines.length, 1); // header only
      expect(lines[0], 'name,member1,member2');
    });
  });

  // ==========================================================================
  // CSV ROUND-TRIP (export → import)
  // ==========================================================================

  group('CSV round-trip', () {
    test('grouped export then import preserves data', () {
      final originalTeams = [
        Team(id: 't1', name: 'Thunder', member1: 'Alice', member2: 'Bob'),
        Team(id: 't2', name: 'Lightning', member1: 'Charlie', member2: 'Diana'),
        Team(id: 't3', name: 'Storm', member1: 'Eve', member2: 'Frank'),
      ];
      final originalGroups = Groups(groups: [
        ['t1', 't2'],
        ['t3'],
      ]);

      final csv = ImportService.exportTeamsToCsv(originalTeams, originalGroups);
      final (importedTeams, importedGroups) =
          ImportService.parseTeamsFromCsv(csv);

      expect(importedTeams.length, originalTeams.length);
      expect(importedGroups.groups.length, originalGroups.groups.length);
      expect(importedGroups.groups[0].length, originalGroups.groups[0].length);
      expect(importedGroups.groups[1].length, originalGroups.groups[1].length);

      // Names should match in order
      for (int i = 0; i < originalTeams.length; i++) {
        expect(importedTeams[i].name, originalTeams[i].name);
        expect(importedTeams[i].member1, originalTeams[i].member1);
        expect(importedTeams[i].member2, originalTeams[i].member2);
      }
    });

    test('flat export then import preserves data', () {
      final originalTeams = [
        Team(id: 't1', name: 'Thunder', member1: 'Alice', member2: 'Bob'),
        Team(id: 't2', name: 'Storm', member1: 'Eve', member2: 'Frank'),
      ];

      final csv = ImportService.exportTeamsFlatToCsv(originalTeams);
      final importedTeams = ImportService.parseTeamsFlatFromCsv(csv);

      expect(importedTeams.length, originalTeams.length);
      for (int i = 0; i < originalTeams.length; i++) {
        expect(importedTeams[i].name, originalTeams[i].name);
        expect(importedTeams[i].member1, originalTeams[i].member1);
        expect(importedTeams[i].member2, originalTeams[i].member2);
      }
    });
  });

  // ==========================================================================
  // SNAPSHOT DETECTION
  // ==========================================================================

  group('isSnapshotJson', () {
    test('returns true for valid snapshot', () {
      final data = {
        'teams': [],
        'matchQueue': {'waiting': [], 'playing': []},
        'gruppenphase': [],
        'tabellen': [],
        'knockouts': {},
      };
      expect(ImportService.isSnapshotJson(data), isTrue);
    });

    test('returns false for team-only JSON', () {
      final data = [
        {'name': 'Team A'}
      ];
      expect(ImportService.isSnapshotJson(data), isFalse);
    });

    test('returns false for Map missing required keys', () {
      final data = {'teams': [], 'extra': 'data'};
      expect(ImportService.isSnapshotJson(data), isFalse);
    });

    test('returns false for non-map types', () {
      expect(ImportService.isSnapshotJson('string'), isFalse);
      expect(ImportService.isSnapshotJson(42), isFalse);
      expect(ImportService.isSnapshotJson(null), isFalse);
    });
  });

  // ==========================================================================
  // SNAPSHOT PARSING
  // ==========================================================================

  group('parseSnapshotFromJson', () {
    test('parses a minimal snapshot', () {
      final data = {
        'teams': [
          {'id': 't1', 'name': 'Alpha', 'member1': 'A1', 'member2': 'A2'},
        ],
        'matchQueue': {'waiting': [], 'playing': []},
        'gruppenphase': [],
        'tabellen': [],
        'knockouts': {
          'gold': [],
          'silver': [],
          'bronze': [],
          'extra': [],
        },
        'currentTournamentId': 'test_tournament',
        'isKnockoutMode': false,
        'tournamentStyle': 'groupsAndKnockouts',
        'selectedRuleset': 'bmt-cup',
      };

      final snapshot = ImportService.parseSnapshotFromJson(data);

      expect(snapshot.teams.length, 1);
      expect(snapshot.teams[0].name, 'Alpha');
      expect(snapshot.matchQueue.waiting, isEmpty);
      expect(snapshot.matchQueue.playing, isEmpty);
      expect(snapshot.gruppenphase.groups, isEmpty);
      expect(snapshot.tabellen.tables, isEmpty);
      expect(snapshot.currentTournamentId, 'test_tournament');
      expect(snapshot.isKnockoutMode, isFalse);
      expect(snapshot.tournamentStyle, 'groupsAndKnockouts');
      expect(snapshot.selectedRuleset, 'bmt-cup');
    });

    test('parses a snapshot with match data', () {
      final data = {
        'teams': [
          {'id': 't1', 'name': 'Alpha', 'member1': 'A1', 'member2': 'A2'},
          {'id': 't2', 'name': 'Beta', 'member1': 'B1', 'member2': 'B2'},
        ],
        'matchQueue': {
          'waiting': [
            [
              {
                'teamId1': 't1',
                'teamId2': 't2',
                'score1': 0,
                'score2': 0,
                'tischnummer': 1,
                'id': 'g11',
                'done': false,
              }
            ]
          ],
          'playing': [],
        },
        'gruppenphase': [
          {
            'matches': [
              {
                'teamId1': 't1',
                'teamId2': 't2',
                'score1': 0,
                'score2': 0,
                'tischnummer': 1,
                'id': 'g11',
                'done': false,
              }
            ]
          },
        ],
        'tabellen': [
          [
            {
              'teamId': 't1',
              'punkte': 0,
              'differenz': 0,
              'becher': 0,
              'vergleich': ['', '', '', ''],
            },
            {
              'teamId': 't2',
              'punkte': 0,
              'differenz': 0,
              'becher': 0,
              'vergleich': ['', '', '', ''],
            },
          ],
        ],
        'knockouts': {
          'gold': [],
          'silver': [],
          'bronze': [],
          'extra': [],
        },
        'currentTournamentId': 'test_id',
        'isKnockoutMode': false,
        'tournamentStyle': 'groupsAndKnockouts',
        'selectedRuleset': null,
      };

      final snapshot = ImportService.parseSnapshotFromJson(data);

      expect(snapshot.teams.length, 2);
      expect(snapshot.matchQueue.waiting.length, 1);
      expect(snapshot.matchQueue.waiting[0].length, 1);
      expect(snapshot.matchQueue.waiting[0][0].id, 'g11');
      expect(snapshot.gruppenphase.groups.length, 1);
      expect(snapshot.gruppenphase.groups[0].length, 1);
      expect(snapshot.tabellen.tables.length, 1);
      expect(snapshot.tabellen.tables[0].length, 2);
      expect(snapshot.selectedRuleset, isNull);
    });

    test('handles missing optional fields with defaults', () {
      final data = {
        'teams': [],
        'matchQueue': {'waiting': [], 'playing': []},
        'gruppenphase': [],
        'tabellen': [],
        'knockouts': {
          'gold': [],
          'silver': [],
          'bronze': [],
          'extra': [],
        },
      };

      final snapshot = ImportService.parseSnapshotFromJson(data);

      expect(snapshot.currentTournamentId, '');
      expect(snapshot.isKnockoutMode, isFalse);
      expect(snapshot.tournamentStyle, 'groupsAndKnockouts');
      expect(snapshot.selectedRuleset, isNull);
    });
  });

  // ==========================================================================
  // SNAPSHOT ROUND-TRIP (toJson → parseSnapshotFromJson)
  // ==========================================================================

  group('snapshot round-trip', () {
    test('export then import preserves teams and matches', () {
      // Build a small tournament state manually
      final teams = [
        Team(id: 't1', name: 'Alpha', member1: 'A1', member2: 'A2'),
        Team(id: 't2', name: 'Beta', member1: 'B1', member2: 'B2'),
        Team(id: 't3', name: 'Gamma', member1: 'G1', member2: 'G2'),
        Team(id: 't4', name: 'Delta', member1: 'D1', member2: 'D2'),
      ];

      final match1 = Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 10,
          score2: 5,
          tableNumber: 1,
          id: 'g11',
          done: true);
      final match2 = Match(
          teamId1: 't3',
          teamId2: 't4',
          score1: 3,
          score2: 7,
          tableNumber: 2,
          id: 'g21',
          done: true);

      final gruppenphase = Gruppenphase(groups: [
        [match1],
        [match2],
      ]);
      final matchQueue = MatchQueue(waiting: [], playing: []);
      final tabellen = evalGruppen(gruppenphase);

      // Build the JSON the way TournamentDataState.toJson() would
      final exported = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matchQueue': matchQueue.toJson(),
        'gruppenphase': gruppenphase.toJson(),
        'tabellen': tabellen.toJson(),
        'knockouts': Knockouts().toJson(),
        'currentTournamentId': 'round_trip_test',
        'isKnockoutMode': false,
        'tournamentStyle': 'groupsAndKnockouts',
        'selectedRuleset': 'bmt-cup',
      };

      // Serialize and deserialize through JSON to simulate file I/O
      final jsonString = jsonEncode(exported);
      final reimported = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(ImportService.isSnapshotJson(reimported), isTrue);

      final snapshot = ImportService.parseSnapshotFromJson(reimported);

      expect(snapshot.teams.length, 4);
      expect(snapshot.teams[0], teams[0]);
      expect(snapshot.teams[3], teams[3]);
      expect(snapshot.gruppenphase, gruppenphase);
      expect(snapshot.matchQueue, matchQueue);
      expect(snapshot.tabellen, tabellen);
      expect(snapshot.currentTournamentId, 'round_trip_test');
      expect(snapshot.tournamentStyle, 'groupsAndKnockouts');
      expect(snapshot.selectedRuleset, 'bmt-cup');
    });

    test('round-trip with knockout data', () {
      final teams = [
        Team(id: 't1', name: 'Alpha', member1: 'A1', member2: 'A2'),
        Team(id: 't2', name: 'Beta', member1: 'B1', member2: 'B2'),
      ];

      final knockouts = Knockouts();
      knockouts.instantiate();
      // Seed one match
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final exported = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': knockouts.toJson(),
        'currentTournamentId': 'ko_test',
        'isKnockoutMode': true,
        'tournamentStyle': 'groupsAndKnockouts',
        'selectedRuleset': null,
      };

      final jsonString = jsonEncode(exported);
      final reimported = jsonDecode(jsonString) as Map<String, dynamic>;

      final snapshot = ImportService.parseSnapshotFromJson(reimported);

      expect(snapshot.knockouts.champions.rounds[0][0].teamId1, 't1');
      expect(snapshot.knockouts.champions.rounds[0][0].teamId2, 't2');
      expect(snapshot.isKnockoutMode, isTrue);
      expect(snapshot.selectedRuleset, isNull);
    });
  });
}
