import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/models/match/match_queue.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

/// Shorthand to create a MatchQueueEntry.
MatchQueueEntry _entry(Match m, {int groupRank = 0, int tableOrder = 0}) =>
    MatchQueueEntry(match: m, groupRank: groupRank, tableOrder: tableOrder);

void main() {
  // ═══════════════════════════════════════════════════════════════
  // MatchQueueEntry
  // ═══════════════════════════════════════════════════════════════

  group('MatchQueueEntry', () {
    test('convenience getters delegate to match', () {
      final entry = MatchQueueEntry(
        match: Match(id: 'g1-1', tableNumber: 3),
        groupRank: 2,
        tableOrder: 1,
      );
      expect(entry.matchId, 'g1-1');
      expect(entry.tableNumber, 3);
    });

    test('JSON round-trip preserves data', () {
      final entry = MatchQueueEntry(
        match: Match(id: 'g1-1', teamId1: 'a', teamId2: 'b', tableNumber: 2),
        groupRank: 5,
        tableOrder: 3,
      );
      final json = entry.toJson();
      final restored = MatchQueueEntry.fromJson(json);

      expect(restored.matchId, 'g1-1');
      expect(restored.groupRank, 5);
      expect(restored.tableOrder, 3);
      expect(restored.match.teamId1, 'a');
    });

    test('equality based on match, groupRank, tableOrder', () {
      final a = MatchQueueEntry(
        match: Match(id: 'x', tableNumber: 1),
      );
      final b = MatchQueueEntry(
        match: Match(id: 'x', tableNumber: 1),
      );
      final c = MatchQueueEntry(
        match: Match(id: 'x', tableNumber: 1),
        groupRank: 1,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // MatchQueue – construction
  // ═══════════════════════════════════════════════════════════════

  group('MatchQueue', () {
    test('creates empty queue', () {
      final queue = MatchQueue();
      expect(queue.queue, isEmpty);
      expect(queue.playing, isEmpty);
    });

    test('creates queue with entries and playing matches', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11')),
          _entry(Match(id: 'g12')),
        ],
        playing: [Match(id: 'g13')],
      );

      expect(queue.queue.length, 2);
      expect(queue.playing.length, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // switchPlaying
  // ═══════════════════════════════════════════════════════════════

  group('switchPlaying', () {
    test('moves match from queue to playing when table is free', () {
      final match = Match(id: 'g11', tableNumber: 1);
      final queue = MatchQueue(
        queue: [_entry(match)],
        playing: [],
      );

      final result = queue.switchPlaying('g11');

      expect(result, true);
      expect(queue.queue, isEmpty);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g11');
    });

    test('does not move match when table is occupied', () {
      final match1 = Match(id: 'g11', tableNumber: 1);
      final match2 = Match(id: 'g12', tableNumber: 1);
      final queue = MatchQueue(
        queue: [_entry(match2)],
        playing: [match1],
      );

      final result = queue.switchPlaying('g12');

      expect(result, false);
      expect(queue.queue.length, 1);
      expect(queue.playing.length, 1);
    });

    test('returns false for non-existent match', () {
      final queue = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [],
      );

      final result = queue.switchPlaying('invalid');

      expect(result, false);
    });

    test('can move match from deeper in the queue (not just first)', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 2)),
          _entry(Match(id: 'g13', tableNumber: 3), groupRank: 1),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      // g12 is at index 1, but its table (2) is free
      final result = queue.switchPlaying('g12');

      expect(result, true);
      expect(queue.queue.length, 2);
      expect(queue.playing.length, 2);
      expect(queue.playing[1].id, 'g12');
    });

    test('does not move match when its table is occupied', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 1)),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final result = queue.switchPlaying('g12');

      expect(result, false);
      expect(queue.queue.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // removeFromPlaying
  // ═══════════════════════════════════════════════════════════════

  group('removeFromPlaying', () {
    test('removes match from playing', () {
      final queue = MatchQueue(
        queue: [],
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
        queue: [],
        playing: [Match(id: 'g11')],
      );

      final result = queue.removeFromPlaying('invalid');

      expect(result, false);
      expect(queue.playing.length, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // nextMatches – top-to-bottom scheduling
  // ═══════════════════════════════════════════════════════════════

  group('nextMatches', () {
    test('returns matches with free tables', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 2)),
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
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 2)),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final next = queue.nextMatches();

      expect(next.length, 1);
      expect(next[0].id, 'g12');
    });

    test('returns empty list when no matches with free tables', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final next = queue.nextMatches();

      expect(next, isEmpty);
    });

    test('fills all free tables from sorted queue', () {
      // 4 matches on 4 different tables → all should be ready
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g12', tableNumber: 3), groupRank: 1),
          _entry(Match(id: 'g22', tableNumber: 4), groupRank: 1),
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 4);
      final ids = next.map((m) => m.id).toSet();
      expect(ids, containsAll(['g11', 'g21', 'g12', 'g22']));
    });

    test('picks first match per table (higher priority first)', () {
      // Two matches on table 1, first one (lower groupRank) wins
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 1), groupRank: 1),
          _entry(Match(id: 'g21', tableNumber: 2)),
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 2);
      expect(next[0].id, 'g11'); // table 1
      expect(next[1].id, 'g21'); // table 2
    });

    test('handles more tables than groups correctly', () {
      // This was the old bug: 6 tables, 3 groups. The flat queue handles it.
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g31', tableNumber: 3)),
          _entry(Match(id: 'g12', tableNumber: 4), groupRank: 1),
          _entry(Match(id: 'g22', tableNumber: 5), groupRank: 1),
          _entry(Match(id: 'g32', tableNumber: 6), groupRank: 1),
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      // All 6 tables free → all 6 matches ready
      expect(next.length, 6);
    });

    test('does not return matches on occupied tables even if deeper', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 1), groupRank: 1),
          _entry(Match(id: 'g13', tableNumber: 3), groupRank: 2),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final next = queue.nextMatches();

      // Only g13 on table 3 is available
      expect(next.length, 1);
      expect(next[0].id, 'g13');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // nextNextMatches
  // ═══════════════════════════════════════════════════════════════

  group('nextNextMatches', () {
    test('returns matches blocked by occupied tables', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 2)),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final nextNext = queue.nextNextMatches();

      expect(nextNext.length, 1);
      expect(nextNext[0].id, 'g11');
    });

    test('excludes matches already returned by nextMatches', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g12', tableNumber: 3), groupRank: 1),
          _entry(Match(id: 'g22', tableNumber: 4), groupRank: 1),
        ],
        playing: [],
      );

      final nextNext = queue.nextNextMatches();

      // All 4 matches are ready via nextMatches → nextNext empty
      expect(nextNext, isEmpty);
    });

    test('returns first blocked match per table', () {
      // Table 1 has 3 matches: first is next, second is nextNext
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g12', tableNumber: 1), groupRank: 1),
          _entry(Match(id: 'g13', tableNumber: 1), groupRank: 2),
        ],
        playing: [],
      );

      final nextNext = queue.nextNextMatches();

      // g11 → next (table 1), g21 → next (table 2),
      // g12 → nextNext (table 1 claimed), g13 → skipped (table 1 already in nextNext)
      expect(nextNext.length, 1);
      expect(nextNext[0].id, 'g12');
    });

    test('works correctly when table is occupied by playing match', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g12', tableNumber: 2)),
          _entry(Match(id: 'g13', tableNumber: 1), groupRank: 1),
        ],
        playing: [Match(id: 'playing', tableNumber: 1)],
      );

      final next = queue.nextMatches();
      final nextNext = queue.nextNextMatches();

      // g12 is next (table 2 free). g11 is blocked (table 1 occupied) → nextNext.
      expect(next.length, 1);
      expect(next[0].id, 'g12');
      expect(nextNext.length, 1);
      expect(nextNext[0].id, 'g11');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // isFree
  // ═══════════════════════════════════════════════════════════════

  group('isFree', () {
    test('returns true for free table', () {
      final queue = MatchQueue(
        queue: [],
        playing: [Match(tableNumber: 1)],
      );

      expect(queue.isFree(2), true);
    });

    test('returns false for occupied table', () {
      final queue = MatchQueue(
        queue: [],
        playing: [Match(tableNumber: 1)],
      );

      expect(queue.isFree(1), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // contains
  // ═══════════════════════════════════════════════════════════════

  group('contains', () {
    test('returns true for match in queue', () {
      final queue = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [],
      );

      expect(queue.contains(Match(id: 'g11')), true);
    });

    test('returns true for match in playing', () {
      final queue = MatchQueue(
        queue: [],
        playing: [Match(id: 'g11')],
      );

      expect(queue.contains(Match(id: 'g11')), true);
    });

    test('returns false for match not in queue', () {
      final queue = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [Match(id: 'g12')],
      );

      expect(queue.contains(Match(id: 'g13')), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // isEmpty
  // ═══════════════════════════════════════════════════════════════

  group('isEmpty', () {
    test('returns true for completely empty queue', () {
      final queue = MatchQueue(
        queue: [],
        playing: [],
      );

      expect(queue.isEmpty(), true);
    });

    test('returns false when queue has entries', () {
      final queue = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [],
      );

      expect(queue.isEmpty(), false);
    });

    test('returns false when playing has matches', () {
      final queue = MatchQueue(
        queue: [],
        playing: [Match(id: 'g11')],
      );

      expect(queue.isEmpty(), false);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // updateKnockQueue
  // ═══════════════════════════════════════════════════════════════

  group('updateKnockQueue', () {
    test('adds ready matches to queue', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Set up first match
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final queue = MatchQueue();
      queue.updateKnockQueue(knockouts);

      // Should have added the ready match
      expect(queue.contains(knockouts.champions.rounds[0][0]), true);
    });

    test('does not add unready matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Don't set teams – match not ready
      final queue = MatchQueue();
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

      final queue = MatchQueue();
      queue.updateKnockQueue(knockouts);

      expect(queue.isEmpty(), true);
    });

    test('does not add duplicate matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final queue = MatchQueue();

      queue.updateKnockQueue(knockouts);
      final countAfterFirst = queue.queue.length;

      queue.updateKnockQueue(knockouts);
      final countAfterSecond = queue.queue.length;

      expect(countAfterFirst, countAfterSecond);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // create (from Gruppenphase)
  // ═══════════════════════════════════════════════════════════════

  group('create', () {
    test('creates queue from Gruppenphase', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      expect(queue.queue.isNotEmpty, true);
      expect(queue.playing, isEmpty);
    });

    test('includes all matches from Gruppenphase', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      expect(queue.queue.length, 6); // 6 matches per group (4 choose 2)
    });

    test('interleaves matches across groups (groupRank ordering)', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      // First entries should have groupRank 0
      expect(queue.queue[0].groupRank, 0);
      expect(queue.queue[1].groupRank, 0);
      // Later entries should have higher groupRank
      final lastRank = queue.queue.last.groupRank;
      expect(lastRank, greaterThan(0));
    });

    test('queue is sorted by groupRank then tableOrder', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
        ['t9', 't10', 't11', 't12'],
      ]);
      final gruppenphase = Gruppenphase.create(groups);
      final queue = MatchQueue.create(gruppenphase);

      // Verify sorted order
      for (int i = 1; i < queue.queue.length; i++) {
        final prev = queue.queue[i - 1];
        final curr = queue.queue[i];
        final rankOk = prev.groupRank <= curr.groupRank;
        final orderOk = prev.groupRank < curr.groupRank ||
            prev.tableOrder <= curr.tableOrder;
        expect(rankOk && orderOk, true,
            reason: 'Entry $i should be >= entry ${i - 1} in sort order');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // fromMatches
  // ═══════════════════════════════════════════════════════════════

  group('fromMatches', () {
    test('creates queue from flat match list', () {
      final matches = [
        Match(id: 'm1', tableNumber: 1),
        Match(id: 'm2', tableNumber: 2),
        Match(id: 'm3', tableNumber: 1),
      ];
      final queue = MatchQueue.fromMatches(matches);

      expect(queue.queue.length, 3);
      expect(queue.playing, isEmpty);
    });

    test('assigns sequential groupRank', () {
      final matches = [
        Match(id: 'm1', tableNumber: 1),
        Match(id: 'm2', tableNumber: 2),
        Match(id: 'm3', tableNumber: 1),
      ];
      final queue = MatchQueue.fromMatches(matches);

      // groupRank is sequential index
      expect(queue.queue[0].groupRank, 0);
      expect(queue.queue[1].groupRank, 1);
      expect(queue.queue[2].groupRank, 2);
    });

    test('assigns correct tableOrder', () {
      final matches = [
        Match(id: 'm1', tableNumber: 1),
        Match(id: 'm2', tableNumber: 1),
        Match(id: 'm3', tableNumber: 2),
      ];
      final queue = MatchQueue.fromMatches(matches);

      // m1 is 1st on table 1 → tableOrder 0
      // m2 is 2nd on table 1 → tableOrder 1
      // m3 is 1st on table 2 → tableOrder 0
      final m1Entry = queue.queue.firstWhere((e) => e.matchId == 'm1');
      final m2Entry = queue.queue.firstWhere((e) => e.matchId == 'm2');
      final m3Entry = queue.queue.firstWhere((e) => e.matchId == 'm3');
      expect(m1Entry.tableOrder, 0);
      expect(m2Entry.tableOrder, 1);
      expect(m3Entry.tableOrder, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // JSON serialization
  // ═══════════════════════════════════════════════════════════════

  group('JSON serialization', () {
    test('round trip preserves data', () {
      final original = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', teamId1: 't1', teamId2: 't2')),
          _entry(Match(id: 'g12', teamId1: 't3', teamId2: 't4'), groupRank: 1),
        ],
        playing: [Match(id: 'g13', teamId1: 't5', teamId2: 't6')],
      );

      final json = original.toJson();
      final restored = MatchQueue.fromJson(json);

      expect(restored.queue.length, 2);
      expect(restored.queue[0].matchId, 'g11');
      expect(restored.queue[0].groupRank, 0);
      expect(restored.queue[1].matchId, 'g12');
      expect(restored.queue[1].groupRank, 1);
      expect(restored.playing.length, 1);
      expect(restored.playing[0].id, 'g13');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // clone
  // ═══════════════════════════════════════════════════════════════

  group('clone', () {
    test('creates deep copy', () {
      final original = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [Match(id: 'g12')],
      );

      final cloned = original.clone();

      // Same values
      expect(cloned.queue[0].matchId, 'g11');
      expect(cloned.playing[0].id, 'g12');

      // But different objects
      cloned.playing[0].score1 = 10;
      expect(original.playing[0].score1, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // clearQueue
  // ═══════════════════════════════════════════════════════════════

  group('clearQueue', () {
    test('removes all queue and playing matches', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11')),
          _entry(Match(id: 'g12')),
          _entry(Match(id: 'g21')),
        ],
        playing: [Match(id: 'p1')],
      );

      queue.clearQueue();

      expect(queue.isEmpty(), true);
      expect(queue.queue, isEmpty);
      expect(queue.playing, isEmpty);
    });

    test('clearQueue on already-empty queue is a no-op', () {
      final queue = MatchQueue();

      queue.clearQueue();

      expect(queue.isEmpty(), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // switchPlaying – multi-source
  // ═══════════════════════════════════════════════════════════════

  group('switchPlaying – multi-source', () {
    test('finds and moves match from anywhere in the queue', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g31', tableNumber: 3)),
        ],
        playing: [],
      );

      final result = queue.switchPlaying('g31');

      expect(result, true);
      expect(queue.playing.length, 1);
      expect(queue.playing[0].id, 'g31');
      expect(queue.queue.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // nextMatches – table contention
  // ═══════════════════════════════════════════════════════════════

  group('nextMatches – table contention', () {
    test('returns only one match when all on same table', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 1)),
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 1);
    });

    test('returns match per free table', () {
      final queue = MatchQueue(
        queue: [
          _entry(Match(id: 'g11', tableNumber: 1)),
          _entry(Match(id: 'g21', tableNumber: 2)),
          _entry(Match(id: 'g31', tableNumber: 3)),
        ],
        playing: [],
      );

      final next = queue.nextMatches();

      expect(next.length, 3);
      final tables = next.map((m) => m.tableNumber).toSet();
      expect(tables, {1, 2, 3});
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // updateKnockQueue – edge cases
  // ═══════════════════════════════════════════════════════════════

  group('updateKnockQueue – bounds safety', () {
    test('does not crash when match has tableNumber 0 (unmapped)', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      // Do NOT call mapTables → tableNumber defaults to 0

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final queue = MatchQueue();

      // Should skip matches with invalid tableNumber
      queue.updateKnockQueue(knockouts);

      expect(queue.isEmpty(), true);
    });

    test('enqueues all KO matches regardless of initial queue size', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      for (int i = 0; i < knockouts.champions.rounds[0].length; i++) {
        knockouts.champions.rounds[0][i].teamId1 = 'a${i + 1}';
        knockouts.champions.rounds[0][i].teamId2 = 'b${i + 1}';
      }

      final queue = MatchQueue();
      queue.updateKnockQueue(knockouts);

      // ALL ready matches should be in the queue
      int readyCount = 0;
      for (final m in knockouts.champions.rounds[0]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          readyCount++;
          expect(queue.contains(m), true,
              reason:
                  'Match ${m.id} on table ${m.tableNumber} should be in queue');
        }
      }
      expect(readyCount, greaterThan(0));
    });

    test('next-round matches are queued after completing round 1', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Fill all round 1 champions matches and finish them
      for (final m in knockouts.champions.rounds[0]) {
        m.teamId1 = 'w${m.id}';
        m.teamId2 = 'l${m.id}';
        m.score1 = 10;
        m.score2 = 3;
        m.done = true;
      }
      knockouts.update();

      final queue = MatchQueue();
      queue.updateKnockQueue(knockouts);

      // Round 2 matches should be in the queue
      int r2Ready = 0;
      for (final m in knockouts.champions.rounds[1]) {
        if (m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done) {
          r2Ready++;
          expect(queue.contains(m), true,
              reason:
                  'R2 match ${m.id} on table ${m.tableNumber} should be in queue');
        }
      }
      expect(r2Ready, greaterThan(0),
          reason: 'Should have ready R2 matches after finishing R1');
    });

    test('updateKnockQueue returns early when champions is empty', () {
      final queue = MatchQueue();
      final knockouts = Knockouts(); // empty brackets
      queue.updateKnockQueue(knockouts);
      expect(queue.queue, isEmpty);
      expect(queue.playing, isEmpty);
    });

    test('updateKnockQueue returns early when first match has no teams', () {
      final queue = MatchQueue();
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);
      // All teamIds are empty → guard should trigger
      queue.updateKnockQueue(knockouts);
      expect(queue.queue, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Equality
  // ═══════════════════════════════════════════════════════════════

  group('equality', () {
    test('identical queues are equal', () {
      final a = MatchQueue(
        queue: [_entry(Match(id: 'g11', tableNumber: 1))],
        playing: [Match(id: 'g12')],
      );
      final b = MatchQueue(
        queue: [_entry(Match(id: 'g11', tableNumber: 1))],
        playing: [Match(id: 'g12')],
      );
      expect(a, equals(b));
    });

    test('different queues are not equal', () {
      final a = MatchQueue(
        queue: [_entry(Match(id: 'g11'))],
        playing: [],
      );
      final b = MatchQueue(
        queue: [_entry(Match(id: 'g12'))],
        playing: [],
      );
      expect(a, isNot(equals(b)));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Schedule Stability Invariant
  //
  // Core property: if match X is the nextNextMatch for table T, then
  // after the current nextMatch for T goes through the full lifecycle
  // (switchPlaying → removeFromPlaying), X becomes the nextMatch for T.
  //
  // Additionally, operations on OTHER tables (starting/finishing matches)
  // must not alter the nextNextMatch for table T.
  //
  // Mathematical argument:
  //   The queue is a stable sorted list. nextMatches picks the 1st entry
  //   per free table. nextNextMatches picks the 2nd entry per table (first
  //   non-nextMatch). Removing an entry from the queue (via switchPlaying)
  //   or from playing (via removeFromPlaying) never reorders the remaining
  //   entries. Therefore the 2nd-in-line for a table always becomes
  //   1st-in-line once the 1st is removed. Cross-table independence holds
  //   because entries for different tables don't interact in the per-table
  //   selection logic.
  // ═══════════════════════════════════════════════════════════════

  group('schedule stability invariant', () {
    /// Helper: find the nextMatch for a specific table, or null.
    Match? nextForTable(MatchQueue mq, int table) {
      final nexts = mq.nextMatches();
      for (final m in nexts) {
        if (m.tableNumber == table) return m;
      }
      return null;
    }

    /// Helper: find the nextNextMatch for a specific table, or null.
    Match? nextNextForTable(MatchQueue mq, int table) {
      final nexts = mq.nextNextMatches();
      for (final m in nexts) {
        if (m.tableNumber == table) return m;
      }
      return null;
    }

    test('single table: nextNextMatch becomes nextMatch after finish', () {
      // 3 matches on table 1, sequential ordering
      final m1 = Match(id: 'a', tableNumber: 1);
      final m2 = Match(id: 'b', tableNumber: 1);
      final m3 = Match(id: 'c', tableNumber: 1);
      final mq = MatchQueue(queue: [
        _entry(m1),
        _entry(m2, groupRank: 1, tableOrder: 1),
        _entry(m3, groupRank: 2, tableOrder: 2),
      ]);

      // Initially: next=a, nextNext=b
      expect(nextForTable(mq, 1)!.id, 'a');
      expect(nextNextForTable(mq, 1)!.id, 'b');

      // Start match a → table occupied
      mq.switchPlaying('a');
      expect(nextForTable(mq, 1), isNull); // table busy
      expect(nextNextForTable(mq, 1)!.id, 'b'); // still b

      // Finish match a → table free again
      mq.removeFromPlaying('a');
      expect(nextForTable(mq, 1)!.id, 'b'); // b promoted!
      expect(nextNextForTable(mq, 1)!.id, 'c');

      // Repeat: start b, finish b → c promoted
      mq.switchPlaying('b');
      mq.removeFromPlaying('b');
      expect(nextForTable(mq, 1)!.id, 'c');
      expect(nextNextForTable(mq, 1), isNull); // no more
    });

    test('two tables: finishing on table A does not affect table B', () {
      final a1 = Match(id: 'a1', tableNumber: 1);
      final a2 = Match(id: 'a2', tableNumber: 1);
      final b1 = Match(id: 'b1', tableNumber: 2);
      final b2 = Match(id: 'b2', tableNumber: 2);
      final mq = MatchQueue(queue: [
        _entry(a1),
        _entry(b1),
        _entry(a2, groupRank: 1, tableOrder: 1),
        _entry(b2, groupRank: 1, tableOrder: 1),
      ]);

      // Record nextNext for table 2
      final nnB = nextNextForTable(mq, 2);
      expect(nnB!.id, 'b2');

      // Process entire lifecycle of match on table 1
      mq.switchPlaying('a1');
      expect(nextNextForTable(mq, 2)!.id, 'b2'); // unchanged
      mq.removeFromPlaying('a1');
      expect(nextNextForTable(mq, 2)!.id, 'b2'); // still unchanged
    });

    test('starting match on table A does not change nextNextMatch on table B',
        () {
      final a1 = Match(id: 'a1', tableNumber: 1);
      final a2 = Match(id: 'a2', tableNumber: 1);
      final b1 = Match(id: 'b1', tableNumber: 2);
      final b2 = Match(id: 'b2', tableNumber: 2);
      final b3 = Match(id: 'b3', tableNumber: 2);
      final mq = MatchQueue(queue: [
        _entry(a1),
        _entry(b1),
        _entry(a2, groupRank: 1, tableOrder: 1),
        _entry(b2, groupRank: 1, tableOrder: 1),
        _entry(b3, groupRank: 2, tableOrder: 2),
      ]);

      final nnB = nextNextForTable(mq, 2)!.id;
      expect(nnB, 'b2');

      // Start match on table 1 — should not affect table 2
      mq.switchPlaying('a1');
      expect(nextNextForTable(mq, 2)!.id, nnB);

      // Also start match on table 2 — nextNext should advance
      mq.switchPlaying('b1');
      expect(nextNextForTable(mq, 2)!.id, 'b2');
    });

    test('three tables: full drain verifies invariant at every step', () {
      // 3 tables, 3 matches each = 9 matches
      final matches = <Match>[];
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 3; t++) {
        for (int i = 0; i < 3; i++) {
          final m = Match(id: 't${t}m$i', tableNumber: t);
          matches.add(m);
          entries.add(_entry(m, groupRank: i, tableOrder: i));
        }
      }
      final mq = MatchQueue(queue: entries);

      // Process all matches, verifying invariant at each step
      while (mq.nextMatches().isNotEmpty) {
        // Snapshot nextNext for each table before starting
        final nextNextBefore = <int, String?>{};
        for (int t = 1; t <= 3; t++) {
          nextNextBefore[t] = nextNextForTable(mq, t)?.id;
        }

        // Pick one table to process (the first available)
        final nextMatch = mq.nextMatches().first;
        final table = nextMatch.tableNumber;
        final expectedNext = nextNextBefore[table];

        // Start the match
        mq.switchPlaying(nextMatch.id);

        // Verify nextNext for OTHER tables is unchanged
        for (int t = 1; t <= 3; t++) {
          if (t == table) continue;
          expect(nextNextForTable(mq, t)?.id, nextNextBefore[t],
              reason:
                  'nextNext for table $t should not change when starting on table $table');
        }

        // Finish the match
        mq.removeFromPlaying(nextMatch.id);

        // The old nextNext for this table should now be nextMatch
        if (expectedNext != null) {
          expect(nextForTable(mq, table)?.id, expectedNext,
              reason:
                  'nextNextMatch "$expectedNext" for table $table should be promoted to nextMatch');
        }
      }

      // Everything should be processed
      expect(mq.queue, isEmpty);
      expect(mq.playing, isEmpty);
    });

    test('mixed groupRanks: promotion still holds', () {
      // Simulate interleaved group matches on one table:
      // Match from group A round 0, group B round 0, group A round 1
      final m0 = Match(id: 'gA-0', tableNumber: 1);
      final m1 = Match(id: 'gB-0', tableNumber: 1);
      final m2 = Match(id: 'gA-1', tableNumber: 1);
      final mq = MatchQueue(queue: [
        _entry(m0),
        _entry(m1, tableOrder: 1),
        _entry(m2, groupRank: 1, tableOrder: 2),
      ]);

      expect(nextForTable(mq, 1)!.id, 'gA-0');
      expect(nextNextForTable(mq, 1)!.id, 'gB-0');

      mq.switchPlaying('gA-0');
      mq.removeFromPlaying('gA-0');

      expect(nextForTable(mq, 1)!.id, 'gB-0'); // promoted
      expect(nextNextForTable(mq, 1)!.id, 'gA-1');

      mq.switchPlaying('gB-0');
      mq.removeFromPlaying('gB-0');

      expect(nextForTable(mq, 1)!.id, 'gA-1'); // promoted
      expect(nextNextForTable(mq, 1), isNull);
    });

    test('concurrent playing on multiple tables preserves invariant', () {
      // 2 tables, 3 matches each. Start matches on BOTH tables, then
      // finish them in different order.
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 2; t++) {
        for (int i = 0; i < 3; i++) {
          entries.add(_entry(
            Match(id: 't${t}m$i', tableNumber: t),
            groupRank: i,
            tableOrder: i,
          ));
        }
      }
      final mq = MatchQueue(queue: entries);

      // next: t1m0, t2m0 | nextNext: t1m1, t2m1
      expect(nextForTable(mq, 1)!.id, 't1m0');
      expect(nextNextForTable(mq, 1)!.id, 't1m1');
      expect(nextForTable(mq, 2)!.id, 't2m0');
      expect(nextNextForTable(mq, 2)!.id, 't2m1');

      // Start both tables
      mq.switchPlaying('t1m0');
      mq.switchPlaying('t2m0');

      // nextNext should still be the same (both tables occupied)
      expect(nextNextForTable(mq, 1)!.id, 't1m1');
      expect(nextNextForTable(mq, 2)!.id, 't2m1');

      // Finish table 2 first — table 1's nextNext unchanged
      mq.removeFromPlaying('t2m0');
      expect(nextNextForTable(mq, 1)!.id, 't1m1'); // unchanged
      expect(nextForTable(mq, 2)!.id, 't2m1'); // promoted
      expect(nextNextForTable(mq, 2)!.id, 't2m2');

      // Now finish table 1
      mq.removeFromPlaying('t1m0');
      expect(nextForTable(mq, 1)!.id, 't1m1'); // promoted
      expect(nextNextForTable(mq, 1)!.id, 't1m2');
    });

    test('finishing matches in reverse table order preserves invariant', () {
      // 4 tables, 2 matches each. Start all, then finish in reverse order.
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 4; t++) {
        for (int i = 0; i < 2; i++) {
          entries.add(_entry(
            Match(id: 't${t}m$i', tableNumber: t),
            groupRank: i,
            tableOrder: i,
          ));
        }
      }
      final mq = MatchQueue(queue: entries);

      // Record nextNext for all tables
      final expectedPromotion = <int, String>{};
      for (int t = 1; t <= 4; t++) {
        expectedPromotion[t] = nextNextForTable(mq, t)!.id;
      }

      // Start all 4 tables
      for (int t = 1; t <= 4; t++) {
        mq.switchPlaying('t${t}m0');
      }

      // Finish in reverse order: table 4, 3, 2, 1
      for (int t = 4; t >= 1; t--) {
        mq.removeFromPlaying('t${t}m0');
        expect(nextForTable(mq, t)!.id, expectedPromotion[t],
            reason: 'Table $t: nextNextMatch should be promoted to nextMatch');

        // Other still-playing tables' nextNext should be unchanged
        for (int s = t - 1; s >= 1; s--) {
          expect(nextNextForTable(mq, s)!.id, expectedPromotion[s],
              reason:
                  'Table $s nextNext should be unchanged after finishing table $t');
        }
      }
    });

    test('large scenario: 6 tables, 5 matches each, full drain', () {
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 6; t++) {
        for (int i = 0; i < 5; i++) {
          entries.add(_entry(
            Match(id: 't${t}m$i', tableNumber: t),
            groupRank: i,
            tableOrder: i,
          ));
        }
      }
      final mq = MatchQueue(queue: entries);

      int processed = 0;
      while (mq.nextMatches().isNotEmpty) {
        // Snapshot nextNext for all tables
        final nextNextSnap = <int, String?>{};
        for (int t = 1; t <= 6; t++) {
          nextNextSnap[t] = nextNextForTable(mq, t)?.id;
        }

        // Start matches on all free tables
        final toStart = List<Match>.from(mq.nextMatches());
        for (final m in toStart) {
          mq.switchPlaying(m.id);
        }

        // Verify nextNext for all tables unchanged
        for (int t = 1; t <= 6; t++) {
          expect(nextNextForTable(mq, t)?.id, nextNextSnap[t],
              reason:
                  'Table $t nextNext should not change when starting matches');
        }

        // Finish all playing matches and verify promotion
        final toFinish = List<Match>.from(mq.playing);
        for (final m in toFinish) {
          final table = m.tableNumber;
          final expectedPromoted = nextNextSnap[table];

          mq.removeFromPlaying(m.id);

          if (expectedPromoted != null) {
            expect(nextForTable(mq, table)?.id, expectedPromoted,
                reason:
                    'Table $table: "$expectedPromoted" should be promoted after finishing "${m.id}"');
          }
          processed++;
        }
      }

      expect(processed, 30); // 6 tables × 5 matches
      expect(mq.queue, isEmpty);
      expect(mq.playing, isEmpty);
    });

    test('interleaved start/finish across tables preserves invariant', () {
      // 3 tables, 4 matches each. Simulate realistic tournament play:
      // start table 1, start table 2, finish table 1, start table 3,
      // finish table 2, etc.
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 3; t++) {
        for (int i = 0; i < 4; i++) {
          entries.add(_entry(
            Match(id: 't${t}m$i', tableNumber: t),
            groupRank: i,
            tableOrder: i,
          ));
        }
      }
      final mq = MatchQueue(queue: entries);

      /// Verify the invariant: for each table, nextNextMatch should
      /// eventually become nextMatch after the current nextMatch finishes.
      void verifyInvariantHolds() {
        for (int t = 1; t <= 3; t++) {
          final nn = nextNextForTable(mq, t);
          if (nn == null) continue;

          // Clone state, process current match on this table, check promotion
          final clone = mq.clone();
          final next = nextForTable(clone, t);
          if (next != null) {
            clone.switchPlaying(next.id);
            clone.removeFromPlaying(next.id);
            expect(nextForTable(clone, t)?.id, nn.id,
                reason:
                    'Table $t: nextNext "${nn.id}" should become nextMatch after "${next.id}" finishes');
          }
        }
      }

      verifyInvariantHolds();

      // Start table 1
      mq.switchPlaying('t1m0');
      verifyInvariantHolds();

      // Start table 2
      mq.switchPlaying('t2m0');
      verifyInvariantHolds();

      // Finish table 1
      mq.removeFromPlaying('t1m0');
      verifyInvariantHolds();

      // Start table 3
      mq.switchPlaying('t3m0');
      verifyInvariantHolds();

      // Start table 1 again
      mq.switchPlaying('t1m1');
      verifyInvariantHolds();

      // Finish table 2
      mq.removeFromPlaying('t2m0');
      verifyInvariantHolds();

      // Finish table 3
      mq.removeFromPlaying('t3m0');
      verifyInvariantHolds();

      // Finish table 1
      mq.removeFromPlaying('t1m1');
      verifyInvariantHolds();
    });

    test('KO phase: invariant holds with round-based groupRanks', () {
      // Simulate KO bracket: R1 has 4 matches across 2 tables,
      // R2 has 2 matches on same 2 tables
      final r1t1 = Match(id: 'r1-t1a', tableNumber: 1);
      final r1t1b = Match(id: 'r1-t1b', tableNumber: 1);
      final r1t2 = Match(id: 'r1-t2a', tableNumber: 2);
      final r1t2b = Match(id: 'r1-t2b', tableNumber: 2);
      final r2t1 = Match(id: 'r2-t1', tableNumber: 1);
      final r2t2 = Match(id: 'r2-t2', tableNumber: 2);

      final mq = MatchQueue(queue: [
        // Round 1 (groupRank 0)
        _entry(r1t1),
        _entry(r1t2),
        _entry(r1t1b, tableOrder: 1),
        _entry(r1t2b, tableOrder: 1),
        // Round 2 (groupRank 1) — already known, added later in practice
        _entry(r2t1, groupRank: 1, tableOrder: 2),
        _entry(r2t2, groupRank: 1, tableOrder: 2),
      ]);

      // next: r1-t1a, r1-t2a | nextNext: r1-t1b, r1-t2b
      expect(nextForTable(mq, 1)!.id, 'r1-t1a');
      expect(nextNextForTable(mq, 1)!.id, 'r1-t1b');

      // Play R1 match on table 1
      mq.switchPlaying('r1-t1a');
      mq.removeFromPlaying('r1-t1a');
      expect(nextForTable(mq, 1)!.id, 'r1-t1b'); // promoted
      expect(nextNextForTable(mq, 1)!.id, 'r2-t1'); // R2 is next-next

      // Play remaining R1 match on table 1
      mq.switchPlaying('r1-t1b');
      mq.removeFromPlaying('r1-t1b');
      expect(nextForTable(mq, 1)!.id, 'r2-t1'); // R2 promoted
      expect(nextNextForTable(mq, 1), isNull); // no more for table 1

      // Table 2 should be independently correct
      expect(nextForTable(mq, 2)!.id, 'r1-t2a');
      expect(nextNextForTable(mq, 2)!.id, 'r1-t2b');
    });

    test('KO phase: adding later-round matches preserves table ordering', () {
      // Start with only R1 matches, then simulate updateKnockQueue
      // adding R2 matches after R1 finishes
      final r1t1 = Match(id: 'r1-t1', tableNumber: 1);
      final r1t2 = Match(id: 'r1-t2', tableNumber: 2);
      final mq = MatchQueue(queue: [
        _entry(r1t1),
        _entry(r1t2),
      ]);

      // Play R1 on table 1
      mq.switchPlaying('r1-t1');
      mq.removeFromPlaying('r1-t1');

      // Simulate updateKnockQueue adding R2 matches (groupRank=1)
      final r2t1 = Match(id: 'r2-t1', tableNumber: 1);
      final r2t2 = Match(id: 'r2-t2', tableNumber: 2);
      mq.queue.addAll([
        _entry(r2t1, groupRank: 1, tableOrder: 1),
        _entry(r2t2, groupRank: 1, tableOrder: 1),
      ]);
      // Sort as updateKnockQueue does
      mq.queue.sort((a, b) {
        final cmp = a.groupRank.compareTo(b.groupRank);
        if (cmp != 0) return cmp;
        return a.tableOrder.compareTo(b.tableOrder);
      });

      // Table 1: next should be r2-t1 (nothing else), nextNext null
      expect(nextForTable(mq, 1)!.id, 'r2-t1');

      // Table 2: next should still be r1-t2, nextNext should be r2-t2
      expect(nextForTable(mq, 2)!.id, 'r1-t2');
      expect(nextNextForTable(mq, 2)!.id, 'r2-t2');

      // Invariant: finish r1-t2, r2-t2 promoted
      mq.switchPlaying('r1-t2');
      mq.removeFromPlaying('r1-t2');
      expect(nextForTable(mq, 2)!.id, 'r2-t2');
    });

    test('invariant holds with MatchQueue.create() group phase', () {
      // Build a Gruppenphase with 2 groups, 3 matches each
      final gp = Gruppenphase(groups: [
        [
          Match(id: 'g1-1', teamId1: 'A1', teamId2: 'A2', tableNumber: 1),
          Match(id: 'g1-2', teamId1: 'A1', teamId2: 'A3', tableNumber: 1),
          Match(id: 'g1-3', teamId1: 'A2', teamId2: 'A3', tableNumber: 1),
        ],
        [
          Match(id: 'g2-1', teamId1: 'B1', teamId2: 'B2', tableNumber: 2),
          Match(id: 'g2-2', teamId1: 'B1', teamId2: 'B3', tableNumber: 2),
          Match(id: 'g2-3', teamId1: 'B2', teamId2: 'B3', tableNumber: 2),
        ],
      ]);

      final mq = MatchQueue.create(gp);
      final tables = {1, 2};

      // Drain the entire queue, verifying invariant at every transition
      while (mq.nextMatches().isNotEmpty) {
        for (final t in tables) {
          final nn = nextNextForTable(mq, t);
          if (nn == null) continue;

          // Prove promotion on a clone
          final clone = mq.clone();
          final next = nextForTable(clone, t);
          if (next != null) {
            clone.switchPlaying(next.id);
            clone.removeFromPlaying(next.id);
            expect(nextForTable(clone, t)?.id, nn.id,
                reason:
                    'Table $t: "${nn.id}" should be promoted (via MatchQueue.create)');
          }
        }

        // Progress: start all, then finish all
        final nexts = List<Match>.from(mq.nextMatches());
        for (final m in nexts) {
          mq.switchPlaying(m.id);
        }
        final toFinish = List<Match>.from(mq.playing);
        for (final m in toFinish) {
          mq.removeFromPlaying(m.id);
        }
      }
    });

    test('cross-table independence: exhaustive pairwise check', () {
      // 4 tables, 3 matches each. For every pair (T_active, T_observer),
      // verify that finishing on T_active doesn't change nextNext on T_observer.
      final entries = <MatchQueueEntry>[];
      for (int t = 1; t <= 4; t++) {
        for (int i = 0; i < 3; i++) {
          entries.add(_entry(
            Match(id: 't${t}m$i', tableNumber: t),
            groupRank: i,
            tableOrder: i,
          ));
        }
      }

      for (int active = 1; active <= 4; active++) {
        for (int observer = 1; observer <= 4; observer++) {
          if (active == observer) continue;

          // Fresh queue for each pair
          final mq = MatchQueue(
            queue: entries
                .map((e) => MatchQueueEntry(
                      match: Match(
                        id: e.matchId,
                        tableNumber: e.tableNumber,
                      ),
                      groupRank: e.groupRank,
                      tableOrder: e.tableOrder,
                    ))
                .toList(),
          );

          final nnBefore = nextNextForTable(mq, observer)?.id;

          // Start + finish on active table
          mq.switchPlaying(nextForTable(mq, active)!.id);
          expect(nextNextForTable(mq, observer)?.id, nnBefore,
              reason:
                  'Starting on table $active should not affect table $observer nextNext');

          mq.removeFromPlaying(mq.playing.first.id);
          expect(nextNextForTable(mq, observer)?.id, nnBefore,
              reason:
                  'Finishing on table $active should not affect table $observer nextNext');
        }
      }
    });
  });
}
