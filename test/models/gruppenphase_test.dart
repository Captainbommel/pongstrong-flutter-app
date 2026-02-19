import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/gruppenphase.dart';
import 'package:pongstrong/models/groups.dart';
import 'package:pongstrong/models/match.dart';

void main() {
  group('Gruppenphase', () {
    test('creates empty Gruppenphase', () {
      final gruppenphase = Gruppenphase();
      expect(gruppenphase.groups, isEmpty);
    });

    test('creates Gruppenphase with groups', () {
      final gruppenphase = Gruppenphase(groups: [
        [Match(id: 'g11'), Match(id: 'g12')],
        [Match(id: 'g21'), Match(id: 'g22')],
      ]);
      expect(gruppenphase.groups.length, 2);
      expect(gruppenphase.groups[0].length, 2);
    });
  });

  group('create', () {
    test('creates Gruppenphase from Groups with correct number of groups', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);

      expect(gruppenphase.groups.length, 2);
    });

    test('creates 6 matches per group (round robin)', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);

      expect(gruppenphase.groups[0].length, 6); // 6 matches for 4 teams
    });

    test('assigns team IDs correctly based on pairing pattern', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);
      final matches = gruppenphase.groups[0];

      // Actual circle-method pattern for 4 teams: [0,3],[1,2],[0,2],[3,1],[0,1],[2,3]
      expect(matches[0].teamId1, 't1'); // index 0
      expect(matches[0].teamId2, 't4'); // index 3
      expect(matches[1].teamId1, 't2'); // index 1
      expect(matches[1].teamId2, 't3'); // index 2
      expect(matches[2].teamId1, 't1'); // index 0
      expect(matches[2].teamId2, 't3'); // index 2
      expect(matches[3].teamId1, 't4'); // index 3
      expect(matches[3].teamId2, 't2'); // index 1
      expect(matches[4].teamId1, 't1'); // index 0
      expect(matches[4].teamId2, 't2'); // index 1
      expect(matches[5].teamId1, 't3'); // index 2
      expect(matches[5].teamId2, 't4'); // index 3
    });

    test('assigns match IDs correctly', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);

      expect(gruppenphase.groups[0][0].id, 'g11');
      expect(gruppenphase.groups[0][1].id, 'g12');
      expect(gruppenphase.groups[0][5].id, 'g16');
      expect(gruppenphase.groups[1][0].id, 'g21');
      expect(gruppenphase.groups[1][5].id, 'g26');
    });

    test('assigns table numbers according to blueprint', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);

      // Blueprint for first round: [1, 2, ...] and [2, 3, ...]
      expect(gruppenphase.groups[0][0].tischNr, 1);
      expect(gruppenphase.groups[1][0].tischNr, 2);

      // Check that all matches have valid table numbers
      for (var group in gruppenphase.groups) {
        for (var match in group) {
          expect(match.tischNr, greaterThan(0));
          expect(match.tischNr, lessThanOrEqualTo(6));
        }
      }
    });

    test('handles different numbers of groups', () {
      // This will be a future feature
    });

    test('initializes matches as not done', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
      ]);

      final gruppenphase = Gruppenphase.create(groups);

      for (var match in gruppenphase.groups[0]) {
        expect(match.done, false);
        expect(match.score1, 0);
        expect(match.score2, 0);
      }
    });
  });

  group('JSON serialization', () {
    test('toJson converts Gruppenphase to JSON correctly', () {
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(id: 'g11', teamId1: 't1', teamId2: 't2', score1: 10, score2: 5),
          Match(id: 'g12', teamId1: 't3', teamId2: 't4', score1: 0, score2: 0),
        ],
      ]);

      final json = gruppenphase.toJson();
      expect(json.length, 1);
      expect(json[0]['matches'].length, 2);
      expect(json[0]['matches'][0]['id'], 'g11');
      expect(json[0]['matches'][1]['id'], 'g12');
    });

    test('fromJson creates Gruppenphase from JSON correctly', () {
      final json = [
        {
          'matches': [
            {
              'id': 'g11',
              'teamId1': 't1',
              'teamId2': 't2',
              'score1': 10,
              'score2': 5,
              'tischnummer': 1,
              'done': true,
            },
          ],
        },
      ];

      final gruppenphase = Gruppenphase.fromJson(json);
      expect(gruppenphase.groups.length, 1);
      expect(gruppenphase.groups[0].length, 1);
      expect(gruppenphase.groups[0][0].id, 'g11');
      expect(gruppenphase.groups[0][0].teamId1, 't1');
      expect(gruppenphase.groups[0][0].done, true);
    });

    test('round trip serialization preserves data', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      final original = Gruppenphase.create(groups);

      // Mark some matches as done
      original.groups[0][0].done = true;
      original.groups[0][0].score1 = 10;
      original.groups[0][0].score2 = 5;

      final json = original.toJson();
      final restored = Gruppenphase.fromJson(json);

      expect(restored.groups.length, original.groups.length);
      expect(restored.groups[0][0].id, original.groups[0][0].id);
      expect(restored.groups[0][0].done, original.groups[0][0].done);
      expect(restored.groups[0][0].score1, original.groups[0][0].score1);
    });
  });
}
