import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/match_queue.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/gruppenphase.dart';
import 'package:pongstrong/models/groups.dart';
import 'package:pongstrong/models/knockouts.dart';

void main() {
  group('MatchQueue', () {
    test('creates empty queue', () {
      final queue = MatchQueue();
      expect(queue.waiting, isEmpty);
      expect(queue.playing, isEmpty);
    });

    test('creates queue with waiting and playing matches', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11')],
          [Match(id: 'g12')],
        ],
        playing: [Match(id: 'g13')],
      );

      expect(queue.waiting.length, 2);
      expect(queue.playing.length, 1);
    });
  });

  group('switchPlaying', () {
    test('moves match from waiting to playing when table is free', () {
      final match = Match(id: 'g11', tischNr: 1);
      final queue = MatchQueue(
        waiting: [
          [match],
        ],
        playing: [],
      );

      final result = queue.switchPlaying('g11');

      expect(result, true);
      expect(queue.waiting[0], isEmpty);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g11');
    });

    test('does not move match when table is occupied', () {
      final match1 = Match(id: 'g11', tischNr: 1);
      final match2 = Match(id: 'g12', tischNr: 1);
      final queue = MatchQueue(
        waiting: [
          [match2],
        ],
        playing: [match1],
      );

      final result = queue.switchPlaying('g12');

      expect(result, false);
      expect(queue.waiting[0].length, 1);
      expect(queue.playing.length, 1);
    });

    test('returns false for non-existent match', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11')]
        ],
        playing: [],
      );

      final result = queue.switchPlaying('invalid');

      expect(result, false);
    });

    test('can move match from deeper in a waiting list (not just first)', () {
      // Group has 3 matches: table 1 (occupied), table 2, table 3
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 2),
            Match(id: 'g13', tischNr: 3),
          ],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      // g12 is at index 1, but its table (2) is free
      final result = queue.switchPlaying('g12');

      expect(result, true);
      expect(queue.waiting[0].length, 2);
      expect(queue.playing.length, 2);
      expect(queue.playing[1].id, 'g12');
    });

    test('does not move deeper match when its table is occupied', () {
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 1),
          ],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      final result = queue.switchPlaying('g12');

      expect(result, false);
      expect(queue.waiting[0].length, 2);
    });
  });

  group('removeFromPlaying', () {
    test('removes match from playing', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [
          Match(id: 'g11'),
          Match(id: 'g12'),
        ],
      );

      final result = queue.removeFromPlaying('g11');

      expect(result, true);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g12');
    });

    test('returns false for non-existent match', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [Match(id: 'g11')],
      );

      final result = queue.removeFromPlaying('invalid');

      expect(result, false);
      expect(queue.playing.length, 1);
    });
  });

  group('nextMatches', () {
    test('returns matches with free tables', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g12', tischNr: 2)],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 2);
      expect(next[0].id, 'g11');
      expect(next[1].id, 'g12');
    });

    test('excludes matches with occupied tables', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g12', tischNr: 2)],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      final next = queue.nextMatches();

      expect(next.length, 1);
      expect(next[0].id, 'g12');
    });

    test('returns empty list when no matches with free tables', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      final next = queue.nextMatches();

      expect(next, isEmpty);
    });

    test('fills extra tables from deeper in group queues', () {
      // 2 groups, but matches on 4 different tables → all 4 should be ready
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 3),
          ],
          [
            Match(id: 'g21', tischNr: 2),
            Match(id: 'g22', tischNr: 4),
          ],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 4);
      final ids = next.map((m) => m.id).toSet();
      expect(ids, containsAll(['g11', 'g12', 'g21', 'g22']));
    });

    test('round-robins fairly across groups', () {
      // 2 groups each with 3 matches on different tables
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 3),
            Match(id: 'g13', tischNr: 5),
          ],
          [
            Match(id: 'g21', tischNr: 2),
            Match(id: 'g22', tischNr: 4),
            Match(id: 'g23', tischNr: 6),
          ],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      // All 6 tables free → all 6 matches ready
      expect(next.length, 6);
    });

    test('skips matches on already-claimed tables', () {
      // Both groups compete for table 1, second match in group has unique table
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 3),
          ],
          [
            Match(id: 'g21', tischNr: 1),
            Match(id: 'g22', tischNr: 4),
          ],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      // Table 1 can only be given to one match; the other group's second
      // match on table 4 should still show up
      expect(next.length, 3);
      final tables = next.map((m) => m.tischNr).toSet();
      expect(tables, containsAll([1, 3, 4]));
    });

    test('does not return matches on occupied tables even if deeper', () {
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 1), // same table, still occupied
            Match(id: 'g13', tischNr: 3),
          ],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      final next = queue.nextMatches();

      // Only g13 on table 3 is available
      expect(next.length, 1);
      expect(next[0].id, 'g13');
    });
  });

  group('nextNextMatches', () {
    test('returns matches with occupied tables', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g12', tischNr: 2)],
        ],
        playing: [Match(id: 'playing', tischNr: 1)],
      );

      final nextNext = queue.nextNextMatches();

      expect(nextNext.length, 1);
      expect(nextNext[0].id, 'g11');
    });

    test('excludes matches already returned by nextMatches', () {
      // 2 groups, deeper matches fill extra tables
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 3),
          ],
          [
            Match(id: 'g21', tischNr: 2),
            Match(id: 'g22', tischNr: 4),
          ],
        ],
        playing: [],
      );

      final nextNext = queue.nextNextMatches();

      // All 4 matches are ready via nextMatches, so nextNext should be empty
      expect(nextNext, isEmpty);
    });

    test('returns first blocked match per group', () {
      // Group 0: all on table 1 (only first is ready, rest blocked)
      // Group 1: on table 2 (ready)
      final queue = MatchQueue(
        waiting: [
          [
            Match(id: 'g11', tischNr: 1),
            Match(id: 'g12', tischNr: 1),
            Match(id: 'g13', tischNr: 1),
          ],
          [
            Match(id: 'g21', tischNr: 2),
          ],
        ],
        playing: [],
      );

      final nextNext = queue.nextNextMatches();

      // g11 and g21 are ready. g12 is first blocked in group 0.
      expect(nextNext.length, 1);
      expect(nextNext[0].id, 'g12');
    });
  });

  group('isFree', () {
    test('returns true for free table', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [Match(tischNr: 1)],
      );

      expect(queue.isFree(2), true);
    });

    test('returns false for occupied table', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [Match(tischNr: 1)],
      );

      expect(queue.isFree(1), false);
    });
  });

  group('contains', () {
    test('returns true for match in waiting', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11')],
        ],
        playing: [],
      );

      expect(queue.contains(Match(id: 'g11')), true);
    });

    test('returns true for match in playing', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [Match(id: 'g11')],
      );

      expect(queue.contains(Match(id: 'g11')), true);
    });

    test('returns false for match not in queue', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11')]
        ],
        playing: [Match(id: 'g12')],
      );

      expect(queue.contains(Match(id: 'g13')), false);
    });
  });

  group('isEmpty', () {
    test('returns true for completely empty queue', () {
      final queue = MatchQueue(
        waiting: [[], [], []],
        playing: [],
      );

      expect(queue.isEmpty(), true);
    });

    test('returns false when waiting has matches', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11')],
        ],
        playing: [],
      );

      expect(queue.isEmpty(), false);
    });

    test('returns false when playing has matches', () {
      final queue = MatchQueue(
        waiting: [],
        playing: [Match(id: 'g11')],
      );

      expect(queue.isEmpty(), false);
    });
  });

  group('updateKnockQueue', () {
    test('adds ready matches to queue', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Set up first match
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      queue.updateKnockQueue(knockouts);

      // Should have added the ready match
      expect(queue.contains(knockouts.champions.rounds[0][0]), true);
    });

    test('does not add unready matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Don't set teams - match not ready
      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      queue.updateKnockQueue(knockouts);

      expect(queue.isEmpty(), true);
    });

    test('does not add finished matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].done = true;

      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      queue.updateKnockQueue(knockouts);

      expect(queue.isEmpty(), true);
    });

    test('does not add duplicate matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      queue.updateKnockQueue(knockouts);
      final countAfterFirst = queue.waiting.expand((w) => w).length;

      queue.updateKnockQueue(knockouts);
      final countAfterSecond = queue.waiting.expand((w) => w).length;

      expect(countAfterFirst, countAfterSecond);
    });
  });

  group('create', () {
    test('creates queue from Gruppenphase', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      // MatchQueue.create produces one waiting slot per group (keyed by group
      // index, not by table number). With 2 groups → 2 slots.
      expect(queue.waiting.length, 2);
      expect(queue.playing, isEmpty);
    });

    test('distributes matches across all tables', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      // All 6 tables should have matches
      for (var line in queue.waiting) {
        expect(line.isNotEmpty, true);
      }
    });

    test('includes all matches from Gruppenphase', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      final totalMatches = queue.waiting.expand((w) => w).length;
      expect(totalMatches, 6); // 6 matches per group
    });
  });

  group('JSON serialization', () {
    test('round trip preserves data', () {
      final original = MatchQueue(
        waiting: [
          [Match(id: 'g11', teamId1: 't1', teamId2: 't2')],
          [Match(id: 'g12', teamId1: 't3', teamId2: 't4')],
        ],
        playing: [Match(id: 'g13', teamId1: 't5', teamId2: 't6')],
      );

      final json = original.toJson();
      final restored = MatchQueue.fromJson(json);

      expect(restored.waiting.length, 2);
      expect(restored.waiting[0][0].id, 'g11');
      expect(restored.playing.length, 1);
      expect(restored.playing[0].id, 'g13');
    });
  });

  group('clone', () {
    test('creates deep copy', () {
      final original = MatchQueue(
        waiting: [
          [Match(id: 'g11')],
        ],
        playing: [Match(id: 'g12')],
      );

      final cloned = original.clone();

      // Same values
      expect(cloned.waiting[0][0].id, 'g11');
      expect(cloned.playing[0].id, 'g12');

      // But different objects
      cloned.playing[0].score1 = 10;
      expect(original.playing[0].score1, 0);
    });
  });

  // =========================================================================
  // EDGE-CASE & ADDITIONAL TESTS
  // =========================================================================

  group('clearQueue', () {
    test('removes all waiting and playing matches', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11'), Match(id: 'g12')],
          [Match(id: 'g21')],
        ],
        playing: [Match(id: 'p1')],
      );

      queue.clearQueue();

      expect(queue.isEmpty(), true);
      // Waiting slots should still exist (just empty)
      expect(queue.waiting.length, 2);
      expect(queue.waiting[0], isEmpty);
      expect(queue.waiting[1], isEmpty);
      expect(queue.playing, isEmpty);
    });

    test('clearQueue on already-empty queue is a no-op', () {
      final queue = MatchQueue(
        waiting: [[], []],
        playing: [],
      );

      queue.clearQueue();

      expect(queue.isEmpty(), true);
    });
  });

  group('isEmpty – default constructor', () {
    test('default-constructed queue is empty', () {
      final queue = MatchQueue();
      expect(queue.isEmpty(), true);
    });
  });

  group('switchPlaying – multi-group', () {
    test('finds and moves match from second waiting group', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g21', tischNr: 2)],
        ],
        playing: [],
      );

      final result = queue.switchPlaying('g21');

      expect(result, true);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g21');
      expect(queue.waiting[1], isEmpty);
    });

    test('finds and moves match from last waiting group', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g21', tischNr: 2)],
          [Match(id: 'g31', tischNr: 3)],
        ],
        playing: [],
      );

      final result = queue.switchPlaying('g31');

      expect(result, true);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g31');
    });
  });

  group('nextMatches – table contention', () {
    test('returns only one match when all on same table', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g21', tischNr: 1)],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 1);
    });

    test('returns match per free table across groups', () {
      final queue = MatchQueue(
        waiting: [
          [Match(id: 'g11', tischNr: 1)],
          [Match(id: 'g21', tischNr: 2)],
          [Match(id: 'g31', tischNr: 3)],
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 3);
      // All on different tables
      final tables = next.map((m) => m.tischNr).toSet();
      expect(tables, {1, 2, 3});
    });
  });

  group('updateKnockQueue – bounds safety', () {
    test('does not crash when match has tischNr 0 (unmapped)', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      // Do NOT call mapTables — tischNr defaults to 0

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      // tischNr is 0 → waiting[0 - 1] = waiting[-1] would crash

      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      // After fix: should skip matches with invalid tischNr
      // instead of crashing with RangeError
      queue.updateKnockQueue(knockouts);

      // The match with tischNr 0 should NOT have been added
      expect(queue.isEmpty(), true);
    });

    test('does not crash when tischNr exceeds waiting length', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].tischNr = 10; // Only 6 slots

      final queue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );

      // After fix: should skip matches with out-of-bounds tischNr
      queue.updateKnockQueue(knockouts);

      expect(queue.isEmpty(), true);
    });
  });
}
