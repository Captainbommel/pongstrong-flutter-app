import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups/groups.dart';
import 'package:pongstrong/models/team.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FirestoreService makeService([FakeFirebaseFirestore? fs]) =>
    FirestoreService.forTesting(fs ?? FakeFirebaseFirestore());

List<Team> buildTeams(int count) => List.generate(
      count,
      (i) => Team(
        id: 'team_$i',
        name: 'Team $i',
        member1: 'Player ${i}A',
        member2: 'Player ${i}B',
      ),
    );

Groups buildGroups(List<Team> teams, int numGroups) {
  final groups = List.generate(numGroups, (_) => <String>[]);
  for (int i = 0; i < teams.length; i++) {
    groups[i % numGroups].add(teams[i].id);
  }
  return Groups(groups: groups);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  group('FirestoreService – teams CRUD', () {
    test('saveTeams and loadTeams round-trip', () async {
      final svc = makeService();
      final teams = buildTeams(4);

      await svc.saveTeams(teams);
      final loaded = await svc.loadTeams();

      expect(loaded, isNotNull);
      expect(loaded!.length, 4);
      expect(loaded.map((t) => t.id).toList(),
          containsAll(teams.map((t) => t.id)));
    });

    test('loadTeams returns null for missing doc', () async {
      final svc = makeService();
      final loaded = await svc.loadTeams();
      expect(loaded, isNull);
    });

    test('saveTeams overwrites previous data', () async {
      final svc = makeService();
      await svc.saveTeams(buildTeams(4));
      await svc.saveTeams(buildTeams(2));
      final loaded = await svc.loadTeams();
      expect(loaded!.length, 2);
    });
  });

  // =========================================================================
  group('FirestoreService – groups CRUD', () {
    test('saveGroups and loadGroups round-trip', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.saveGroups(groups);
      final loaded = await svc.loadGroups();

      expect(loaded, isNotNull);
      expect(loaded!.groups.length, 2);
      expect(loaded.groups[0].length, 4); // 8 teams / 2 groups
      expect(loaded.groups[1].length, 4);
    });

    test('loadGroups returns null for missing doc', () async {
      final svc = makeService();
      expect(await svc.loadGroups(), isNull);
    });
  });

  // =========================================================================
  group('FirestoreService – gruppenphase CRUD', () {
    test('saveGruppenphase and loadGruppenphase round-trip', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.saveTeams(teams);
      await svc.saveGroups(groups);

      final gp = await svc.loadGruppenphase();
      // Not saved yet → null
      expect(gp, isNull);
    });
  });

  // =========================================================================
  group('initializeTournament', () {
    test('creates all required collections', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.initializeTournament(teams, groups, tableCount: 3);

      // Teams
      final loadedTeams = await svc.loadTeams();
      expect(loadedTeams!.length, 8);

      // Groups
      final loadedGroups = await svc.loadGroups();
      expect(loadedGroups!.groups.length, 2);

      // Gruppenphase
      final gp = await svc.loadGruppenphase();
      expect(gp, isNotNull);
      expect(gp!.groups.length, 2);
      // 4 teams per group → 6 matches each
      expect(gp.groups[0].length, 6);
      expect(gp.groups[1].length, 6);

      // Match queue
      final queue = await svc.loadMatchQueue();
      expect(queue, isNotNull);

      // Knockouts (empty at start)
      final knockouts = await svc.loadKnockouts();
      expect(knockouts, isNotNull);

      // Tournament metadata
      final meta = await svc.getTournamentMetadata();
      expect(meta, isNotNull);
      expect(meta!['phase'], 'groups');
    });

    test('every match has a valid table number', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.initializeTournament(teams, groups, tableCount: 3);
      final gp = await svc.loadGruppenphase();

      for (final group in gp!.groups) {
        for (final match in group) {
          expect(match.tableNumber, inInclusiveRange(1, 3));
        }
      }
    });

    test('all matches start as not done', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.initializeTournament(teams, groups);
      final gp = await svc.loadGruppenphase();

      for (final group in gp!.groups) {
        for (final match in group) {
          expect(match.done, isFalse);
          expect(match.score1, 0);
          expect(match.score2, 0);
        }
      }
    });
  });

  // =========================================================================
  group('initializeKOOnlyTournament', () {
    test('creates bracket for 8 teams', () async {
      final svc = makeService();
      final teams = buildTeams(8);

      await svc.initializeKOOnlyTournament(teams, tableCount: 4);

      final teams2 = await svc.loadTeams();
      expect(teams2!.length, 8);

      final knockouts = await svc.loadKnockouts();
      expect(knockouts, isNotNull);
      // 8 teams: 4 matches in R1, 2 in QF, 1 in SF, 1 final = 4 rounds
      expect(knockouts!.champions.rounds.length, 3);
      expect(knockouts.champions.rounds[0].length, 4); // R1: 4 matches
      expect(knockouts.champions.rounds[1].length, 2); // QF: 2 matches
      expect(knockouts.champions.rounds[2].length, 1); // Final: 1 match

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'knockouts');
      expect(meta['tournamentStyle'], 'knockoutsOnly');
    });

    test('creates bracket for 16 teams', () async {
      final svc = makeService();
      await svc.initializeKOOnlyTournament(buildTeams(16));

      final knockouts = await svc.loadKnockouts();
      expect(knockouts!.champions.rounds.length, 4);
      expect(knockouts.champions.rounds[0].length, 8); // R1: 8 matches
      expect(knockouts.champions.rounds[3].length, 1); // Final
    });

    test('first round matches have correct team assignments', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      await svc.initializeKOOnlyTournament(teams);

      final knockouts = await svc.loadKnockouts();
      final firstRound = knockouts!.champions.rounds[0];
      // Pairs: [0,1],[2,3],[4,5],[6,7]
      expect(firstRound[0].teamId1, teams[0].id);
      expect(firstRound[0].teamId2, teams[1].id);
      expect(firstRound[1].teamId1, teams[2].id);
      expect(firstRound[1].teamId2, teams[3].id);
    });

    test('later rounds start with empty team slots', () async {
      final svc = makeService();
      await svc.initializeKOOnlyTournament(buildTeams(8));

      final knockouts = await svc.loadKnockouts();
      for (int r = 1; r < knockouts!.champions.rounds.length; r++) {
        for (final m in knockouts.champions.rounds[r]) {
          expect(m.teamId1, isEmpty);
          expect(m.teamId2, isEmpty);
        }
      }
    });
  });

  // =========================================================================
  group('initializeRoundRobinTournament', () {
    test('creates correct number of matches for even team count', () async {
      final svc = makeService();
      await svc.initializeRoundRobinTournament(buildTeams(6), tableCount: 3);

      final gp = await svc.loadGruppenphase();
      expect(gp, isNotNull);
      // 6 teams: 6*5/2 = 15 matches stored in a single group
      expect(gp!.groups.length, 1);
      expect(gp.groups[0].length, 15);
    });

    test('creates correct number of matches for odd team count', () async {
      final svc = makeService();
      await svc.initializeRoundRobinTournament(buildTeams(5), tableCount: 3);

      final gp = await svc.loadGruppenphase();
      // 5 teams: 5*4/2 = 10 real matches (BYE slots skipped)
      expect(gp!.groups[0].length, 10);
    });

    test('every pair of teams plays exactly once', () async {
      final svc = makeService();
      final teams = buildTeams(6);
      await svc.initializeRoundRobinTournament(teams);

      final gp = await svc.loadGruppenphase();
      final matches = gp!.groups[0];

      // Build set of {id1, id2} pairs
      final pairs = matches.map((m) => <String>{m.teamId1, m.teamId2}).toSet();

      // All C(6,2) = 15 unique pairs
      expect(pairs.length, 15);

      // No team plays itself
      for (final m in matches) {
        expect(m.teamId1, isNot(m.teamId2));
      }
    });

    test('sets phase to groups and style to everyoneVsEveryone', () async {
      final svc = makeService();
      await svc.initializeRoundRobinTournament(buildTeams(4));

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'groups');
      expect(meta['tournamentStyle'], 'everyoneVsEveryone');
    });
  });

  // =========================================================================
  group('transitionToKnockouts', () {
    test('advances phase and populates knockouts from completed groups',
        () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      final teams = buildTeams(24);
      final groups = buildGroups(teams, 6);

      await svc.initializeTournament(teams, groups);

      // Mark all group matches as done with valid scores
      final gp = await svc.loadGruppenphase();
      for (final group in gp!.groups) {
        for (final match in group) {
          match.done = true;
          match.score1 = 10;
          match.score2 = 5;
        }
      }
      await svc.saveGruppenphase(gp);

      await svc.transitionToKnockouts(numberOfGroups: 6);

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'knockouts');

      final knockouts = await svc.loadKnockouts();
      expect(knockouts, isNotNull);
      // Champions bracket should have seeded teams in R1
      expect(
          knockouts!.champions.rounds[0][0].teamId1.isNotEmpty ||
              knockouts.champions.rounds[0][0].teamId2.isNotEmpty,
          isTrue);
    });
  });

  // =========================================================================
  group('revertToGroupPhase', () {
    test('sets phase back to groups', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      await svc.initializeTournament(teams, groups);

      // Manually set phase to knockouts
      await svc.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(FirestoreBase.defaultTournamentId)
          .update({'phase': 'knockouts'});

      await svc.revertToGroupPhase();

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'groups');
    });
  });

  // =========================================================================
  group('resetTournament', () {
    test('deletes gruppenphase, queue, knockouts, tabellen; phase → notStarted',
        () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      await svc.initializeTournament(teams, groups);

      await svc.resetTournament();

      expect(await svc.loadGruppenphase(), isNull);
      expect(await svc.loadMatchQueue(), isNull);
      expect(await svc.loadKnockouts(), isNull);

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'notStarted');
    });

    test('teams are still present after reset', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      await svc.initializeTournament(teams, groups);

      await svc.resetTournament();

      // Teams doc was not deleted
      final loadedTeams = await svc.loadTeams();
      expect(loadedTeams, isNotNull);
      expect(loadedTeams!.length, 8);
    });
  });

  // =========================================================================
  group('createTournament', () {
    test('creates tournament with correct metadata', () async {
      final svc = makeService();
      final id = await svc.createTournament(
        tournamentName: 'Test Cup',
        creatorId: 'user1',
        password: 'secret',
      );

      expect(id, 'Test-Cup');

      final meta = await svc.getTournamentInfo('Test-Cup');
      expect(meta, isNotNull);
      expect(meta!['name'], 'Test Cup');
      expect(meta['creatorId'], 'user1');
      expect(meta['phase'], 'setup');
    });

    test('returns null if tournament name is taken', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      await svc.createTournament(
          tournamentName: 'My Cup', creatorId: 'u1', password: 'pw');
      final id2 = await svc.createTournament(
          tournamentName: 'My Cup', creatorId: 'u2', password: 'pw');
      expect(id2, isNull);
    });
  });

  // =========================================================================
  group('verifyTournamentPassword', () {
    test('accepts correct password', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Secure Cup', creatorId: 'u1', password: 'hunter2');

      final ok = await svc.verifyTournamentPassword('Secure-Cup', 'hunter2');
      expect(ok, isTrue);
    });

    test('rejects wrong password', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Secure Cup', creatorId: 'u1', password: 'hunter2');

      final ok = await svc.verifyTournamentPassword('Secure-Cup', 'wrong');
      expect(ok, isFalse);
    });

    test('returns false for non-existent tournament', () async {
      final svc = makeService();
      expect(await svc.verifyTournamentPassword('ghost', 'pw'), isFalse);
    });
  });

  // =========================================================================
  group('isCreator / isParticipant', () {
    test('creator is recognized', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'My Cup', creatorId: 'owner', password: 'pw');

      expect(await svc.isCreator('My-Cup', 'owner'), isTrue);
      expect(await svc.isCreator('My-Cup', 'stranger'), isFalse);
    });

    test('creator counts as participant', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Fan Cup', creatorId: 'boss', password: 'pw');

      expect(await svc.isParticipant('Fan-Cup', 'boss'), isTrue);
    });

    test('joinTournament adds participant', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Join Cup', creatorId: 'boss', password: 'pw');

      await svc.joinTournament('Join-Cup', 'newcomer');

      expect(await svc.isParticipant('Join-Cup', 'newcomer'), isTrue);
      expect(await svc.isParticipant('Join-Cup', 'nobody'), isFalse);
    });
  });

  // =========================================================================
  group('importTeamsAndGroups', () {
    test('saves teams and groups, phase stays notStarted', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.importTeamsAndGroups(teams, groups);

      final loadedTeams = await svc.loadTeams();
      expect(loadedTeams!.length, 8);

      final loadedGroups = await svc.loadGroups();
      expect(loadedGroups!.groups.length, 2);

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'notStarted');
    });
  });

  // =========================================================================
  group('importTeamsOnly', () {
    test('saves teams, phase stays notStarted', () async {
      final svc = makeService();
      final teams = buildTeams(5);

      await svc.importTeamsOnly(teams);

      final loadedTeams = await svc.loadTeams();
      expect(loadedTeams!.length, 5);

      final meta = await svc.getTournamentMetadata();
      expect(meta!['phase'], 'notStarted');
    });
  });

  // =========================================================================
  group('updateTournamentStyle', () {
    test('writes style field to Firestore', () async {
      final svc = makeService();
      // Create tournament doc first
      await svc.createTournament(
          tournamentName: 'Style Cup', creatorId: 'u1', password: 'pw');

      await svc.updateTournamentStyle(
        tournamentId: 'Style-Cup',
        style: 'knockoutsOnly',
      );

      final doc = await svc.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc('Style-Cup')
          .get();
      final data = doc.data()!;
      expect(data['tournamentStyle'], 'knockoutsOnly');
    });
  });

  // =========================================================================
  group('Match queue – integration', () {
    test(
        'match queue after initializeTournament contains group matches in waiting',
        () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      await svc.initializeTournament(teams, groups, tableCount: 3);
      final queue = await svc.loadMatchQueue();

      expect(queue, isNotNull);
      // waiting is indexed by table number, all matches start in waiting
      final waitingCount =
          queue!.waiting.fold<int>(0, (sum, slot) => sum + slot.length);
      expect(waitingCount, greaterThan(0));
      expect(queue.playing, isEmpty);
    });

    test('KO-only queue contains first round matches', () async {
      final svc = makeService();
      await svc.initializeKOOnlyTournament(buildTeams(8), tableCount: 4);
      final queue = await svc.loadMatchQueue();

      expect(queue, isNotNull);
      expect(queue!.waiting.length, 4); // 4 tables
      final waitingCount =
          queue.waiting.fold<int>(0, (sum, slot) => sum + slot.length);
      expect(waitingCount, 4); // 4 first-round matches
    });

    test('round-robin queue distributes matches across tables', () async {
      final svc = makeService();
      await svc.initializeRoundRobinTournament(buildTeams(4), tableCount: 2);
      final queue = await svc.loadMatchQueue();

      expect(queue, isNotNull);
      final totalQueued =
          queue!.waiting.fold<int>(0, (sum, slot) => sum + slot.length);
      expect(totalQueued, 6); // C(4,2) = 6 matches
    });
  });

  // =========================================================================
  group('deleteTournament', () {
    test('removes all tournament data', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      await svc.initializeTournament(teams, groups);

      await svc.deleteTournament();

      expect(await svc.loadTeams(), isNull);
      expect(await svc.loadGroups(), isNull);
      expect(await svc.loadGruppenphase(), isNull);
      expect(await svc.loadMatchQueue(), isNull);
      expect(await svc.loadKnockouts(), isNull);
      expect(await svc.getTournamentMetadata(), isNull);
    });
  });

  // =========================================================================
  group('tournamentExists', () {
    test('returns false for nonexistent tournament', () async {
      final svc = makeService();
      expect(await svc.tournamentExists(tournamentId: 'ghost'), isFalse);
    });

    test('returns true after createTournament', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Exists Cup', creatorId: 'u1', password: 'pw');
      expect(await svc.tournamentExists(tournamentId: 'Exists-Cup'), isTrue);
    });
  });

  // =========================================================================
  group('listTournaments & listUserTournaments', () {
    test('lists all created tournaments', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      await svc.createTournament(
          tournamentName: 'Cup A', creatorId: 'u1', password: 'pw');
      await svc.createTournament(
          tournamentName: 'Cup B', creatorId: 'u2', password: 'pw');

      final all = await svc.listTournaments();
      expect(all, containsAll(['Cup-A', 'Cup-B']));
    });

    test('listUserTournaments filters by creator', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      await svc.createTournament(
          tournamentName: 'Mine', creatorId: 'me', password: 'pw');
      await svc.createTournament(
          tournamentName: 'Theirs', creatorId: 'them', password: 'pw');

      final mine = await svc.listUserTournaments('me');
      expect(mine, contains('Mine'));
      expect(mine, isNot(contains('Theirs')));
    });
  });

  // =========================================================================
  group('updateStandings', () {
    test('recalculates standings after match results change', () async {
      final svc = makeService();
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      await svc.initializeTournament(teams, groups);

      // Complete one match
      final gp = await svc.loadGruppenphase();
      gp!.groups[0][0].done = true;
      gp.groups[0][0].score1 = 10;
      gp.groups[0][0].score2 = 5;
      await svc.saveGruppenphase(gp);

      await svc.updateStandings();

      final tabellen = await svc.loadTabellen();
      expect(tabellen, isNotNull);
      // The winning team should have 3 points
      final winnerRow = tabellen!.tables[0]
          .firstWhere((row) => row.teamId == gp.groups[0][0].teamId1);
      expect(winnerRow.points, 3);
    });
  });

  // =========================================================================
  group('revertToGroupPhase – table count handling', () {
    test('derives queue size from actual match table numbers', () async {
      final svc = makeService();
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);

      // Initialize with 3 tables
      await svc.initializeTournament(teams, groups, tableCount: 3);

      // Manually advance to knockouts
      await svc.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(FirestoreBase.defaultTournamentId)
          .update({'phase': 'knockouts'});

      await svc.revertToGroupPhase();

      final queue = await svc.loadMatchQueue();
      expect(queue, isNotNull);
      // Queue should have slots for at least the max table number (3+)
      // All undone matches should be in the queue
      final totalQueued =
          queue!.waiting.fold<int>(0, (sum, slot) => sum + slot.length);
      // 2 groups × C(4,2) = 12 matches, all undone
      expect(totalQueued, 12);
    });
  });

  // =========================================================================
  group('getTournamentInfo', () {
    test('returns info without password', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'Info Cup', creatorId: 'u1', password: 'secret');

      final info = await svc.getTournamentInfo('Info-Cup');
      expect(info, isNotNull);
      expect(info!['name'], 'Info Cup');
      expect(info['creatorId'], 'u1');
      expect(info.containsKey('password'), isFalse);
    });

    test('returns null for nonexistent tournament', () async {
      final svc = makeService();
      expect(await svc.getTournamentInfo('ghost'), isNull);
    });
  });

  // =========================================================================
  group('tournamentHasPassword', () {
    test('returns true when password is set', () async {
      final svc = makeService();
      await svc.createTournament(
          tournamentName: 'PW Cup', creatorId: 'u1', password: 'pw');

      expect(await svc.tournamentHasPassword('PW-Cup'), isTrue);
    });

    test('returns false for nonexistent tournament', () async {
      final svc = makeService();
      expect(await svc.tournamentHasPassword('ghost'), isFalse);
    });
  });
}
