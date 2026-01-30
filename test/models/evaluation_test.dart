import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/evaluation.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/gruppenphase.dart';
import 'package:pongstrong/models/groups.dart';

void main() {
  group('isValid', () {
    test('validates deathcup scenarios', () {
      expect(isValid(-1, 0), true);
      expect(isValid(-1, 5), true);
      expect(isValid(-1, 10), true);
      expect(isValid(0, -1), true);
      expect(isValid(5, -1), true);
      expect(isValid(10, -1), true);
    });

    test('validates deathcup overtime scenarios', () {
      expect(isValid(-2, 10), true);
      expect(isValid(-2, 15), true);
      expect(isValid(10, -2), true);
      expect(isValid(15, -2), true);
    });

    test('validates normal win (10 cups)', () {
      expect(isValid(10, 0), true);
      expect(isValid(10, 5), true);
      expect(isValid(10, 9), true);
      expect(isValid(0, 10), true);
      expect(isValid(5, 10), true);
      expect(isValid(9, 10), true);
    });

    test('validates overtime scenarios (16 cups)', () {
      expect(isValid(16, 10), true);
      expect(isValid(16, 15), true);
      expect(isValid(10, 16), true);
      expect(isValid(15, 16), true);
    });

    test('validates 1-on-1 overtime scenarios (19 cups)', () {
      expect(isValid(19, 16), true);
      expect(isValid(19, 18), true);
      expect(isValid(16, 19), true);
      expect(isValid(18, 19), true);
    });

    test('validates extended overtime (both >= 19)', () {
      expect(isValid(20, 19), true);
      expect(isValid(19, 20), true);
      expect(isValid(25, 24), true);
      expect(isValid(24, 25), true);
    });

    test('rejects invalid scenarios', () {
      expect(isValid(10, 10), false);
      expect(isValid(5, 5), false);
      expect(isValid(0, 0), false);
      expect(isValid(-1, -2), false);
      expect(isValid(-2, -1), false);
      expect(isValid(3, 3), false);
      expect(isValid(13, 13), false);
      expect(isValid(11, 9), false);
      expect(isValid(15, 14), false);
      expect(isValid(16, 8), false);
      expect(isValid(16, -1), false);
      expect(isValid(20, 20), false);
    });
  });

  group('calculatePoints', () {
    test('returns null for unfinished match (0-0)', () {
      expect(calculatePoints(0, 0), null);
    });

    test('calculates points for normal win (10 cups)', () {
      final points = calculatePoints(10, 5);
      expect(points, isNotNull);
      expect(points!.$1, 3); // winner gets 3 points
      expect(points.$2, 0); // loser gets 0 points
    });

    test('calculates points for normal loss (10 cups)', () {
      final points = calculatePoints(5, 10);
      expect(points, isNotNull);
      expect(points!.$1, 0); // loser gets 0 points
      expect(points.$2, 3); // winner gets 3 points
    });

    test('calculates points for overtime win (16 or 19 cups)', () {
      final points16 = calculatePoints(16, 15);
      expect(points16, isNotNull);
      expect(points16!.$1, 2); // winner gets 2 points
      expect(points16.$2, 1); // loser gets 1 point

      final points19 = calculatePoints(19, 18);
      expect(points19, isNotNull);
      expect(points19!.$1, 2);
      expect(points19.$2, 1);
    });

    test('calculates points for overtime loss (16 or 19 cups)', () {
      final points = calculatePoints(15, 16);
      expect(points, isNotNull);
      expect(points!.$1, 1); // loser gets 1 point
      expect(points.$2, 2); // winner gets 2 points
    });

    test('calculates points for 1-on-1 overtime (both >= 19)', () {
      final points = calculatePoints(20, 19);
      expect(points, isNotNull);
      expect(points!.$1, 2);
      expect(points.$2, 1);
    });

    test('calculates points for deathcup win', () {
      final points = calculatePoints(-1, 5);
      expect(points, isNotNull);
      expect(points!.$1, 4); // deathcup winner gets 4 points
      expect(points.$2, 0); // loser gets 0 points
    });

    test('calculates points for deathcup loss', () {
      final points = calculatePoints(5, -1);
      expect(points, isNotNull);
      expect(points!.$1, 0);
      expect(points.$2, 4);
    });

    test('calculates points for deathcup overtime win', () {
      final points = calculatePoints(-2, 15);
      expect(points, isNotNull);
      expect(points!.$1, 3); // deathcup overtime winner gets 3 points
      expect(points.$2, 1); // loser gets 1 point
    });

    test('calculates points for deathcup overtime loss', () {
      final points = calculatePoints(15, -2);
      expect(points, isNotNull);
      expect(points!.$1, 1);
      expect(points.$2, 3);
    });

    test('returns null for invalid scores', () {
      expect(calculatePoints(5, 5), null);
      expect(calculatePoints(11, 9), null);
      expect(calculatePoints(-1, -2), null);
      expect(calculatePoints(16, -1), null);
      expect(calculatePoints(8, 16), null);
    });
  });

  group('determineWinner', () {
    test('returns 1 when team1 has deathcup (negative score)', () {
      expect(determineWinner(-1, 5), 1);
      expect(determineWinner(-2, 10), 1);
    });

    test('returns 2 when team2 has deathcup (negative score)', () {
      expect(determineWinner(5, -1), 2);
      expect(determineWinner(10, -2), 2);
    });

    test('returns 1 when team1 has higher score', () {
      expect(determineWinner(10, 5), 1);
      expect(determineWinner(16, 15), 1);
      expect(determineWinner(20, 19), 1);
    });

    test('returns 2 when team2 has higher score', () {
      expect(determineWinner(5, 10), 2);
      expect(determineWinner(15, 16), 2);
      expect(determineWinner(19, 20), 2);
    });

    test('returns null for tie', () {
      expect(determineWinner(5, 5), null);
      expect(determineWinner(10, 10), null);
      expect(determineWinner(0, 0), null);
    });

    test('handles invalid scores', () {
      expect(determineWinner(11, 9), null);
      expect(determineWinner(-1, -2), null);
      expect(determineWinner(16, -1), null);
    });
  });

  group('evaluate', () {
    test('returns empty table for no matches', () {
      final table = evaluate([]);
      expect(table.length, 4);
      expect(table.every((row) => row.teamId.isEmpty), true);
    });

    test('evaluates single finished match correctly', () {
      final matches = [
        Match(
          teamId1: 'team1',
          teamId2: 'team2',
          score1: 10,
          score2: 5,
          done: true,
        ),
      ];

      final table = evaluate(matches);
      expect(table.length, 4);

      // Find teams in table
      final team1Row = table.firstWhere((row) => row.teamId == 'team1');
      final team2Row = table.firstWhere((row) => row.teamId == 'team2');

      expect(team1Row.punkte, 3);
      expect(team1Row.becher, 10);
      expect(team1Row.differenz, 5);

      expect(team2Row.punkte, 0);
      expect(team2Row.becher, 5);
      expect(team2Row.differenz, -5);
    });

    test('evaluates multiple finished matches correctly', () {
      final matches = [
        Match(
          teamId1: 'team1',
          teamId2: 'team2',
          score1: 10,
          score2: 5,
          done: true,
        ),
        Match(
          teamId1: 'team1',
          teamId2: 'team3',
          score1: 16,
          score2: 15,
          done: true,
        ),
      ];

      final table = evaluate(matches);
      final team1Row = table.firstWhere((row) => row.teamId == 'team1');

      expect(team1Row.punkte, 5); // 3 + 2
      expect(team1Row.becher, 26); // 10 + 16
      expect(team1Row.differenz, 6); // (10-5) + (16-15)
    });

    test('handles deathcup correctly in evaluation', () {
      final matches = [
        Match(
          teamId1: 'team1',
          teamId2: 'team2',
          score1: -1,
          score2: 8,
          done: true,
        ),
      ];

      final table = evaluate(matches);
      final team1Row = table.firstWhere((row) => row.teamId == 'team1');
      final team2Row = table.firstWhere((row) => row.teamId == 'team2');

      expect(team1Row.punkte, 4); // deathcup winner
      expect(team1Row.becher, 10); // cups(-1) = 10
      expect(team1Row.differenz, 2); // 10 - 8

      expect(team2Row.punkte, 0);
      expect(team2Row.becher, 8);
      expect(team2Row.differenz, -2);
    });

    test('ignores unfinished matches', () {
      final matches = [
        Match(
          teamId1: 'team1',
          teamId2: 'team2',
          score1: 10,
          score2: 5,
          done: true,
        ),
        Match(
          teamId1: 'team1',
          teamId2: 'team3',
          score1: 0,
          score2: 0,
          done: false,
        ),
      ];

      final table = evaluate(matches);
      final team1Row = table.firstWhere((row) => row.teamId == 'team1');
      final team3Row = table.firstWhere((row) => row.teamId == 'team3');

      expect(team1Row.punkte, 3); // only from first match
      expect(team3Row.punkte, 0); // unfinished match ignored
    });
  });

  group('evalGruppen', () {
    test('evaluates all groups and sorts tables', () {
      final groups = Groups(groups: [
        ['team1', 'team2', 'team3', 'team4'],
        ['team5', 'team6', 'team7', 'team8'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);

      // Finish some matches
      gruppenphase.groups[0][0].done = true;
      gruppenphase.groups[0][0].score1 = 10;
      gruppenphase.groups[0][0].score2 = 5;

      gruppenphase.groups[1][0].done = true;
      gruppenphase.groups[1][0].score1 = 16;
      gruppenphase.groups[1][0].score2 = 15;

      final tabellen = evalGruppen(gruppenphase);

      expect(tabellen.tables.length, 2);
      expect(tabellen.tables[0].length, 4);
      expect(tabellen.tables[1].length, 4);

      // Check that tables are sorted (highest points first)
      for (var table in tabellen.tables) {
        for (int i = 0; i < table.length - 1; i++) {
          expect(table[i].punkte >= table[i + 1].punkte, true);
        }
      }

      // Add a different configuration for testing
      gruppenphase.groups[0][1].done = true;
      gruppenphase.groups[0][1].score1 = 8;
      gruppenphase.groups[0][1].score2 = 10;

      gruppenphase.groups[1][1].done = true;
      gruppenphase.groups[1][1].score1 = 12;
      gruppenphase.groups[1][1].score2 = 14;

      final updatedTabellen = evalGruppen(gruppenphase);

      // Verify the updated tables
      expect(updatedTabellen.tables[0].length, 4);
      expect(updatedTabellen.tables[1].length, 4);

      // Check that tables are still sorted correctly
      for (var table in updatedTabellen.tables) {
        for (int i = 0; i < table.length - 1; i++) {
          expect(table[i].punkte >= table[i + 1].punkte, true);
        }
      }
    });
  });

  group('evaluateGroups8', () {
    // evaluateGroups8 ist used yet and probably has some issues still
    //TODO: add tests for evaluateGroups8
  });

  group('evaluateGroups6', () {
    test('creates knockout structure from 6 groups', () {
      final groups = Groups(
          groups: List.generate(
        6,
        (i) => ['t${i}1', 't${i}2', 't${i}3', 't${i}4'],
      ));
      final gruppenphase = Gruppenphase.create(groups);

      // Simulate group stage results with varying scores
      for (int g = 0; g < gruppenphase.groups.length; g++) {
        for (int m = 0; m < gruppenphase.groups[g].length; m++) {
          gruppenphase.groups[g][m].done = true;
          gruppenphase.groups[g][m].score1 = 10;
          gruppenphase.groups[g][m].score2 = 5 + (m % 3);
        }
      }

      final tabellen = evalGruppen(gruppenphase);
      final knockouts = evaluateGroups6(tabellen);

      expect(knockouts.champions.rounds.length, 4);
      expect(knockouts.champions.rounds[0].length, 8);

      // Europa and Conference skip round 0
      expect(knockouts.europa.rounds[1].length, 2);
      expect(knockouts.conference.rounds[1].length, 2);

      // Check that best thirds are placed
      int filledSlots = knockouts.champions.rounds[0]
          .where((m) => m.teamId1.isNotEmpty && m.teamId2.isNotEmpty)
          .length;
      expect(filledSlots, greaterThan(0));
    });
  });
}
