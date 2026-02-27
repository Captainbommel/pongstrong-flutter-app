import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/evaluation.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/groups/tabellen.dart';
import 'package:pongstrong/models/match/match.dart';

/// Creates a Tabellen from [n] groups of 4 teams with simulated results.
/// Team IDs follow the pattern: g{group}p{rank} (e.g. g0p1, g0p2, g0p3, g0p4).
Tabellen _makeTabellenForGroups(int n) {
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
      gp.groups[g][m].score1 = 10;
      gp.groups[g][m].score2 = 3 + g % 5;
    }
  }
  return evalGruppen(gp);
}

/// Maps each team to its bracket slot (0-indexed) from the knockout rounds.
///
/// Round 1 match m → slot 2m (teamId1), slot 2m+1 (teamId2).
/// Bye teams (removed from R1, placed in R2) are mapped back to their
/// original sub-bracket position.
Map<String, int> _buildSlotMap(List<List<Match>> rounds) {
  if (rounds.isEmpty) return {};
  final slots = <String, int>{};

  // Collect from round 1.
  for (int m = 0; m < rounds[0].length; m++) {
    if (rounds[0][m].teamId1.isNotEmpty) {
      slots[rounds[0][m].teamId1] = m * 2;
    }
    if (rounds[0][m].teamId2.isNotEmpty) {
      slots[rounds[0][m].teamId2] = m * 2 + 1;
    }
  }

  // Bye teams: appear in round 2 but not round 1.
  if (rounds.length > 1) {
    for (int m = 0; m < rounds[1].length; m++) {
      final t1 = rounds[1][m].teamId1;
      final t2 = rounds[1][m].teamId2;
      if (t1.isNotEmpty && !slots.containsKey(t1)) {
        // Came from R1 match 2*m → original slot in [4m, 4m+1].
        slots[t1] = m * 4;
      }
      if (t2.isNotEmpty && !slots.containsKey(t2)) {
        // Came from R1 match 2*m+1 → original slot in [4m+2, 4m+3].
        slots[t2] = m * 4 + 2;
      }
    }
  }
  return slots;
}

/// Returns the earliest round (1-indexed) where two teams at [slotI] and
/// [slotJ] could meet, assuming both win all their matches.
///
/// In an 8-team bracket:
///   - Slots 0,1 → round 1 (same R1 match)
///   - Slots 0,3 → round 2 (semi-final)
///   - Slots 0,5 → round 3 (final)
int _earliestMeetingRound(int slotI, int slotJ) {
  for (int r = 1; r <= 20; r++) {
    if ((slotI >> r) == (slotJ >> r)) return r;
  }
  return -1; // should never happen for valid slots in the same bracket
}

/// Groups teams in a league by their original group number.
Map<int, List<String>> _groupTeamsByGroup(
  Map<String, int> slots,
  Map<String, int> groupOf,
) {
  final grouped = <int, List<String>>{};
  for (final team in slots.keys) {
    final g = groupOf[team];
    if (g != null) {
      grouped.putIfAbsent(g, () => []).add(team);
    }
  }
  return grouped;
}

