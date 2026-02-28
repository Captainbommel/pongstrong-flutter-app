import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/evaluation.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/groups/tabellen.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/models/match/match_queue.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

/// Creates a fully-evaluated Tabellen for [n] groups (deterministic rankings).
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

/// Finishes a match with teamId1 winning 10-5.
void finishMatch(Match match) {
  match.score1 = 10;
  match.score2 = 5;
  match.done = true;
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // Basic advancement through dynamically-created brackets
  // ═════════════════════════════════════════════════════════════════════════

  for (final n in [2, 3, 5, 6, 8, 10]) {
    group('KO advancement – $n groups', () {
      late Knockouts ko;

      setUp(() {
        final tabellen = _makeTabellenForGroups(n);
        ko = evaluateGroups(tabellen);
      });

      test('champions round 1 winners advance to round 2', () {
        final r1 = ko.champions.rounds[0];

        // Finish all round-1 matches that have both teams
        for (final m in r1) {
          if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty) {
            finishMatch(m);
          }
        }
        ko.update();

        // Every round-2 slot should be populated
        final r2 = ko.champions.rounds[1];
        for (int i = 0; i < r2.length; i++) {
          expect(
            r2[i].teamId1.isNotEmpty || r2[i].teamId2.isNotEmpty,
            isTrue,
            reason: 'Champions R2 match $i should have at least 1 team '
                'after all R1 matches finish ($n groups)',
          );
        }
      });

      test('champions full playthrough to final', () {
        // Play through every round
        for (int r = 0; r < ko.champions.rounds.length; r++) {
          for (final m in ko.champions.rounds[r]) {
            if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
              finishMatch(m);
            }
          }
          ko.update();
        }

        // Final should be done
        final champFinal = ko.champions.rounds.last[0];
        expect(champFinal.done, isTrue,
            reason: 'Champions final should be done ($n groups)');
        expect(champFinal.getWinnerId(), isNotNull,
            reason: 'Champions final should have a winner ($n groups)');
      });

      test('europa full playthrough to final', () {
        if (ko.europa.rounds.isEmpty) return; // skip if no europa

        for (int r = 0; r < ko.europa.rounds.length; r++) {
          for (final m in ko.europa.rounds[r]) {
            if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
              finishMatch(m);
            }
          }
          ko.update();
        }

        final euroFinal = ko.europa.rounds.last[0];
        expect(euroFinal.done, isTrue,
            reason: 'Europa final should be done ($n groups)');
        expect(euroFinal.getWinnerId(), isNotNull,
            reason: 'Europa final should have a winner ($n groups)');
      });

      test('conference full playthrough to final', () {
        if (ko.conference.rounds.isEmpty) return; // skip if no conference

        for (int r = 0; r < ko.conference.rounds.length; r++) {
          for (final m in ko.conference.rounds[r]) {
            if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
              finishMatch(m);
            }
          }
          ko.update();
        }

        final confFinal = ko.conference.rounds.last[0];
        expect(confFinal.done, isTrue,
            reason: 'Conference final should be done ($n groups)');
        expect(confFinal.getWinnerId(), isNotNull,
            reason: 'Conference final should have a winner ($n groups)');
      });

      test('full tournament playthrough including super cup', () {
        // Play ALL leagues to completion
        void playAllReady() {
          bool progress = true;
          while (progress) {
            progress = false;
            for (final round in ko.champions.rounds) {
              for (final m in round) {
                if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
                  finishMatch(m);
                  progress = true;
                }
              }
            }
            for (final round in ko.europa.rounds) {
              for (final m in round) {
                if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
                  finishMatch(m);
                  progress = true;
                }
              }
            }
            for (final round in ko.conference.rounds) {
              for (final m in round) {
                if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
                  finishMatch(m);
                  progress = true;
                }
              }
            }
            for (final m in ko.superCup.matches) {
              if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
                finishMatch(m);
                progress = true;
              }
            }
            ko.update();
          }
        }

        playAllReady();

        // Super cup match 2 (the grand final) should be done
        if (ko.superCup.matches.length >= 2) {
          expect(ko.superCup.matches[1].done, isTrue,
              reason: 'Super Cup final should be done ($n groups)');
          expect(ko.superCup.matches[1].getWinnerId(), isNotNull,
              reason: 'Super Cup final should have a winner ($n groups)');
        }
      });
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Super cup with empty Conference
  // ═════════════════════════════════════════════════════════════════════════

  group('Super cup – empty Conference league', () {
    // For N=3: Conference is empty, only Europa + Champions
    late Knockouts ko;

    setUp(() {
      final tabellen = _makeTabellenForGroups(3);
      ko = evaluateGroups(tabellen);
      // Verify Conference is indeed empty
      expect(ko.conference.rounds, isEmpty,
          reason: 'N=3 should have empty Conference');
    });

    test('europa winner auto-advances to super cup match 1', () {
      // Play Europa to completion
      for (int r = 0; r < ko.europa.rounds.length; r++) {
        for (final m in ko.europa.rounds[r]) {
          if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
            finishMatch(m);
          }
        }
        ko.update();
      }

      final euroWinner = ko.europa.rounds.last[0].getWinnerId();
      expect(euroWinner, isNotNull);

      // With no Conference, Europa winner should auto-advance to match 1
      expect(ko.superCup.matches[1].teamId1, euroWinner,
          reason: 'Europa winner should auto-advance to Super Cup match 1');
    });

    test('super cup match 0 should be playable without Conference', () {
      // With Conference empty, super cup match 0 needs to be handled:
      // either auto-advance Europa winner, or restructure super cup.
      // Play Europa to completion
      for (int r = 0; r < ko.europa.rounds.length; r++) {
        for (final m in ko.europa.rounds[r]) {
          if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
            finishMatch(m);
          }
        }
        ko.update();
      }

      final sc0 = ko.superCup.matches[0];
      // Super cup match 0 should either:
      // a) have both teams set (if we find a second team), or
      // b) the Europa winner should auto-advance to match 1
      final hasMatch = sc0.teamId1.isNotEmpty && sc0.teamId2.isNotEmpty;
      final autoAdvanced = ko.superCup.matches[1].teamId1.isNotEmpty;

      expect(hasMatch || autoAdvanced, isTrue,
          reason: 'With empty Conference, Europa winner must either have an '
              'opponent in SC match 0 or auto-advance to SC match 1');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Match queue discovery
  // ═════════════════════════════════════════════════════════════════════════

  group('Match queue – KO discovery', () {
    test('initial queue contains all ready round-1 matches', () {
      final tabellen = _makeTabellenForGroups(5);
      final ko = evaluateGroups(tabellen);

      final queue = MatchQueue();
      queue.updateKnockQueue(ko);

      // Count matches that should be in queue (both teams set, not done)
      int expectedReady = 0;
      for (final m in ko.champions.rounds[0]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          expectedReady++;
        }
      }
      for (final m in ko.europa.rounds[0]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          expectedReady++;
        }
      }
      if (ko.conference.rounds.isNotEmpty) {
        for (final m in ko.conference.rounds[0]) {
          if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
            expectedReady++;
          }
        }
      }

      final totalInQueue = queue.queue.length;
      expect(totalInQueue, expectedReady,
          reason: 'Queue should contain all ready R1 matches');
    });

    test('new matches are queued after round 1 completion', () {
      final tabellen = _makeTabellenForGroups(5);
      final ko = evaluateGroups(tabellen);

      // Finish all round 1 champions matches
      for (final m in ko.champions.rounds[0]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty) {
          finishMatch(m);
        }
      }
      ko.update();

      final queue = MatchQueue();
      queue.updateKnockQueue(ko);

      // Round 2 matches should now be in the queue
      int r2Ready = 0;
      for (final m in ko.champions.rounds[1]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          r2Ready++;
        }
      }
      expect(r2Ready, greaterThan(0),
          reason: 'Champions R2 should have ready matches');

      // Verify these matches are in the queue
      final allQueuedIds = queue.queue.map((e) => e.matchId).toSet();
      for (final m in ko.champions.rounds[1]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          expect(allQueuedIds.contains(m.id), isTrue,
              reason: 'Champions R2 match ${m.id} should be in queue');
        }
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Advancement correctness (winners go to correct slots)
  // ═════════════════════════════════════════════════════════════════════════

  group('Advancement slot correctness', () {
    test('match 0 winner → R2 match 0 slot, match 1 winner → R2 match 0 slot',
        () {
      final tabellen = _makeTabellenForGroups(5);
      final ko = evaluateGroups(tabellen);

      final m0 = ko.champions.rounds[0][0];
      final m1 = ko.champions.rounds[0][1];

      // Finish match 0 (teamId1 wins)
      finishMatch(m0);
      ko.update();
      expect(ko.champions.rounds[1][0].teamId1, m0.teamId1,
          reason: 'Match 0 winner should go to R2[0].teamId1');

      // Finish match 1 (teamId1 wins)
      finishMatch(m1);
      ko.update();
      expect(ko.champions.rounds[1][0].teamId2, m1.teamId1,
          reason: 'Match 1 winner should go to R2[0].teamId2');
    });

    test('match 2 and 3 winners → R2 match 1', () {
      final tabellen = _makeTabellenForGroups(5);
      final ko = evaluateGroups(tabellen);

      if (ko.champions.rounds[0].length < 4) {
        return; // need at least 4 R1 matches
      }

      final m2 = ko.champions.rounds[0][2];
      final m3 = ko.champions.rounds[0][3];

      finishMatch(m2);
      finishMatch(m3);
      ko.update();

      expect(ko.champions.rounds[1][1].teamId1, m2.teamId1,
          reason: 'Match 2 winner → R2[1].teamId1');
      expect(ko.champions.rounds[1][1].teamId2, m3.teamId1,
          reason: 'Match 3 winner → R2[1].teamId2');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Edge case: update() called multiple times is idempotent
  // ═════════════════════════════════════════════════════════════════════════

  group('Idempotency', () {
    test('calling update() multiple times does not duplicate teams', () {
      final tabellen = _makeTabellenForGroups(5);
      final ko = evaluateGroups(tabellen);

      // Finish one match
      finishMatch(ko.champions.rounds[0][0]);

      ko.update();
      final after1 = ko.champions.rounds[1][0].teamId1;

      ko.update();
      ko.update();
      final after3 = ko.champions.rounds[1][0].teamId1;

      expect(after1, after3);
      // teamId2 should still be empty (only one feeder match done)
      expect(ko.champions.rounds[1][0].teamId2, isEmpty);
    });
  });
}
