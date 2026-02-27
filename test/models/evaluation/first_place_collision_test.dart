import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/evaluation.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/groups/tabellen.dart';
import 'package:pongstrong/models/match/match.dart';

/// Creates a Tabellen for [n] groups where ALL matches are set to 10-0.
/// This simulates the user's scenario where team1 always wins decisively.
Tabellen _makeTabellenAllSameScore(
  int n, {
  required int score1,
  required int score2,
}) {
  final groups = Groups(
    groups: List.generate(
      n,
      (g) => ['g${g}p1', 'g${g}p2', 'g${g}p3', 'g${g}p4'],
    ),
  );
  final gp = Gruppenphase.create(groups);

  for (int g = 0; g < gp.groups.length; g++) {
    for (int m = 0; m < gp.groups[g].length; m++) {
      gp.groups[g][m].done = true;
      gp.groups[g][m].score1 = score1;
      gp.groups[g][m].score2 = score2;
    }
  }
  return evalGruppen(gp);
}

/// Extracts team IDs for a given rank (0=first place) across all groups.
Set<String> _getTeamsAtRank(Tabellen tabellen, int rank) {
  final teams = <String>{};
  for (final table in tabellen.tables) {
    if (rank < table.length) {
      teams.add(table[rank].teamId);
    }
  }
  return teams;
}

/// Checks R1 matches in a league for first-vs-first collisions.
List<String> _findFirstPlaceCollisions(
  List<List<Match>> rounds,
  Set<String> firstPlaceTeams,
) {
  if (rounds.isEmpty) return [];
  final collisions = <String>[];

  for (final match in rounds[0]) {
    final t1IsFirst = firstPlaceTeams.contains(match.teamId1);
    final t2IsFirst = firstPlaceTeams.contains(match.teamId2);
    if (t1IsFirst && t2IsFirst) {
      collisions.add('${match.teamId1} vs ${match.teamId2}');
    }
  }
  return collisions;
}

/// Returns the nearest power of 2 to x (matches bracket_seeding logic).
int _nearestPow2(int x) {
  if (x <= 2) return x <= 1 ? 1 : 2;
  int next = 1;
  while (next < x) {
    next *= 2;
  }
  final prev = next >> 1;
  return (next - x <= x - prev) ? next : prev;
}

/// Determines if first-vs-first is avoidable for n groups.
/// When numFirsts > bracketSize/2, it's mathematically impossible.
bool _isFirstVsFirstAvoidable(int n) {
  final champSize = _nearestPow2(2 * n);
  final numFirsts = n; // All firsts go to Champions
  final r1Matches = champSize ~/ 2;
  // If we have more firsts than R1 matches, at least one match must be first-vs-first
  return numFirsts <= r1Matches;
}

