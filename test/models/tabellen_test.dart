import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/tabellen.dart';

void main() {
  group('TableRow', () {
    test('creates row with default values', () {
      final row = TableRow();
      expect(row.teamId, '');
      expect(row.punkte, 0);
      expect(row.differenz, 0);
      expect(row.becher, 0);
      expect(row.vergleich.length, 4);
      expect(row.vergleich.every((v) => v == ''), true);
    });

    test('creates row with custom values', () {
      final row = TableRow(
        teamId: 'team1',
        punkte: 6,
        differenz: 5,
        becher: 20,
        vergleich: ['t1', 't2', 't3', 't4'],
      );
      expect(row.teamId, 'team1');
      expect(row.punkte, 6);
      expect(row.differenz, 5);
      expect(row.becher, 20);
      expect(row.vergleich, ['t1', 't2', 't3', 't4']);
    });

    group('JSON serialization', () {
      test('toJson converts row to JSON correctly', () {
        final row = TableRow(
          teamId: 'team1',
          punkte: 6,
          differenz: 5,
          becher: 20,
          vergleich: ['t1', 't2', 't3', 't4'],
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
        expect(row.punkte, 6);
        expect(row.differenz, 5);
        expect(row.becher, 20);
        expect(row.vergleich, ['t1', 't2', 't3', 't4']);
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final row = TableRow.fromJson(json);
        expect(row.teamId, '');
        expect(row.punkte, 0);
        expect(row.differenz, 0);
        expect(row.becher, 0);
        expect(row.vergleich.length, 4);
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
          TableRow(teamId: 't1', punkte: 6),
          TableRow(teamId: 't2', punkte: 3),
        ],
      ]);
      expect(tabellen.tables.length, 1);
      expect(tabellen.tables[0].length, 2);
    });
  });

  group('sortTable', () {
    test('sorts by points descending', () {
      final table = [
        TableRow(teamId: 't1', punkte: 3),
        TableRow(teamId: 't2', punkte: 6),
        TableRow(teamId: 't3'),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // 6 points
      expect(table[1].teamId, 't1'); // 3 points
      expect(table[2].teamId, 't3'); // 0 points
    });

    test('sorts by differenz when points are equal', () {
      final table = [
        TableRow(teamId: 't1', punkte: 3, differenz: 2),
        TableRow(teamId: 't2', punkte: 3, differenz: 5),
        TableRow(teamId: 't3', punkte: 3, differenz: -1),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // differenz: 5
      expect(table[1].teamId, 't1'); // differenz: 2
      expect(table[2].teamId, 't3'); // differenz: -1
    });

    test('sorts by becher when points and differenz are equal', () {
      final table = [
        TableRow(teamId: 't1', punkte: 3, differenz: 2, becher: 15),
        TableRow(teamId: 't2', punkte: 3, differenz: 2, becher: 20),
        TableRow(teamId: 't3', punkte: 3, differenz: 2, becher: 10),
      ];

      Tabellen.sortTable(table);

      expect(table[0].teamId, 't2'); // becher: 20
      expect(table[1].teamId, 't1'); // becher: 15
      expect(table[2].teamId, 't3'); // becher: 10
    });

    test('sorts by all criteria in priority order', () {
      final table = [
        TableRow(teamId: 't1', punkte: 3, differenz: 2, becher: 15),
        TableRow(teamId: 't2', punkte: 6, differenz: -1, becher: 10),
        TableRow(teamId: 't3', punkte: 3, differenz: 5, becher: 20),
        TableRow(teamId: 't4', differenz: 10, becher: 25),
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
      final table = [TableRow(teamId: 't1', punkte: 3)];
      Tabellen.sortTable(table);
      expect(table.length, 1);
      expect(table[0].teamId, 't1');
    });
  });

  group('sortTables', () {
    test('sorts all tables in Tabellen', () {
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', punkte: 3),
          TableRow(teamId: 't2', punkte: 6),
        ],
        [
          TableRow(teamId: 't3'),
          TableRow(teamId: 't4', punkte: 3),
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
  });

  group('JSON serialization', () {
    test('toJson converts Tabellen to JSON correctly', () {
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't1', punkte: 6),
          TableRow(teamId: 't2', punkte: 3),
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
      expect(tabellen.tables[0][0].punkte, 6);
    });

    test('round trip serialization preserves data', () {
      final original = Tabellen(tables: [
        [
          TableRow(teamId: 't1', punkte: 6, differenz: 2, becher: 15),
          TableRow(teamId: 't2', punkte: 3, becher: 10),
        ],
      ]);

      final json = original.toJson();
      final restored = Tabellen.fromJson(json);

      expect(restored.tables.length, original.tables.length);
      expect(restored.tables[0][0].teamId, original.tables[0][0].teamId);
      expect(restored.tables[0][0].punkte, original.tables[0][0].punkte);
    });
  });

  group('clone', () {
    test('creates deep copy of Tabellen', () {
      final original = Tabellen(tables: [
        [
          TableRow(teamId: 't1', punkte: 6),
          TableRow(teamId: 't2', punkte: 3),
        ],
      ]);

      final cloned = original.clone();

      // Same values
      expect(cloned.tables[0][0].teamId, original.tables[0][0].teamId);
      expect(cloned.tables[0][0].punkte, original.tables[0][0].punkte);

      // But different objects
      cloned.tables[0][0].punkte = 9;
      expect(original.tables[0][0].punkte, 6); // Original unchanged
      expect(cloned.tables[0][0].punkte, 9); // Clone changed
    });
  });
}
