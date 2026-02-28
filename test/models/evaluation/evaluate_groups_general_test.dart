import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/evaluation.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/groups/tabellen.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';

/// Creates a Tabellen from [n] groups of 4 teams with simulated results.
/// Team IDs follow the pattern: g{group}p{rank} (e.g. g0p1, g0p2, g0p3, g0p4).
/// The simulation ensures deterministic sorted order within each group.
Tabellen _makeTabellenForGroups(int n) {
  final groups = Groups(
    groups: List.generate(
      n,
      (g) => ['g${g}p1', 'g${g}p2', 'g${g}p3', 'g${g}p4'],
    ),
  );
  final gp = Gruppenphase.create(groups);

  // Simulate: first-listed team wins every match decisively.
  // This creates a deterministic ranking: p1 > p2 > p3 > p4 per group.
  for (int g = 0; g < gp.groups.length; g++) {
    for (int m = 0; m < gp.groups[g].length; m++) {
      gp.groups[g][m].done = true;
      gp.groups[g][m].score1 = 10;
      // Vary losing score slightly by group to differentiate cross-group perf.
      gp.groups[g][m].score2 = 3 + g % 5;
    }
  }
  return evalGruppen(gp);
}

void main() {
  // ====================================================================
  // Helper utilities
  // ====================================================================

  group('_nextPow2 / _nearestPow2 / generateSeeding', () {
    test('generateSeeding produces correct bracket for size 8', () {
      final s = generateSeeding(8);
      // Standard bracket: [1,8,4,5,2,7,3,6]
      expect(s, [1, 8, 4, 5, 2, 7, 3, 6]);
    });

    test('generateSeeding produces correct bracket for size 4', () {
      final s = generateSeeding(4);
      expect(s, [1, 4, 2, 3]);
    });

    test('generateSeeding produces correct bracket for size 2', () {
      final s = generateSeeding(2);
      expect(s, [1, 2]);
    });
  });

  // ====================================================================
  // Structural tests for every group count 2–10
  // ====================================================================

  for (int n = 2; n <= 10; n++) {
    group('evaluateGroups – $n groups', () {
      late Tabellen tabellen;
      late Knockouts knockouts;

      setUp(() {
        tabellen = _makeTabellenForGroups(n);
        knockouts = evaluateGroups(tabellen);
      });

      test('creates a valid knockout structure', () {
        // Champions must always exist with at least 1 round
        expect(knockouts.champions.rounds, isNotEmpty,
            reason: 'Champions bracket is empty');

        // The first round should have bracketSize / 2 matches
        final firstRoundLen = knockouts.champions.rounds[0].length;
        expect(firstRoundLen, greaterThanOrEqualTo(1));

        // Final round has exactly 1 match
        expect(knockouts.champions.rounds.last.length, 1,
            reason: 'Champions final should be 1 match');

        // Each round halves
        for (int r = 1; r < knockouts.champions.rounds.length; r++) {
          expect(
            knockouts.champions.rounds[r].length,
            knockouts.champions.rounds[r - 1].length ~/ 2,
            reason: 'Round $r should have half the matches of round ${r - 1}',
          );
        }
      });

      test('all ${4 * n} teams appear exactly once across all leagues', () {
        final allTeamIds = <String>{};
        final allTeamIdsList = <String>[];

        void collectFromRounds(List<List<Match>> rounds) {
          for (final round in rounds) {
            for (final match in round) {
              if (match.teamId1.isNotEmpty) {
                allTeamIds.add(match.teamId1);
                allTeamIdsList.add(match.teamId1);
              }
              if (match.teamId2.isNotEmpty) {
                allTeamIds.add(match.teamId2);
                allTeamIdsList.add(match.teamId2);
              }
            }
          }
        }

        collectFromRounds(knockouts.champions.rounds);
        collectFromRounds(knockouts.europa.rounds);
        collectFromRounds(knockouts.conference.rounds);

        // Every original team should appear
        for (int g = 0; g < n; g++) {
          for (int p = 1; p <= 4; p++) {
            expect(allTeamIds.contains('g${g}p$p'), isTrue,
                reason: 'Team g${g}p$p missing from knockout brackets');
          }
        }

        // No team should appear more than once ACROSS LEAGUES.
        // Within a league, a team may appear in multiple rounds (advancing),
        // so check cross-league uniqueness.
        final champTeams = <String>{};
        final euroTeams = <String>{};
        final confTeams = <String>{};

        void collectUnique(List<List<Match>> rounds, Set<String> dest) {
          for (final round in rounds) {
            for (final match in round) {
              if (match.teamId1.isNotEmpty) dest.add(match.teamId1);
              if (match.teamId2.isNotEmpty) dest.add(match.teamId2);
            }
          }
        }

        collectUnique(knockouts.champions.rounds, champTeams);
        collectUnique(knockouts.europa.rounds, euroTeams);
        collectUnique(knockouts.conference.rounds, confTeams);

        // No overlap between leagues
        expect(champTeams.intersection(euroTeams), isEmpty,
            reason: 'Teams appear in both Champions and Europa');
        expect(champTeams.intersection(confTeams), isEmpty,
            reason: 'Teams appear in both Champions and Conference');
        expect(euroTeams.intersection(confTeams), isEmpty,
            reason: 'Teams appear in both Europa and Conference');
      });

      test('no same-group matchup in champions round 1', () {
        // Build group lookup
        final groupOf = <String, int>{};
        for (int g = 0; g < n; g++) {
          for (final row in tabellen.tables[g]) {
            groupOf[row.teamId] = g;
          }
        }

        // For ≤ 4-team brackets (≤ 2 rounds), R1 IS the semi-final, so
        // same-group matchups there are acceptable.
        if (knockouts.champions.rounds.length < 3) return;

        for (final match in knockouts.champions.rounds[0]) {
          if (match.teamId1.isEmpty || match.teamId2.isEmpty) continue;
          final g1 = groupOf[match.teamId1];
          final g2 = groupOf[match.teamId2];
          expect(g1 != g2, isTrue,
              reason:
                  'Same-group conflict in Champions R1: ${match.teamId1}(G$g1) vs ${match.teamId2}(G$g2)');
        }
      });

      test('all 1st-place teams are in champions', () {
        final champTeams = <String>{};
        for (final round in knockouts.champions.rounds) {
          for (final match in round) {
            if (match.teamId1.isNotEmpty) champTeams.add(match.teamId1);
            if (match.teamId2.isNotEmpty) champTeams.add(match.teamId2);
          }
        }

        for (int g = 0; g < n; g++) {
          final firstPlace = tabellen.tables[g][0].teamId;
          expect(champTeams.contains(firstPlace), isTrue,
              reason:
                  'Group $g first-place $firstPlace not found in Champions');
        }
      });

      test('all matches have valid table numbers', () {
        void check(List<List<Match>> rounds, String league) {
          for (final round in rounds) {
            for (final match in round) {
              expect(match.tableNumber, greaterThan(0),
                  reason: '$league match ${match.id} has no table assigned');
              expect(match.tableNumber, lessThanOrEqualTo(6),
                  reason: '$league match ${match.id} table > 6');
            }
          }
        }

        check(knockouts.champions.rounds, 'Champions');
        check(knockouts.europa.rounds, 'Europa');
        check(knockouts.conference.rounds, 'Conference');
      });

      test('super cup has correct match count', () {
        // 2 matches when both Europa and Conference exist, 1 otherwise
        final hasEuropa = knockouts.europa.rounds.isNotEmpty;
        final hasConference = knockouts.conference.rounds.isNotEmpty;
        final expected = (hasEuropa && hasConference) ? 2 : 1;
        expect(knockouts.superCup.matches.length, expected);
      });
    });
  }

  // ====================================================================
  // Distribution snapshot tests
  // ====================================================================

  group('evaluateGroups – bracket size distribution', () {
    // Expected distribution for each N:
    //   N: champBracket, euroBracket, confBracket
    // Europa is filled first (largest pow2 ≤ remaining), Conference gets rest.
    final expected = <int, List<int>>{
      2: [4, 4, 0], // rest 4 → euro 4
      3: [8, 4, 0], // rest 4 → euro 4
      4: [8, 8, 0], // rest 8 → euro 8
      5: [8, 8, 4], // demote 2 seconds → rest 12 → euro 8, conf 4
      6: [16, 8, 0], // rest 8 → euro 8
      7: [16, 8, 4], // rest 12 → euro 8, conf 4
      8: [16, 16, 0], // rest 16 → euro 16
      9: [16, 16, 4], // demote 2 seconds → rest 20 → euro 16, conf 4
      10: [16, 16, 8], // demote 4 seconds → rest 24 → euro 16, conf 8
    };

    for (final entry in expected.entries) {
      final n = entry.key;
      final sizes = entry.value;

      test('$n groups → champ=${sizes[0]}, euro=${sizes[1]}, conf=${sizes[2]}',
          () {
        final tabellen = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tabellen);

        // Champions bracket size = first round matches * 2
        final champBracket = ko.champions.rounds.isNotEmpty
            ? ko.champions.rounds[0].length * 2
            : 0;
        expect(champBracket, sizes[0], reason: 'Champions bracket mismatch');

        final euroBracket =
            ko.europa.rounds.isNotEmpty ? ko.europa.rounds[0].length * 2 : 0;
        expect(euroBracket, sizes[1], reason: 'Europa bracket mismatch');

        final confBracket = ko.conference.rounds.isNotEmpty
            ? ko.conference.rounds[0].length * 2
            : 0;
        expect(confBracket, sizes[2], reason: 'Conference bracket mismatch');
      });
    }
  });

  // ====================================================================
  // Seeding constraint checks
  // ====================================================================

  group('evaluateGroups – seeding quality', () {
    test('1st-place teams get top seeds (appear as teamId1 in round 1)', () {
      for (int n = 2; n <= 10; n++) {
        final tabellen = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tabellen);

        final firstPlaceIds = <String>{};
        for (int g = 0; g < n; g++) {
          firstPlaceIds.add(tabellen.tables[g][0].teamId);
        }

        // In standard seeding, top seeds are placed as teamId1
        // Check that most firsts appear as teamId1
        int asTeamId1 = 0;
        for (final match in ko.champions.rounds[0]) {
          if (firstPlaceIds.contains(match.teamId1)) asTeamId1++;
        }

        // At least half the firsts should be teamId1 (high seed position)
        expect(asTeamId1, greaterThanOrEqualTo((n + 1) ~/ 2),
            reason: 'Too few 1st-place teams as teamId1 for $n groups');
      }
    });

    test('no duplicate match IDs within a knockout structure', () {
      for (int n = 2; n <= 10; n++) {
        final tabellen = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tabellen);

        final ids = <String>{};

        void collectIds(List<List<Match>> rounds) {
          for (final round in rounds) {
            for (final match in round) {
              expect(ids.contains(match.id), isFalse,
                  reason: 'Duplicate match ID ${match.id} for $n groups');
              ids.add(match.id);
            }
          }
        }

        collectIds(ko.champions.rounds);
        collectIds(ko.europa.rounds);
        collectIds(ko.conference.rounds);
        for (final m in ko.superCup.matches) {
          expect(ids.contains(m.id), isFalse,
              reason: 'Duplicate match ID ${m.id} for $n groups');
          ids.add(m.id);
        }
      }
    });
  });

  // ====================================================================
  // createBracketRounds utility
  // ====================================================================

  group('createBracketRounds', () {
    test('creates correct round structure for size 16', () {
      final rounds = createBracketRounds(16, 'c');
      expect(rounds.length, 4); // 8, 4, 2, 1
      expect(rounds[0].length, 8);
      expect(rounds[1].length, 4);
      expect(rounds[2].length, 2);
      expect(rounds[3].length, 1);
    });

    test('creates correct round structure for size 4', () {
      final rounds = createBracketRounds(4, 'e');
      expect(rounds.length, 2); // 2, 1
      expect(rounds[0].length, 2);
      expect(rounds[1].length, 1);
    });

    test('returns empty for size < 2', () {
      expect(createBracketRounds(1, 'x'), isEmpty);
      expect(createBracketRounds(0, 'x'), isEmpty);
    });

    test('match IDs follow prefix+round+index pattern', () {
      final rounds = createBracketRounds(8, 'e');
      expect(rounds[0][0].id, 'e1-1');
      expect(rounds[0][3].id, 'e1-4');
      expect(rounds[1][0].id, 'e2-1');
      expect(rounds[2][0].id, 'e3-1');
    });
  });

  // ====================================================================
  // Verbose output for manual inspection
  // ====================================================================

  group('evaluateGroups – print bracket (manual inspection)', () {
    for (int n = 2; n <= 10; n++) {
      test('$n groups', () {
        final tab = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tab);

        final buf = StringBuffer();
        buf.writeln('═══════════════════════════════════');
        buf.writeln(' $n GROUPS → KNOCKOUT BRACKETS');
        buf.writeln('═══════════════════════════════════');

        void printLeague(String name, List<List<Match>> rounds) {
          if (rounds.isEmpty) {
            buf.writeln('  $name: (empty)');
            return;
          }
          buf.writeln(
              '  $name (bracket ${rounds[0].length * 2}, ${rounds.length} rounds):');
          for (int r = 0; r < rounds.length; r++) {
            buf.write('    R${r + 1}: ');
            for (final m in rounds[r]) {
              final t1 = m.teamId1.isEmpty ? '___' : m.teamId1;
              final t2 = m.teamId2.isEmpty ? '___' : m.teamId2;
              buf.write('[${m.id} T${m.tableNumber}: $t1 v $t2]  ');
            }
            buf.writeln();
          }
        }

        printLeague('CHAMPIONS', ko.champions.rounds);
        printLeague('EUROPA', ko.europa.rounds);
        printLeague('CONFERENCE', ko.conference.rounds);
        buf.writeln(
            '  SUPER CUP: ${ko.superCup.matches.map((m) => m.id).join(', ')}');
        buf.writeln();

        // ignore: avoid_print
        print(buf);
      });
    }
  });
}
