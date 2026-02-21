import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/tabellen.dart';

void main() {
  group('TableRow', () {
    test('creates row with default values', () {
      final row = TableRow();
      expect(row.teamId, '');
      expect(row.points, 0);
      expect(row.difference, 0);
      expect(row.cups, 0);
      expect(row.headToHead.length, 4);
      expect(row.headToHead.every((v) => v == ''), true);
    });

    test('creates row with custom values', () {
      final row = TableRow(
        teamId: 'team1',
        points: 6,
        difference: 5,
        cups: 20,
        headToHead: ['t1', 't2', 't3', 't4'],
      );
      expect(row.teamId, 'team1');
      expect(row.points, 6);
      expect(row.difference, 5);
      expect(row.cups, 20);
      expect(row.headToHead, ['t1', 't2', 't3', 't4']);
    });

    group('JSON serialization', () {
      test('toJson converts row to JSON correctly', () {
        final row = TableRow(
          teamId: 'team1',
          points: 6,
          difference: 5,
          cups: 20,
          headToHead: ['t1', 't2', 't3', 't4'],
        );

        final json = row.toJson();
        expect(json['teamId'], 'team1');
        expect(json['punkte'], 6);
        expect(json['differenz'], 5);
        expect(json['becher'], 20);
        expect(json['vergleich'], ['t1', 't2', 't3', 't4']);
      });

      test('fromJson creates row from JSON correctly', () {
        final json = {
          'teamId': 'team1',
          'punkte': 6,
          'differenz': 5,
          'becher': 20,
          'vergleich': ['t1', 't2', 't3', 't4'],
        };

        final row = TableRow.fromJson(json);
        expect(row.teamId, 'team1');
        expect(row.points, 6);
        expect(row.difference, 5);
        expect(row.cups, 20);
        expect(row.headToHead, ['t1', 't2', 't3', 't4']);
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final row = TableRow.fromJson(json);
        expect(row.teamId, '');
        expect(row.points, 0);
        expect(row.difference, 0);
        expect(row.cups, 0);
        expect(row.headToHead.length, 4);
      });
    });
  });

  group('Tabellen', () {
    test('creates empty Tabellen', () {
      final tabellen = Tabellen();
      expect(tabellen.tables, isEmpty);
    });

    test('creates Tabellen with tables', () {
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 6),
          TableRow(teamId: 't2', points: 3),
        ],
      ]);
      expect(tabellen.tables.length, 1);
      expect(tabellen.tables[0].length, 2);
    });
  });

  group('sortTable', () {
    test('sorts by points descending', () {
      final table = [
        TableRow(teamId: 't1', points: 3),
        TableRow(teamId: 't2', points: 6),
        TableRow(teamId: 't3'),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // 6 points
      expect(table[1].teamId, 't1'); // 3 points
      expect(table[2].teamId, 't3'); // 0 points
    });

    test('sorts by differenz when points are equal', () {
      final table = [
        TableRow(teamId: 't1', points: 3, difference: 2),
        TableRow(teamId: 't2', points: 3, difference: 5),
        TableRow(teamId: 't3', points: 3, difference: -1),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // difference: 5
      expect(table[1].teamId, 't1'); // difference: 2
      expect(table[2].teamId, 't3'); // difference: -1
    });

    test('sorts by becher when points and differenz are equal', () {
      final table = [
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 20),
        TableRow(teamId: 't3', points: 3, difference: 2, cups: 10),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // cups: 20
      expect(table[1].teamId, 't1'); // cups: 15
      expect(table[2].teamId, 't3'); // cups: 10
    });

    test('sorts by all criteria in priority order', () {
      final table = [
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't2', points: 6, difference: -1, cups: 10),
        TableRow(teamId: 't3', points: 3, difference: 5, cups: 20),
        TableRow(teamId: 't4', difference: 10, cups: 25),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // 6 points (highest)
      expect(table[1].teamId, 't3'); // 3 points, 5 differenz
      expect(table[2].teamId, 't1'); // 3 points, 2 differenz
      expect(table[3].teamId, 't4'); // 0 points
    });

    test('handles empty table', () {
      final table = <TableRow>[];
      Tabellen.sortTable(table);
      expect(table, isEmpty);
    });

    test('handles single entry table', () {
      final table = [TableRow(teamId: 't1', points: 3)];
      Tabellen.sortTable(table);
      expect(table.length, 1);
      expect(table[0].teamId, 't1');
    });

    test('uses head-to-head when all other metrics equal', () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 10,
          score2: 5,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 15),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't1'); // t1 beat t2 head-to-head
      expect(table[1].teamId, 't2');
    });

    test('head-to-head: team2 won the direct match', () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 5,
          score2: 10,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 15),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't2'); // t2 beat t1 head-to-head
      expect(table[1].teamId, 't1');
    });

    test('head-to-head: no direct match → falls back to alphabetical', () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't3',
          score1: 10,
          score2: 5,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't1'); // alphabetical fallback
      expect(table[1].teamId, 't2');
    });

    test('head-to-head: unfinished direct match → falls back to alphabetical',
        () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
        ),
      ];
      final table = [
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't1'); // alphabetical fallback
      expect(table[1].teamId, 't2');
    });

    test('head-to-head with deathcup win', () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: -1,
          score2: 5,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't2', points: 4, cups: 10),
        TableRow(teamId: 't1', points: 4, cups: 10),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't1'); // t1 won via deathcup
      expect(table[1].teamId, 't2');
    });

    test('head-to-head with overtime win', () {
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 15,
          score2: 16,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't1', points: 2, cups: 16),
        TableRow(teamId: 't2', points: 2, cups: 16),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't2'); // t2 won 16-15
      expect(table[1].teamId, 't1');
    });

    test('head-to-head not used when points differ', () {
      // Even though t2 beat t1 head-to-head, t1 has more points
      final matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 5,
          score2: 10,
          done: true,
        ),
      ];
      final table = [
        TableRow(teamId: 't2', points: 3),
        TableRow(teamId: 't1', points: 6),
      ];

      Tabellen.sortTable(table, matches: matches);

      expect(table[0].teamId, 't1'); // t1 has more points
      expect(table[1].teamId, 't2');
    });

    test('no matches provided → falls back to alphabetical', () {
      final table = [
        TableRow(teamId: 't2', points: 3, difference: 2, cups: 15),
        TableRow(teamId: 't1', points: 3, difference: 2, cups: 15),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't1'); // alphabetical fallback
      expect(table[1].teamId, 't2');
    });
  });

  group('sortTables', () {
    test('sorts all tables in Tabellen', () {
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 3),
          TableRow(teamId: 't2', points: 6),
        ],
        [
          TableRow(teamId: 't3'),
          TableRow(teamId: 't4', points: 3),
        ],
      ]);

      tabellen.sortTables();

      expect(tabellen.tables[0][0].teamId, 't2'); // 6 points
      expect(tabellen.tables[0][1].teamId, 't1'); // 3 points
      expect(tabellen.tables[1][0].teamId, 't4'); // 3 points
      expect(tabellen.tables[1][1].teamId, 't3'); // 0 points
    });

    test('handles empty Tabellen', () {
      final tabellen = Tabellen();
      tabellen.sortTables();
      expect(tabellen.tables, isEmpty);
    });

    test('applies head-to-head from groupMatches per group', () {
      final group0Matches = [
        Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 5,
          score2: 10,
          done: true,
        ),
      ];
      final group1Matches = [
        Match(
          teamId1: 't3',
          teamId2: 't4',
          score1: 10,
          score2: 5,
          done: true,
        ),
      ];

      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 3, cups: 10),
          TableRow(teamId: 't2', points: 3, cups: 10),
        ],
        [
          TableRow(teamId: 't4', points: 3, cups: 10),
          TableRow(teamId: 't3', points: 3, cups: 10),
        ],
      ]);

      tabellen.sortTables(groupMatches: [group0Matches, group1Matches]);

      // Group 0: t2 beat t1 → t2 first
      expect(tabellen.tables[0][0].teamId, 't2');
      expect(tabellen.tables[0][1].teamId, 't1');
      // Group 1: t3 beat t4 → t3 first
      expect(tabellen.tables[1][0].teamId, 't3');
      expect(tabellen.tables[1][1].teamId, 't4');
    });
  });

  group('JSON serialization', () {
    test('toJson converts Tabellen to JSON correctly', () {
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 6),
          TableRow(teamId: 't2', points: 3),
        ],
      ]);

      final json = tabellen.toJson();
      expect(json.length, 1);
      expect(json[0].length, 2);
      expect(json[0][0]['teamId'], 't1');
      expect(json[0][1]['teamId'], 't2');
    });

    test('fromJson creates Tabellen from JSON correctly', () {
      final json = [
        [
          {
            'teamId': 't1',
            'punkte': 6,
            'differenz': 2,
            'becher': 15,
            'vergleich': ['', '', '', '']
          },
          {
            'teamId': 't2',
            'punkte': 3,
            'differenz': 0,
            'becher': 10,
            'vergleich': ['', '', '', '']
          },
        ],
      ];

      final tabellen = Tabellen.fromJson(json);
      expect(tabellen.tables.length, 1);
      expect(tabellen.tables[0].length, 2);
      expect(tabellen.tables[0][0].teamId, 't1');
      expect(tabellen.tables[0][0].points, 6);
    });

    test('round trip serialization preserves data', () {
      final original = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 6, difference: 2, cups: 15),
          TableRow(teamId: 't2', points: 3, cups: 10),
        ],
      ]);

      final json = original.toJson();
      final restored = Tabellen.fromJson(json);

      expect(restored.tables.length, original.tables.length);
      expect(restored.tables[0][0].teamId, original.tables[0][0].teamId);
      expect(restored.tables[0][0].points, original.tables[0][0].points);
    });
  });

  group('headToHeadResult', () {
    test('returns negative when teamA won', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'B', score1: 10, score2: 5, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), -1);
    });

    test('returns positive when teamB won', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'B', score1: 5, score2: 10, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), 1);
    });

    test('returns positive when teamB won (reversed order in match)', () {
      final matches = [
        Match(teamId1: 'B', teamId2: 'A', score1: 10, score2: 5, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), 1);
    });

    test('returns negative when teamA won (reversed order in match)', () {
      final matches = [
        Match(teamId1: 'B', teamId2: 'A', score1: 5, score2: 10, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), -1);
    });

    test('returns 0 when no direct match exists', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'C', score1: 10, score2: 5, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), 0);
    });

    test('returns 0 when direct match is unfinished', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'B'),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), 0);
    });

    test('returns 0 with empty matches', () {
      expect(Tabellen.headToHeadResult('A', 'B', []), 0);
    });

    test('handles deathcup winner correctly', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'B', score1: -1, score2: 5, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), -1);
    });

    test('handles deathcup OT winner correctly', () {
      final matches = [
        Match(teamId1: 'A', teamId2: 'B', score1: 15, score2: -2, done: true),
      ];
      expect(Tabellen.headToHeadResult('A', 'B', matches), 1);
    });
  });

  group('clone', () {
    test('creates deep copy of Tabellen', () {
      final original = Tabellen(tables: [
        [
          TableRow(teamId: 't1', points: 6),
          TableRow(teamId: 't2', points: 3),
        ],
      ]);

      final cloned = original.clone();

      // Same values
      expect(cloned.tables[0][0].teamId, original.tables[0][0].teamId);
      expect(cloned.tables[0][0].points, original.tables[0][0].points);

      // But different objects
      cloned.tables[0][0].points = 9;
      expect(original.tables[0][0].points, 6); // Original unchanged
      expect(cloned.tables[0][0].points, 9); // Clone changed
    });
  });
}