void main() {
  // ====================================================================
  // No same-group meeting before the semi-final
  // ====================================================================

  group('group separation – no meeting before semi-final', () {
    for (int n = 2; n <= 10; n++) {
      for (final league in ['Champions', 'Europa', 'Conference']) {
        test('$n groups – $league: same-group teams meet no earlier than semi',
            () {
          final tab = _makeTabellenForGroups(n);
          final ko = evaluateGroups(tab);

          final rounds = switch (league) {
            'Champions' => ko.champions.rounds,
            'Europa' => ko.europa.rounds,
            'Conference' => ko.conference.rounds,
            _ => <List<Match>>[],
          };

          if (rounds.isEmpty) return;
          // Only meaningful for brackets with ≥ 2 rounds.
          if (rounds.length < 2) return;

          final totalRounds = rounds.length;
          final semiRound = totalRounds - 1; // semi-final round number

          final groupOf = <String, int>{};
          for (int g = 0; g < n; g++) {
            for (final row in tab.tables[g]) {
              groupOf[row.teamId] = g;
            }
          }

          final slots = _buildSlotMap(rounds);
          final grouped = _groupTeamsByGroup(slots, groupOf);

          for (final entry in grouped.entries) {
            final teams = entry.value;
            for (int i = 0; i < teams.length; i++) {
              for (int j = i + 1; j < teams.length; j++) {
                final slotA = slots[teams[i]]!;
                final slotB = slots[teams[j]]!;
                final earliest = _earliestMeetingRound(slotA, slotB);

                expect(earliest, greaterThanOrEqualTo(semiRound),
                    reason: '$league – Group ${entry.key}: '
                        '${teams[i]}(slot $slotA) vs '
                        '${teams[j]}(slot $slotB) could meet in '
                        'R$earliest, but semi-final is R$semiRound');
              }
            }
          }
        });
      }
    }
  });

  // ====================================================================
  // No R1 same-group conflict in brackets with ≥ 3 rounds (8+ teams)
  // (For 4-team brackets, R1 IS the semi-final so conflicts are OK)
  // ====================================================================

  group('group separation – no R1 conflict (8+ team brackets)', () {
    for (int n = 2; n <= 10; n++) {
      test('$n groups: no same-group matchup in R1 of 8+ team leagues', () {
        final tab = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tab);

        final groupOf = <String, int>{};
        for (int g = 0; g < n; g++) {
          for (final row in tab.tables[g]) {
            groupOf[row.teamId] = g;
          }
        }

        void checkR1(List<List<Match>> rounds, String league) {
          if (rounds.isEmpty) return;
          // Only check brackets with ≥ 3 rounds (8+ teams).
          // In 4-team brackets, R1 is the semi-final — same-group is OK.
          if (rounds.length < 3) return;

          for (final match in rounds[0]) {
            if (match.teamId1.isEmpty || match.teamId2.isEmpty) continue;
            expect(groupOf[match.teamId1], isNot(groupOf[match.teamId2]),
                reason: '$league R1: ${match.teamId1} vs ${match.teamId2} '
                    'are from the same group');
          }
        }

        checkR1(ko.champions.rounds, 'Champions');
        checkR1(ko.europa.rounds, 'Europa');
        checkR1(ko.conference.rounds, 'Conference');
      });
    }
  });

  // ====================================================================
  // Earliest meeting round analysis (diagnostic / manual inspection)
  // ====================================================================

  group('group separation – earliest meeting round analysis', () {
    for (int n = 2; n <= 10; n++) {
      test('$n groups: report earliest meeting round for all same-group pairs',
          () {
        final tab = _makeTabellenForGroups(n);
        final ko = evaluateGroups(tab);

        final groupOf = <String, int>{};
        for (int g = 0; g < n; g++) {
          for (final row in tab.tables[g]) {
            groupOf[row.teamId] = g;
          }
        }

        void analyzeLeague(String name, List<List<Match>> rounds) {
          if (rounds.isEmpty) {
            // ignore: avoid_print
            print('  $name: (empty)');
            return;
          }

          final slots = _buildSlotMap(rounds);
          final totalRounds = rounds.length;
          final grouped = _groupTeamsByGroup(slots, groupOf);

          final buf = StringBuffer();
          buf.writeln('  $name ($totalRounds rounds, '
              'bracket ${rounds[0].length * 2}):');

          int minEarliest = totalRounds;
          bool hasPairs = false;

          for (final entry in grouped.entries) {
            final teams = entry.value;
            if (teams.length < 2) continue;
            hasPairs = true;

            for (int i = 0; i < teams.length; i++) {
              for (int j = i + 1; j < teams.length; j++) {
                final earliest =
                    _earliestMeetingRound(slots[teams[i]]!, slots[teams[j]]!);
                minEarliest = min(minEarliest, earliest);
                buf.writeln('    Group ${entry.key}: '
                    '${teams[i]}(slot ${slots[teams[i]]}) vs '
                    '${teams[j]}(slot ${slots[teams[j]]}) → '
                    'earliest R$earliest of $totalRounds '
                    '${earliest >= totalRounds - 1 ? "✓ OK (semi or later)" : "✗ TOO EARLY"}');
              }
            }
          }

          if (hasPairs) {
            buf.writeln('    → Worst case: R$minEarliest of $totalRounds');
          } else {
            buf.writeln('    → No same-group pairs in this league');
          }
          // ignore: avoid_print
          print(buf);
        }

        // ignore: avoid_print
        print('\n═══ $n GROUPS ═══');
        analyzeLeague('CHAMPIONS', ko.champions.rounds);
        analyzeLeague('EUROPA', ko.europa.rounds);
        analyzeLeague('CONFERENCE', ko.conference.rounds);
      });
    }
  });
}
