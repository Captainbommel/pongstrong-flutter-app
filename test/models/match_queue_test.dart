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

      expect(queue.waiting.length, 6);
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
}