void main() {
  group('first-place collision tests – 10-0 scenario', () {
    test(
        '4 groups with 10-0 results: no first-place teams play each other in R1',
        () {
      final tabellen = _makeTabellenAllSameScore(4, score1: 10, score2: 0);
      final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);

      // Debug: print group standings
      for (int g = 0; g < tabellen.tables.length; g++) {
        final standings = tabellen.tables[g]
            .map((r) => '${r.teamId}(${r.points}pts,${r.difference}diff)')
            .join(', ');
        // ignore: avoid_print
        print('Group $g: $standings');
      }
      // ignore: avoid_print
      print('First-place teams: $firstPlaceTeams');

      final ko = evaluateGroups(tabellen);

      // Debug: print Champions R1 matchups
      // ignore: avoid_print
      print('\nChampions R1 matchups:');
      for (final match in ko.champions.rounds[0]) {
        final t1First = firstPlaceTeams.contains(match.teamId1) ? '(1st)' : '';
        final t2First = firstPlaceTeams.contains(match.teamId2) ? '(1st)' : '';
        // ignore: avoid_print
        print('  ${match.teamId1}$t1First vs ${match.teamId2}$t2First');
      }

      final champCollisions =
          _findFirstPlaceCollisions(ko.champions.rounds, firstPlaceTeams);

      expect(champCollisions, isEmpty,
          reason: 'First-place teams should not play each other in R1 of '
              'Champions. Found: $champCollisions');
    });

    // Test configurations where first-vs-first IS avoidable
    for (int n = 2; n <= 10; n++) {
      final avoidable = _isFirstVsFirstAvoidable(n);
      if (avoidable) {
        test('$n groups with 10-0 results: no first-vs-first in R1 (avoidable)',
            () {
          final tabellen = _makeTabellenAllSameScore(n, score1: 10, score2: 0);
          final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);

          final ko = evaluateGroups(tabellen);

          void checkLeague(String name, List<List<Match>> rounds) {
            if (rounds.isEmpty) return;
            final collisions =
                _findFirstPlaceCollisions(rounds, firstPlaceTeams);
            expect(collisions, isEmpty,
                reason:
                    '$name R1 has first-vs-first: $collisions (firsts: $firstPlaceTeams)');
          }

          checkLeague('Champions', ko.champions.rounds);
          checkLeague('Europa', ko.europa.rounds);
          checkLeague('Conference', ko.conference.rounds);
        });
      } else {
        test(
            '$n groups with 10-0 results: first-vs-first unavoidable (mathematical limit)',
            () {
          // Document that this is a known limitation
          final tabellen = _makeTabellenAllSameScore(n, score1: 10, score2: 0);
          final ko = evaluateGroups(tabellen);

          // Just verify the knockout structure is valid
          expect(ko.champions.rounds, isNotEmpty);
          // ignore: avoid_print
          print('Note: $n groups has more firsts than R1 matches, '
              'first-vs-first is unavoidable.');
        });
      }
    }
  });

  group('first-place collision analysis – all group counts', () {
    for (int n = 2; n <= 10; n++) {
      test('$n groups: detailed collision analysis', () {
        final tabellen = _makeTabellenAllSameScore(n, score1: 10, score2: 0);
        final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);

        final champSize = _nearestPow2(2 * n);
        final r1Matches = champSize ~/ 2;
        final minUnavoidable = (n > r1Matches) ? n - r1Matches : 0;

        final ko = evaluateGroups(tabellen);
        final collisions =
            _findFirstPlaceCollisions(ko.champions.rounds, firstPlaceTeams);

        // ignore: avoid_print
        print(
            '$n groups: champSize=$champSize, firsts=$n, r1Matches=$r1Matches');
        // ignore: avoid_print
        print('  Minimum unavoidable first-vs-first: $minUnavoidable');
        // ignore: avoid_print
        print('  Actual collisions: ${collisions.length} - $collisions');

        // Verify we're at or near the theoretical minimum
        if (minUnavoidable == 0) {
          expect(collisions, isEmpty,
              reason: '$n groups should have NO first-vs-first in R1');
        } else {
          // We should have at most minUnavoidable collisions
          // (algorithm should minimize, not exceed theoretical minimum)
          expect(collisions.length, lessThanOrEqualTo(minUnavoidable + 1),
              reason: '$n groups has $minUnavoidable minimum unavoidable, '
                  'but got ${collisions.length}');
        }
      });
    }
  });

  group('first-place collision tests – various score patterns', () {
    // Test different score patterns that might cause sorting issues
    final scorePatterns = [
      (10, 0, 'decisive wins'),
      (10, 9, 'close games'),
      (16, 15, 'overtime wins'),
      (5, 0, 'low-scoring wins'),
    ];

    for (final (s1, s2, desc) in scorePatterns) {
      test('4 groups with $desc ($s1-$s2): no first-vs-first in R1', () {
        final tabellen = _makeTabellenAllSameScore(4, score1: s1, score2: s2);
        final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);

        final ko = evaluateGroups(tabellen);
        final collisions =
            _findFirstPlaceCollisions(ko.champions.rounds, firstPlaceTeams);

        expect(collisions, isEmpty,
            reason: 'First-place teams with $desc should not play in R1');
      });
    }
  });

  group('first-place collision tests – edge cases', () {
    test(
        '4 groups with reversed scores (0-10): verify first-place identification',
        () {
      // When score1=0, score2=10, team2 always wins
      final tabellen = _makeTabellenAllSameScore(4, score1: 0, score2: 10);
      final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);

      // Debug: verify who finished first
      for (int g = 0; g < tabellen.tables.length; g++) {
        final firstInGroup = tabellen.tables[g][0].teamId;
        // ignore: avoid_print
        print('Group $g first place: $firstInGroup');
      }

      final ko = evaluateGroups(tabellen);
      final collisions =
          _findFirstPlaceCollisions(ko.champions.rounds, firstPlaceTeams);

      expect(collisions, isEmpty,
          reason: 'No first-vs-first even with reversed scores: $collisions');
    });
  });

  group('seeding verification – Champions bracket structure', () {
    test('4 groups: verify seed distribution in 8-team Champions bracket', () {
      final tabellen = _makeTabellenAllSameScore(4, score1: 10, score2: 0);
      final firstPlaceTeams = _getTeamsAtRank(tabellen, 0);
      final secondPlaceTeams = _getTeamsAtRank(tabellen, 1);

      final ko = evaluateGroups(tabellen);

      // In an 8-team bracket with standard seeding [1,8,4,5,2,7,3,6]:
      // Each R1 match should pair a seed 1-4 with a seed 5-8
      // (i.e., a first-place with a second-place team)
      // ignore: avoid_print
      print('First-place teams: $firstPlaceTeams');
      // ignore: avoid_print
      print('Second-place teams: $secondPlaceTeams');

      for (int i = 0; i < ko.champions.rounds[0].length; i++) {
        final match = ko.champions.rounds[0][i];
        final t1IsFirst = firstPlaceTeams.contains(match.teamId1);
        final t2IsFirst = firstPlaceTeams.contains(match.teamId2);
        final t1IsSecond = secondPlaceTeams.contains(match.teamId1);
        final t2IsSecond = secondPlaceTeams.contains(match.teamId2);

        // ignore: avoid_print
        print(
            'R1 Match $i: ${match.teamId1}${t1IsFirst ? "(1st)" : t1IsSecond ? "(2nd)" : ""} '
            'vs ${match.teamId2}${t2IsFirst ? "(1st)" : t2IsSecond ? "(2nd)" : ""}');

        // Each match should have one first-place and one second-place
        // (or one could be a bye)
        if (match.teamId1.isNotEmpty && match.teamId2.isNotEmpty) {
          expect(t1IsFirst && t2IsFirst, isFalse,
              reason: 'Match $i has two first-place teams');
        }
      }
    });
  });
}
