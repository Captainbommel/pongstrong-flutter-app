import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/import_service.dart';

void main() {
  // ==========================================================================
  // HELPER BUILDERS
  // ==========================================================================

  /// Creates a list of teams with IDs 't0' .. 't{count-1}'.
  List<Team> makeTeams(int count) => List.generate(
        count,
        (i) => Team(id: 't$i', name: 'Team $i', member1: 'M1', member2: 'M2'),
      );

  /// A valid Knockouts object with standard structure.
  Knockouts validKnockouts() {
    final k = Knockouts();
    k.instantiate();
    return k;
  }

  /// Minimal valid snapshot components.
  ({
    List<Team> teams,
    MatchQueue matchQueue,
    Gruppenphase gruppenphase,
    Tabellen tabellen,
    Knockouts knockouts,
  }) validSnapshot() {
    final teams = makeTeams(4);
    final gruppenphase = Gruppenphase(groups: [
      [
        Match(
            id: 'g1-1',
            teamId1: 't0',
            teamId2: 't1',
            tableNumber: 1,
            score1: 10,
            score2: 5,
            done: true),
      ],
      [
        Match(
            id: 'g2-1',
            teamId1: 't2',
            teamId2: 't3',
            tableNumber: 2,
            score1: 10,
            score2: 3,
            done: true),
      ],
    ]);
    final tabellen = Tabellen(tables: [
      [
        TableRow(teamId: 't0', points: 3),
        TableRow(teamId: 't1'),
      ],
      [
        TableRow(teamId: 't2', points: 3),
        TableRow(teamId: 't3'),
      ],
    ]);
    final matchQueue = MatchQueue(queue: [], playing: []);
    final knockouts = validKnockouts();

    return (
      teams: teams,
      matchQueue: matchQueue,
      gruppenphase: gruppenphase,
      tabellen: tabellen,
      knockouts: knockouts,
    );
  }

  // ==========================================================================
  // 1. VALID SNAPSHOTS PASS
  // ==========================================================================

  group('validateSnapshot – valid data', () {
    test('returns empty list for valid snapshot', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
      );
      expect(errors, isEmpty);
    });

    test('returns empty list for completely empty snapshot', () {
      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );
      expect(errors, isEmpty);
    });

    test('returns empty list for snapshot with unplayed matches', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1', tableNumber: 1),
        ],
      ]);
      final tabellen = Tabellen(tables: [
        [
          TableRow(teamId: 't0'),
          TableRow(teamId: 't1'),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(
          queue: [
            MatchQueueEntry(
              match: Match(
                  id: 'g1-1', teamId1: 't0', teamId2: 't1', tableNumber: 1),
            ),
          ],
          playing: [],
        ),
        gruppenphase: gruppenphase,
        tabellen: tabellen,
        knockouts: Knockouts(),
      );
      expect(errors, isEmpty);
    });
  });

  // ==========================================================================
  // 2. KNOCKOUT BRACKET TREE STRUCTURE
  // ==========================================================================

  group('validateSnapshot – bracket tree structure', () {
    test('detects champions bracket that does not halve', () {
      final teams = makeTeams(2);
      // Manually build a broken bracket: 8 matches → 3 matches (should be 4)
      final brokenChampions = KnockoutBracket(rounds: [
        List.generate(8, (i) => Match(id: 'c1-${i + 1}')),
        List.generate(3, (i) => Match(id: 'c2-${i + 1}')), // wrong!
        [Match(id: 'c3-1')],
      ]);

      final knockouts = Knockouts(
        champions: brokenChampions,
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.length, greaterThanOrEqualTo(1));
      expect(errors.any((e) => e.contains('Champions')), isTrue);
      expect(errors.any((e) => e.contains('round 2')), isTrue);
    });

    test('detects europa bracket that does not halve', () {
      final brokenEuropa = KnockoutBracket(rounds: [
        List.generate(4, (i) => Match(id: 'e1-${i + 1}')),
        List.generate(3, (i) => Match(id: 'e2-${i + 1}')), // wrong!
      ]);

      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: brokenEuropa,
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('Europa')), isTrue);
    });

    test('detects conference bracket that does not halve', () {
      final brokenConference = KnockoutBracket(rounds: [
        List.generate(4, (i) => Match(id: 'f1-${i + 1}')),
        [Match(id: 'f2-1')],
        [Match(id: 'f3-1')], // wrong – should not exist after 1 match
      ]);

      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: brokenConference,
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('Conference')), isTrue);
    });

    test('valid bracket structure passes', () {
      final knockouts = validKnockouts();
      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      // No bracket structure errors
      expect(
        errors.where((e) =>
            e.contains('Champions') ||
            e.contains('Europa') ||
            e.contains('Conference')),
        isEmpty,
      );
    });

    test('single-round bracket is valid', () {
      final singleRound = KnockoutBracket(rounds: [
        [Match(id: 'x11')],
      ]);
      final knockouts = Knockouts(
        champions: singleRound,
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );
      expect(errors.where((e) => e.contains('Champions')), isEmpty);
    });
  });

  // ==========================================================================
  // 3. SUPER CUP SIZE
  // ==========================================================================

  group('validateSnapshot – super cup size', () {
    test('detects super cup with wrong number of matches', () {
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: [Match(id: 's-1')]), // only 1!
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );
      expect(errors.any((e) => e.contains('Super Cup')), isTrue);
      expect(errors.any((e) => e.contains('2 matches')), isTrue);
    });

    test('super cup with 3 matches is invalid', () {
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: [
          Match(id: 's-1'),
          Match(id: 's-2'),
          Match(id: 's-3'),
        ]),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );
      expect(errors.any((e) => e.contains('Super Cup')), isTrue);
    });

    test('empty super cup is valid', () {
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: []),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );
      expect(errors.where((e) => e.contains('Super Cup')), isEmpty);
    });

    test('super cup with exactly 2 matches is valid', () {
      final knockouts = validKnockouts();
      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );
      expect(errors.where((e) => e.contains('Super Cup')), isEmpty);
    });
  });

  // ==========================================================================
  // 4. TEAM ID REFERENTIAL INTEGRITY
  // ==========================================================================

  group('validateSnapshot – team ID referential integrity', () {
    test('detects unknown team ID in gruppenphase', () {
      final teams = makeTeams(2); // t0, t1
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(id: 'g1-1', teamId1: 't0', teamId2: 'ghost_team'),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 'ghost_team')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('ghost_team')), isTrue);
      expect(errors.any((e) => e.contains('gruppenphase')), isTrue);
    });

    test('detects unknown team ID in knockouts', () {
      final teams = makeTeams(2); // t0, t1
      final knockouts = Knockouts(
        champions: KnockoutBracket(rounds: [
          [Match(id: 'c1-1', teamId1: 't0', teamId2: 'nonexistent')],
        ]),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('nonexistent')), isTrue);
      expect(errors.any((e) => e.contains('Champions')), isTrue);
    });

    test('detects unknown team ID in super cup', () {
      final teams = makeTeams(2);
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: [
          Match(id: 's-1', teamId1: 't0', teamId2: 'bad_id'),
          Match(id: 's-2'),
        ]),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('bad_id')), isTrue);
      expect(errors.any((e) => e.contains('Super Cup')), isTrue);
    });

    test('detects unknown team ID in match queue waiting', () {
      final teams = makeTeams(2);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(
          queue: [
            MatchQueueEntry(
              match: Match(id: 'w1', teamId1: 't0', teamId2: 'missing'),
            ),
          ],
          playing: [],
        ),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('missing')), isTrue);
      expect(errors.any((e) => e.contains('matchQueue')), isTrue);
    });

    test('detects unknown team ID in match queue playing', () {
      final teams = makeTeams(2);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(
          queue: [],
          playing: [Match(id: 'p1', teamId1: 'phantom', teamId2: 't1')],
        ),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('phantom')), isTrue);
    });

    test('empty team IDs are allowed (unfilled slots)', () {
      final teams = makeTeams(2);
      final knockouts = Knockouts(
        champions: KnockoutBracket(rounds: [
          [Match(id: 'c1-1', teamId1: 't0')],
        ]),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      // No team ref errors
      expect(errors.where((e) => e.contains('Unknown team')), isEmpty);
    });
  });

  // ==========================================================================
  // 5. MATCH ID UNIQUENESS
  // ==========================================================================

  group('validateSnapshot – match ID uniqueness', () {
    test('detects duplicate match ID within gruppenphase', () {
      final teams = makeTeams(4);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1'),
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1'), // duplicate!
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('Duplicate')), isTrue);
      expect(errors.any((e) => e.contains('g1-1')), isTrue);
    });

    test('detects duplicate match ID across gruppenphase and knockouts', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [Match(id: 'shared_id', teamId1: 't0', teamId2: 't1')],
      ]);
      final knockouts = Knockouts(
        champions: KnockoutBracket(rounds: [
          [Match(id: 'shared_id', teamId1: 't0', teamId2: 't1')], // dup!
        ]),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('Duplicate')), isTrue);
      expect(errors.any((e) => e.contains('shared_id')), isTrue);
    });

    test('no error for unique match IDs', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
      );
      expect(errors.where((e) => e.contains('Duplicate')), isEmpty);
    });

    test('empty match IDs are ignored', () {
      final knockouts = Knockouts(
        champions: KnockoutBracket(rounds: [
          [Match(), Match()],
          [Match(id: 'c2-1')],
        ]),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.where((e) => e.contains('Duplicate')), isEmpty);
    });
  });

  // ==========================================================================
  // 6. GRUPPENPHASE / TABELLEN CONSISTENCY
  // ==========================================================================

  group('validateSnapshot – gruppenphase/tabellen consistency', () {
    test('detects mismatched group counts', () {
      final teams = makeTeams(4);
      final gruppenphase = Gruppenphase(groups: [
        [Match(id: 'g1-1', teamId1: 't0', teamId2: 't1')],
        [Match(id: 'g2-1', teamId1: 't2', teamId2: 't3')],
      ]);
      final tabellen = Tabellen(tables: [
        [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        // Missing second table!
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: tabellen,
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('Gruppenphase')), isTrue);
      expect(errors.any((e) => e.contains('Tabellen')), isTrue);
    });

    test('no error when both are empty', () {
      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );
      expect(
        errors
            .where((e) => e.contains('Gruppenphase') && e.contains('Tabellen')),
        isEmpty,
      );
    });

    test('no error when gruppenphase is empty and tabellen is non-empty', () {
      // E.g., KO-only mode might have empty gruppenphase
      final errors = ImportService.validateSnapshot(
        teams: makeTeams(2),
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0')],
        ]),
        knockouts: Knockouts(),
      );
      expect(
        errors
            .where((e) => e.contains('Gruppenphase') && e.contains('Tabellen')),
        isEmpty,
      );
    });
  });

  // ==========================================================================
  // 7. DONE / SCORE CONSISTENCY
  // ==========================================================================

  group('validateSnapshot – done/score consistency', () {
    test('detects done match with invalid scores in gruppenphase', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: 7,
              score2: 3,
              done: true), // 7:3 is not a valid final score
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('invalid scores')), isTrue);
      expect(errors.any((e) => e.contains('g1-1')), isTrue);
    });

    test('detects done match with invalid scores in knockouts', () {
      final teams = makeTeams(2);
      final knockouts = Knockouts(
        champions: KnockoutBracket(rounds: [
          [
            Match(
                id: 'c1-1',
                teamId1: 't0',
                teamId2: 't1',
                score1: 5,
                score2: 5,
                done: true), // 5:5 tie is invalid
          ],
        ]),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('invalid scores')), isTrue);
      expect(errors.any((e) => e.contains('c1-1')), isTrue);
    });

    test('does not flag unplayed matches with zero scores', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1'),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });

    test('valid done match passes (normal win)', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: 10,
              score2: 7,
              done: true),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });

    test('valid done match passes (overtime)', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: 16,
              score2: 14,
              done: true),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });

    test('valid done match passes (deathcup)', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: -1,
              score2: 4,
              done: true),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });

    test('detects done match with invalid scores in super cup', () {
      final teams = makeTeams(2);
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: [
          Match(
              id: 's-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: 99,
              score2: 99,
              done: true), // invalid
          Match(id: 's-2'),
        ]),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('s-1')), isTrue);
      expect(errors.any((e) => e.contains('invalid scores')), isTrue);
    });
  });

  // ==========================================================================
  // 8. MATCH QUEUE INTEGRITY
  // ==========================================================================

  group('validateSnapshot – match queue integrity', () {
    test('detects match in both queue and playing', () {
      final teams = makeTeams(2);
      final match =
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1', tableNumber: 1);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(
          queue: [
            MatchQueueEntry(match: match),
          ],
          playing: [
            Match(id: 'g1-1', teamId1: 't0', teamId2: 't1', tableNumber: 1)
          ],
        ),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );

      expect(errors.any((e) => e.contains('g1-1')), isTrue);
      expect(errors.any((e) => e.contains('both queue and playing')), isTrue);
    });

    test('no error when queue is clean', () {
      final teams = makeTeams(2);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(
          queue: [
            MatchQueueEntry(
              match: Match(
                  id: 'g1-1', teamId1: 't0', teamId2: 't1', tableNumber: 1),
            ),
          ],
          playing: [
            Match(id: 'g1-2', teamId1: 't0', teamId2: 't1', tableNumber: 2)
          ],
        ),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );

      expect(
          errors.where((e) => e.contains('both waiting and playing')), isEmpty);
    });
  });

  // ==========================================================================
  // 9. MULTIPLE ERRORS AT ONCE
  // ==========================================================================

  group('validateSnapshot – combined errors', () {
    test('reports multiple validation errors simultaneously', () {
      // Broken bracket + unknown team + duplicate ID + bad score
      final teams = makeTeams(2); // t0, t1

      final brokenChampions = KnockoutBracket(rounds: [
        List.generate(4, (i) => Match(id: 'c1-${i + 1}')),
        [Match(id: 'c2-1'), Match(id: 'c2-2'), Match(id: 'c2-3')], // 3 not 2!
      ]);

      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 'zombie',
              score1: 4,
              score2: 4,
              done: true),
          Match(id: 'g1-1', teamId1: 't0', teamId2: 't1'), // duplicate
        ],
      ]);

      final knockouts = Knockouts(
        champions: brokenChampions,
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(matches: [Match(id: 's-1')]), // wrong size
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      // Should detect at least 4 distinct issues
      expect(errors.length, greaterThanOrEqualTo(4));
      // Bracket structure
      expect(errors.any((e) => e.contains('Champions')), isTrue);
      // Unknown team
      expect(errors.any((e) => e.contains('zombie')), isTrue);
      // Duplicate ID
      expect(errors.any((e) => e.contains('Duplicate')), isTrue);
      // Invalid score
      expect(errors.any((e) => e.contains('invalid scores')), isTrue);
      // Super cup size
      expect(errors.any((e) => e.contains('Super Cup')), isTrue);
    });
  });

  // ==========================================================================
  // 10. ROUND-TRIP WITH VALIDATION
  // ==========================================================================

  group('validateSnapshot – round-trip integrity', () {
    test('valid tournament export passes validation', () {
      final teams = [
        Team(id: 't1', name: 'Alpha', member1: 'A1', member2: 'A2'),
        Team(id: 't2', name: 'Beta', member1: 'B1', member2: 'B2'),
        Team(id: 't3', name: 'Gamma', member1: 'G1', member2: 'G2'),
        Team(id: 't4', name: 'Delta', member1: 'D1', member2: 'D2'),
      ];

      final match1 = Match(
          teamId1: 't1',
          teamId2: 't2',
          score1: 10,
          score2: 5,
          tableNumber: 1,
          id: 'g1-1',
          done: true);
      final match2 = Match(
          teamId1: 't3',
          teamId2: 't4',
          score1: 10,
          score2: 3,
          tableNumber: 2,
          id: 'g2-1',
          done: true);

      final gruppenphase = Gruppenphase(groups: [
        [match1],
        [match2],
      ]);
      final matchQueue = MatchQueue(queue: [], playing: []);
      final tabellen = evalGruppen(gruppenphase);

      // Simulate JSON export → import
      final exported = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matchQueue': matchQueue.toJson(),
        'gruppenphase': gruppenphase.toJson(),
        'tabellen': tabellen.toJson(),
        'knockouts': Knockouts().toJson(),
        'currentTournamentId': 'test',
        'isKnockoutMode': false,
        'tournamentStyle': 'groupsAndKnockouts',
        'numberOfTables': 6,
        'groups': Groups().toJson(),
      };

      final jsonString = jsonEncode(exported);
      final reimported = jsonDecode(jsonString) as Map<String, dynamic>;
      final snapshot = ImportService.parseSnapshotFromJson(reimported);

      final errors = ImportService.validateSnapshot(
        teams: snapshot.teams,
        matchQueue: snapshot.matchQueue,
        gruppenphase: snapshot.gruppenphase,
        tabellen: snapshot.tabellen,
        knockouts: snapshot.knockouts,
      );

      expect(errors, isEmpty);
    });

    test('tampered bracket in exported JSON is caught', () {
      final teams = [
        Team(id: 't1', name: 'Alpha', member1: 'A1', member2: 'A2'),
        Team(id: 't2', name: 'Beta', member1: 'B1', member2: 'B2'),
      ];

      final knockouts = Knockouts();
      knockouts.instantiate();
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';

      final exported = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': knockouts.toJson(),
        'isKnockoutMode': true,
        'tournamentStyle': 'knockoutsOnly',
        'numberOfTables': 6,
        'groups': Groups().toJson(),
      };

      // Tamper: remove two matches from champions round 1 (should be 8 → 4)
      final jsonString = jsonEncode(exported);
      final reimported = jsonDecode(jsonString) as Map<String, dynamic>;
      // Remove last 2 entries from champions round 0
      // ignore: avoid_dynamic_calls
      final champRounds = reimported['knockouts']['gold'] as List;
      (champRounds[0] as List).removeLast();
      (champRounds[0] as List).removeLast();
      // Now round 0 has 6 matches, round 1 still expects 4 → should fail

      final snapshot = ImportService.parseSnapshotFromJson(reimported);
      final errors = ImportService.validateSnapshot(
        teams: snapshot.teams,
        matchQueue: snapshot.matchQueue,
        gruppenphase: snapshot.gruppenphase,
        tabellen: snapshot.tabellen,
        knockouts: snapshot.knockouts,
      );

      expect(errors.any((e) => e.contains('Champions')), isTrue);
    });
  });

  // ==========================================================================
  // 11. EDGE CASES
  // ==========================================================================

  group('validateSnapshot – edge cases', () {
    test('single team with no matches is valid', () {
      final errors = ImportService.validateSnapshot(
        teams: makeTeams(1),
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );
      expect(errors, isEmpty);
    });

    test('bracket with odd first round size (3) halves to ceil(1.5)=2', () {
      // 3 → 2 → 1 (ceiling division)
      final bracket = KnockoutBracket(rounds: [
        List.generate(3, (i) => Match(id: 'x1${i + 1}')),
        List.generate(2, (i) => Match(id: 'x2${i + 1}')),
        [Match(id: 'x31')],
      ]);

      final knockouts = Knockouts(
        champions: bracket,
        europa: KnockoutBracket(),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: [],
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.where((e) => e.contains('Champions')), isEmpty);
    });

    test('unknown team in europa bracket is detected', () {
      final teams = makeTeams(2);
      final knockouts = Knockouts(
        champions: KnockoutBracket(),
        europa: KnockoutBracket(rounds: [
          [
            Match(id: 'e1-1', teamId1: 't0', teamId2: 'phantom'),
            Match(id: 'e1-2'),
          ],
          [Match(id: 'e2-1')],
        ]),
        conference: KnockoutBracket(),
        superCup: Super(),
      );

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: knockouts,
      );

      expect(errors.any((e) => e.contains('phantom')), isTrue);
      expect(errors.any((e) => e.contains('Europa')), isTrue);
    });

    test('deathcup OT done match with valid scores passes', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: -2,
              score2: 10,
              done: true),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });

    test('1-on-1 OT done match with valid scores passes', () {
      final teams = makeTeams(2);
      final gruppenphase = Gruppenphase(groups: [
        [
          Match(
              id: 'g1-1',
              teamId1: 't0',
              teamId2: 't1',
              score1: 21,
              score2: 20,
              done: true),
        ],
      ]);

      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: gruppenphase,
        tabellen: Tabellen(tables: [
          [TableRow(teamId: 't0'), TableRow(teamId: 't1')],
        ]),
        knockouts: Knockouts(),
      );

      expect(errors.where((e) => e.contains('invalid scores')), isEmpty);
    });
  });

  // ==========================================================================
  // 12. NUMBER OF TABLES VALIDATION
  // ==========================================================================

  group('validateSnapshot – numberOfTables', () {
    test('default numberOfTables (6) passes', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
      );
      expect(errors, isEmpty);
    });

    test('explicit numberOfTables=1 passes', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
        numberOfTables: 1,
      );
      expect(errors, isEmpty);
    });

    test('numberOfTables=10 passes', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
        numberOfTables: 10,
      );
      expect(errors, isEmpty);
    });

    test('numberOfTables=0 fails', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
        numberOfTables: 0,
      );
      expect(errors.any((e) => e.contains('numberOfTables')), isTrue);
    });

    test('numberOfTables=-1 fails', () {
      final s = validSnapshot();
      final errors = ImportService.validateSnapshot(
        teams: s.teams,
        matchQueue: s.matchQueue,
        gruppenphase: s.gruppenphase,
        tabellen: s.tabellen,
        knockouts: s.knockouts,
        numberOfTables: -1,
      );
      expect(errors.any((e) => e.contains('numberOfTables')), isTrue);
    });
  });

  // ==========================================================================
  // 13. GROUPS / TEAMS CONSISTENCY VALIDATION
  // ==========================================================================

  group('validateSnapshot – groups consistency', () {
    test('valid groups with matching team IDs passes', () {
      final teams = makeTeams(4);
      final groups = Groups(groups: [
        ['t0', 't1'],
        ['t2', 't3'],
      ]);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
        groups: groups,
      );
      expect(errors, isEmpty);
    });

    test('null groups passes', () {
      final errors = ImportService.validateSnapshot(
        teams: makeTeams(2),
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
      );
      expect(errors, isEmpty);
    });

    test('empty groups passes', () {
      final errors = ImportService.validateSnapshot(
        teams: makeTeams(2),
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
        groups: Groups(),
      );
      expect(errors, isEmpty);
    });

    test('unknown team ID in groups fails', () {
      final teams = makeTeams(2); // t0, t1
      final groups = Groups(groups: [
        ['t0', 't1', 'phantom'],
      ]);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
        groups: groups,
      );
      expect(errors.any((e) => e.contains('phantom')), isTrue);
      expect(errors.any((e) => e.contains('groups group 0')), isTrue);
    });

    test('multiple unknown team IDs in different groups', () {
      final teams = makeTeams(2); // t0, t1
      final groups = Groups(groups: [
        ['t0', 'fake1'],
        ['t1', 'fake2'],
      ]);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
        groups: groups,
      );
      expect(errors.length, 2);
      expect(errors.any((e) => e.contains('fake1')), isTrue);
      expect(errors.any((e) => e.contains('fake2')), isTrue);
    });

    test('empty team ID in groups is ignored', () {
      final teams = makeTeams(2);
      final groups = Groups(groups: [
        ['t0', '', 't1'],
      ]);
      final errors = ImportService.validateSnapshot(
        teams: teams,
        matchQueue: MatchQueue(),
        gruppenphase: Gruppenphase(),
        tabellen: Tabellen(),
        knockouts: Knockouts(),
        groups: groups,
      );
      expect(errors, isEmpty);
    });
  });

  // ==========================================================================
  // 14. PARSE SNAPSHOT – NEW FIELDS (numberOfTables, groups)
  // ==========================================================================

  group('parseSnapshotFromJson – numberOfTables and groups', () {
    test('parses numberOfTables from JSON', () {
      final json = {
        'teams': <dynamic>[],
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': Knockouts().toJson(),
        'numberOfTables': 8,
        'groups': Groups().toJson(),
      };
      final snapshot = ImportService.parseSnapshotFromJson(json);
      expect(snapshot.numberOfTables, 8);
    });

    test('throws when numberOfTables is missing', () {
      final json = {
        'teams': <dynamic>[],
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': Knockouts().toJson(),
        'groups': Groups().toJson(),
      };
      expect(
        () => ImportService.parseSnapshotFromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('parses groups from JSON', () {
      final groups = Groups(groups: [
        ['t0', 't1'],
        ['t2', 't3'],
      ]);
      final json = {
        'teams': makeTeams(4).map((t) => t.toJson()).toList(),
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': Knockouts().toJson(),
        'numberOfTables': 6,
        'groups': groups.toJson(),
      };
      final snapshot = ImportService.parseSnapshotFromJson(json);
      expect(snapshot.groups.groups.length, 2);
      expect(snapshot.groups.groups[0], ['t0', 't1']);
      expect(snapshot.groups.groups[1], ['t2', 't3']);
    });

    test('throws when groups is missing', () {
      final json = {
        'teams': <dynamic>[],
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': Knockouts().toJson(),
        'numberOfTables': 6,
      };
      expect(
        () => ImportService.parseSnapshotFromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('full round-trip preserves numberOfTables and groups', () {
      final teams = makeTeams(4);
      final groups = Groups(groups: [
        ['t0', 't1'],
        ['t2', 't3'],
      ]);
      final exported = {
        'teams': teams.map((t) => t.toJson()).toList(),
        'matchQueue': MatchQueue().toJson(),
        'gruppenphase': Gruppenphase().toJson(),
        'tabellen': Tabellen().toJson(),
        'knockouts': Knockouts().toJson(),
        'currentTournamentId': 'test',
        'isKnockoutMode': false,
        'tournamentStyle': 'groupsAndKnockouts',
        'numberOfTables': 4,
        'groups': groups.toJson(),
      };

      final jsonString = jsonEncode(exported);
      final reimported = jsonDecode(jsonString) as Map<String, dynamic>;
      final snapshot = ImportService.parseSnapshotFromJson(reimported);

      expect(snapshot.numberOfTables, 4);
      expect(snapshot.groups.groups.length, 2);
      expect(snapshot.groups, groups);

      final errors = ImportService.validateSnapshot(
        teams: snapshot.teams,
        matchQueue: snapshot.matchQueue,
        gruppenphase: snapshot.gruppenphase,
        tabellen: snapshot.tabellen,
        knockouts: snapshot.knockouts,
        numberOfTables: snapshot.numberOfTables,
        groups: snapshot.groups,
      );
      expect(errors, isEmpty);
    });
  });
}
