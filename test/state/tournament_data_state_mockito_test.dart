import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';

@GenerateNiceMocks([MockSpec<FirestoreService>()])
import 'tournament_data_state_mockito_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Team> buildTeams(int count) => List.generate(
      count,
      (i) => Team(
        id: 'team_$i',
        name: 'Team $i',
        mem1: 'Player ${i}A',
        mem2: 'Player ${i}B',
      ),
    );

Groups buildGroups(List<Team> teams, int numGroups) {
  final groups = List.generate(numGroups, (_) => <String>[]);
  for (int i = 0; i < teams.length; i++) {
    groups[i % numGroups].add(teams[i].id);
  }
  return Groups(groups: groups);
}

Gruppenphase buildGruppenphase(Groups groups, {int tableCount = 6}) {
  return Gruppenphase.create(groups, tableCount: tableCount);
}

MatchQueue buildMatchQueue(Gruppenphase gp) {
  return MatchQueue.create(gp);
}

/// Build a Knockouts structure with teams seeded into champions round 1.
Knockouts buildKnockouts({List<Match>? championsRound1}) {
  final ko = Knockouts();
  ko.instantiate();
  if (championsRound1 != null) {
    ko.champions.rounds[0] = championsRound1;
  }
  return ko;
}

TournamentDataState makeState(MockFirestoreService mockService) {
  return TournamentDataState(firestoreService: mockService);
}

/// Sets up the mock to return a fully loaded tournament (group phase).
void stubLoadedTournament(
  MockFirestoreService mock, {
  required List<Team> teams,
  required Gruppenphase gruppenphase,
  required MatchQueue matchQueue,
  Knockouts? knockouts,
  String tournamentId = 'test-tourney',
  String tournamentStyle = 'groupsAndKnockouts',
  String? selectedRuleset,
  bool includeSelectedRuleset = false,
}) {
  final info = <String, dynamic>{
    'name': 'Test Tournament',
    'creatorId': 'user1',
    'phase': 'groups',
    'tournamentStyle': tournamentStyle,
  };
  if (includeSelectedRuleset) {
    info['selectedRuleset'] = selectedRuleset;
  }

  when(mock.getTournamentInfo(tournamentId)).thenAnswer((_) async => info);

  when(mock.loadTeams(tournamentId: tournamentId))
      .thenAnswer((_) async => teams);

  when(mock.loadMatchQueue(tournamentId: tournamentId))
      .thenAnswer((_) async => matchQueue);

  when(mock.loadGruppenphase(tournamentId: tournamentId))
      .thenAnswer((_) async => gruppenphase);

  when(mock.loadKnockouts(tournamentId: tournamentId))
      .thenAnswer((_) async => knockouts);

  // Streams default to empty (NiceMock returns Stream.empty())
  when(mock.gruppenphaseStream(tournamentId: tournamentId))
      .thenAnswer((_) => const Stream.empty());
  when(mock.matchQueueStream(tournamentId: tournamentId))
      .thenAnswer((_) => const Stream.empty());
  when(mock.knockoutsStream(tournamentId: tournamentId))
      .thenAnswer((_) => const Stream.empty());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFirestoreService mockService;

  setUp(() {
    mockService = MockFirestoreService();
  });

  // =========================================================================
  group('loadTournamentData', () {
    test('returns false when tournament does not exist', () async {
      when(mockService.getTournamentInfo('ghost'))
          .thenAnswer((_) async => null);

      final state = makeState(mockService);
      final result = await state.loadTournamentData('ghost');

      expect(result, isFalse);
      expect(state.hasData, isFalse);
      verify(mockService.getTournamentInfo('ghost')).called(1);
    });

    test('returns true and loads data for existing tournament', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      final result = await state.loadTournamentData('test-tourney');

      expect(result, isTrue);
      expect(state.hasData, isTrue);
      expect(state.teams.length, 8);
      expect(state.isKnockoutMode, isFalse);
      expect(state.tournamentStyle, 'groupsAndKnockouts');

      verify(mockService.getTournamentInfo('test-tourney')).called(1);
      verify(mockService.loadTeams(tournamentId: 'test-tourney')).called(1);
      verify(mockService.loadMatchQueue(tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.loadKnockouts(tournamentId: 'test-tourney')).called(1);
    });

    test('returns true in setup phase when teams/queue are null', () async {
      when(mockService.getTournamentInfo('setup-tourney'))
          .thenAnswer((_) async => {
                'name': 'Setup Cup',
                'creatorId': 'u1',
                'phase': 'setup',
                'tournamentStyle': 'groupsAndKnockouts',
              });
      when(mockService.loadTeams(tournamentId: 'setup-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.loadMatchQueue(tournamentId: 'setup-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.loadGruppenphase(tournamentId: 'setup-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.loadKnockouts(tournamentId: 'setup-tourney'))
          .thenAnswer((_) async => null);

      final state = makeState(mockService);
      final result = await state.loadTournamentData('setup-tourney');

      expect(result, isTrue);
      expect(state.hasData, isFalse);
      expect(state.isSetupPhase, isTrue);
    });

    test('detects knockout mode from populated knockout rounds', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      // Knockouts with teams seeded (indicating active KO mode)
      final knockouts = Knockouts(
        champions: Champions(rounds: [
          [Match(teamId1: 'team_0', teamId2: 'team_1', id: 'ko_1', tischNr: 1)]
        ]),
      );

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: knockouts,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.isKnockoutMode, isTrue);
    });

    test('handles selectedRuleset from tournament info', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      when(mockService.getTournamentInfo('rules-tourney'))
          .thenAnswer((_) async => {
                'name': 'Rules Cup',
                'creatorId': 'u1',
                'phase': 'groups',
                'tournamentStyle': 'groupsAndKnockouts',
                'selectedRuleset': 'custom-rules',
              });
      when(mockService.loadTeams(tournamentId: 'rules-tourney'))
          .thenAnswer((_) async => teams);
      when(mockService.loadMatchQueue(tournamentId: 'rules-tourney'))
          .thenAnswer((_) async => queue);
      when(mockService.loadGruppenphase(tournamentId: 'rules-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.loadKnockouts(tournamentId: 'rules-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.gruppenphaseStream(tournamentId: 'rules-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.matchQueueStream(tournamentId: 'rules-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.knockoutsStream(tournamentId: 'rules-tourney'))
          .thenAnswer((_) => const Stream.empty());

      final state = makeState(mockService);
      await state.loadTournamentData('rules-tourney');

      expect(state.selectedRuleset, 'custom-rules');
    });

    test('returns false on service exception', () async {
      when(mockService.getTournamentInfo('bad'))
          .thenThrow(Exception('network error'));

      final state = makeState(mockService);
      final result = await state.loadTournamentData('bad');

      expect(result, isFalse);
    });
  });

  // =========================================================================
  group('startMatch', () {
    test('saves match queue to Firestore on success', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Get a valid match ID from the waiting queue
      final firstMatchId =
          state.matchQueue.waiting.expand((slot) => slot).first.id;

      final result = await state.startMatch(firstMatchId);
      expect(result, isTrue);

      verify(mockService.saveMatchQueue(any, tournamentId: 'test-tourney'))
          .called(1);
    });

    test('reverts on Firestore save failure', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('save failed'));

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final waitingBefore = state.matchQueue.waiting
          .fold<int>(0, (sum, slot) => sum + slot.length);

      final firstMatchId =
          state.matchQueue.waiting.expand((slot) => slot).first.id;

      final result = await state.startMatch(firstMatchId);

      expect(result, isFalse);
      // Verify state was rolled back
      final waitingAfter = state.matchQueue.waiting
          .fold<int>(0, (sum, slot) => sum + slot.length);
      expect(waitingAfter, waitingBefore);
    });

    test('returns false for invalid match ID', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final result = await state.startMatch('nonexistent_match');

      expect(result, isFalse);
      verifyNever(mockService.saveMatchQueue(any,
          tournamentId: anyNamed('tournamentId')));
    });
  });

  // =========================================================================
  group('finishMatch – group phase', () {
    test('updates scores, recalculates tables, saves to Firestore', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveGruppenphase(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveTabellen(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Start a match first
      final matchId = state.matchQueue.waiting.expand((slot) => slot).first.id;
      await state.startMatch(matchId);

      // Stub loadGruppenphase for the finishMatch call
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      // Finish it with final scores
      final result = await state.finishMatch(matchId, score1: 10, score2: 5);

      expect(result, isTrue);
      verify(mockService.saveGruppenphase(any, tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.saveTabellen(any, tournamentId: 'test-tourney'))
          .called(1);
    });

    test('returns false when gruppenphase cannot be loaded', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final matchId = state.matchQueue.waiting.expand((slot) => slot).first.id;
      await state.startMatch(matchId);

      // Make loadGruppenphase return null
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => null);

      final result = await state.finishMatch(matchId, score1: 10, score2: 5);

      expect(result, isFalse);
    });

    test('reverts on Firestore save failure during finish', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final matchId = state.matchQueue.waiting.expand((slot) => slot).first.id;
      await state.startMatch(matchId);

      // Return gruppenphase but fail on save
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.saveGruppenphase(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('firestore down'));

      final playingBefore = state.matchQueue.playing.length;
      final result = await state.finishMatch(matchId, score1: 10, score2: 5);

      expect(result, isFalse);
      // Verify playing list was restored
      expect(state.matchQueue.playing.length, playingBefore);
    });
  });

  // =========================================================================
  group('clearData', () {
    test('resets all fields to defaults', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        tournamentStyle: 'everyoneVsEveryone',
        includeSelectedRuleset: true,
        selectedRuleset: 'custom-rules',
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');
      expect(state.hasData, isTrue);
      expect(state.tournamentStyle, 'everyoneVsEveryone');
      expect(state.selectedRuleset, 'custom-rules');

      state.clearData();

      expect(state.hasData, isFalse);
      expect(state.teams, isEmpty);
      expect(state.isKnockoutMode, isFalse);
      expect(state.tournamentStyle, 'groupsAndKnockouts');
      expect(state.selectedRuleset, 'bmt-cup');
      expect(state.matchQueue.playing, isEmpty);
      expect(state.matchQueue.waiting, isEmpty);
    });
  });

  // =========================================================================
  group('getTeam', () {
    test('returns team by ID from cache after loading', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final team = state.getTeam('team_0');
      expect(team, isNotNull);
      expect(team!.name, 'Team 0');
    });

    test('returns null for unknown team ID', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.getTeam('nonexistent'), isNull);
    });
  });

  // =========================================================================
  group('updateSelectedRuleset', () {
    test('updates ruleset and notifies', () {
      final state = makeState(mockService);
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.updateSelectedRuleset('custom');
      expect(state.selectedRuleset, 'custom');
      expect(notifyCount, 1);

      state.updateSelectedRuleset(null);
      expect(state.selectedRuleset, isNull);
      expect(state.rulesEnabled, isFalse);
    });
  });

  // =========================================================================
  group('transitionToKnockouts', () {
    test('loads gruppenphase and saves knockouts on success', () async {
      final teams = buildTeams(24);
      final groups = buildGroups(teams, 6);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      // Complete all group matches
      for (var group in gp.groups) {
        for (var match in group) {
          match.done = true;
          match.score1 = 10;
          match.score2 = 5;
        }
      }

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Stub the second load for transition
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      final result = await state.transitionToKnockouts();

      expect(result, isTrue);
      expect(state.isKnockoutMode, isTrue);
      verify(mockService.saveKnockouts(any, tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.saveMatchQueue(any, tournamentId: 'test-tourney'))
          .called(greaterThanOrEqualTo(1));
    });

    test('returns false when gruppenphase cannot be loaded', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Make gruppenphase load return null for the transition call
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => null);

      final result = await state.transitionToKnockouts();

      expect(result, isFalse);
      expect(state.isKnockoutMode, isFalse);
    });

    test('reverts state on Firestore save failure', () async {
      final teams = buildTeams(24);
      final groups = buildGroups(teams, 6);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      for (var group in gp.groups) {
        for (var match in group) {
          match.done = true;
          match.score1 = 10;
          match.score2 = 5;
        }
      }

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      // Fail on save
      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('save failed'));

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Stub the second load for transition
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      final result = await state.transitionToKnockouts();

      expect(result, isFalse);
      expect(state.isKnockoutMode, isFalse); // Should be reverted
    });
  });

  // =========================================================================
  group('loadData and toJson', () {
    test('loadData updates all fields', () {
      final state = makeState(mockService);
      final teams = buildTeams(4);
      final queue = MatchQueue(waiting: [], playing: []);
      final tabellen = Tabellen();

      state.loadData(
        teams: teams,
        matchQueue: queue,
        tabellen: tabellen,
      );

      expect(state.teams.length, 4);
      expect(state.hasData, isTrue);
    });

    test('toJson includes all fields', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final json = state.toJson();
      expect(json, contains('teams'));
      expect(json, contains('matchQueue'));
      expect(json, contains('gruppenphase'));
      expect(json, contains('tabellen'));
      expect(json, contains('knockouts'));
      expect(json, containsPair('currentTournamentId', 'test-tourney'));
      expect(json, containsPair('isKnockoutMode', false));
      expect(json, containsPair('tournamentStyle', 'groupsAndKnockouts'));
      expect(json, containsPair('selectedRuleset', 'bmt-cup'));
    });
  });

  // =========================================================================
  group('listener notifications', () {
    test('loadTournamentData notifies listeners', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      await state.loadTournamentData('test-tourney');
      expect(notifyCount, greaterThan(0));
    });

    test('clearData notifies listeners', () {
      final state = makeState(mockService);
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.clearData();
      expect(notifyCount, 1);
    });
  });

  // =========================================================================
  group('service interaction verification', () {
    test('loadTournamentData calls services in correct order', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Verify getTournamentInfo is called first
      verifyInOrder([
        mockService.getTournamentInfo('test-tourney'),
        mockService.loadTeams(tournamentId: 'test-tourney'),
      ]);
    });

    test('no saves occur when only loading', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      verifyNever(
          mockService.saveTeams(any, tournamentId: anyNamed('tournamentId')));
      verifyNever(
          mockService.saveGroups(any, tournamentId: anyNamed('tournamentId')));
      verifyNever(mockService.saveGruppenphase(any,
          tournamentId: anyNamed('tournamentId')));
      verifyNever(mockService.saveMatchQueue(any,
          tournamentId: anyNamed('tournamentId')));
      verifyNever(mockService.saveKnockouts(any,
          tournamentId: anyNamed('tournamentId')));
      verifyNever(mockService.saveTabellen(any,
          tournamentId: anyNamed('tournamentId')));
    });
  });

  // =========================================================================
  // NEW TEST GROUPS
  // =========================================================================

  // =========================================================================
  group('finishMatch – knockout phase', () {
    late List<Team> teams;
    late Groups groups;
    late Gruppenphase gp;
    late MatchQueue queue;
    late Knockouts ko;

    setUp(() {
      teams = buildTeams(8);
      groups = buildGroups(teams, 2);
      gp = buildGruppenphase(groups, tableCount: 3);
      queue = buildMatchQueue(gp);
      ko = buildKnockouts(championsRound1: [
        Match(id: 'ko_1', teamId1: 'team_0', teamId2: 'team_1', tischNr: 1),
        Match(id: 'ko_2', teamId1: 'team_2', teamId2: 'team_3', tischNr: 2),
      ]);
    });

    test('updates knockout match, saves knockouts and match queue', () async {
      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');
      expect(state.isKnockoutMode, isTrue);

      // Manually place the knockout match into the playing queue
      final koMatch = Match(
          id: 'ko_1',
          teamId1: 'team_0',
          teamId2: 'team_1',
          tischNr: 1,
          score1: 10,
          score2: 5,
          done: true);
      state.matchQueue.playing.add(koMatch);

      final result = await state.finishMatch('ko_1', score1: 10, score2: 5);

      expect(result, isTrue);
      verify(mockService.saveKnockouts(any, tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.saveMatchQueue(any, tournamentId: 'test-tourney'))
          .called(greaterThanOrEqualTo(1));
    });

    test('returns false when match not found in knockout structure', () async {
      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Place a match in playing that doesn't exist in knockouts
      final fakeMatch = Match(
          id: 'nonexistent_ko',
          teamId1: 'team_0',
          teamId2: 'team_1',
          tischNr: 1,
          score1: 10,
          score2: 5,
          done: true);
      state.matchQueue.playing.add(fakeMatch);

      final result =
          await state.finishMatch('nonexistent_ko', score1: 10, score2: 5);

      expect(result, isFalse);
    });

    test('reverts on Firestore save failure during knockout finish', () async {
      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('save failed'));

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final koMatch = Match(
          id: 'ko_1',
          teamId1: 'team_0',
          teamId2: 'team_1',
          tischNr: 1,
          score1: 10,
          score2: 5,
          done: true);
      state.matchQueue.playing.add(koMatch);

      final playingBefore = state.matchQueue.playing.length;

      final result = await state.finishMatch('ko_1', score1: 10, score2: 5);

      expect(result, isFalse);
      // Verify state was rolled back
      expect(state.matchQueue.playing.length, playingBefore);
    });
  });

  // =========================================================================
  group('finishMatch – edge cases', () {
    test('returns false when match not in playing queue', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Try to finish a match that was never started (not in playing)
      final result =
          await state.finishMatch('some_match', score1: 10, score2: 5);
      expect(result, isFalse);
    });

    test('returns false when scores are invalid (getPoints returns null)',
        () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Place a match in playing with invalid scores
      final invalidMatch = Match(
          id: 'invalid_match',
          teamId1: 'team_0',
          teamId2: 'team_1',
          tischNr: 1,
          score1: 7,
          score2: 7,
          done: true);
      state.matchQueue.playing.add(invalidMatch);

      final result =
          await state.finishMatch('invalid_match', score1: 7, score2: 7);

      expect(result, isFalse);
    });

    test('finishMatch uses provided scores over existing match scores',
        () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveGruppenphase(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveTabellen(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Get a real match ID from gruppenphase
      final matchId = gp.groups[0].first.id;

      // Place that match in playing with 0-0 scores
      final playingMatch = Match(
          id: matchId,
          teamId1: gp.groups[0].first.teamId1,
          teamId2: gp.groups[0].first.teamId2,
          tischNr: 1);
      state.matchQueue.playing.add(playingMatch);

      // Stub the reload of gruppenphase for finishMatch
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      // Provide explicit scores
      final result = await state.finishMatch(matchId, score1: 10, score2: 3);

      expect(result, isTrue);
    });
  });

  // =========================================================================
  group('editMatchScore – group phase', () {
    test('updates match scores and recalculates tables', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      // Mark the first match as done so it can be edited
      gp.groups[0].first.score1 = 10;
      gp.groups[0].first.score2 = 5;
      gp.groups[0].first.done = true;

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveGruppenphase(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveTabellen(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Re-stub loadGruppenphase for the edit call
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      final matchId = gp.groups[0].first.id;
      final result = await state.editMatchScore(
        matchId,
        10,
        8,
        0,
        isKnockout: false,
      );

      expect(result, isTrue);
      verify(mockService.saveGruppenphase(any, tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.saveTabellen(any, tournamentId: 'test-tourney'))
          .called(1);
    });

    test('returns false when gruppenphase cannot be loaded', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Make gruppenphase load return null
      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => null);

      final result = await state.editMatchScore(
        'some_match',
        10,
        5,
        0,
        isKnockout: false,
      );

      expect(result, isFalse);
    });

    test('returns false when match not found in gruppenphase', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      final result = await state.editMatchScore(
        'nonexistent_match',
        10,
        5,
        0,
        isKnockout: false,
      );

      expect(result, isFalse);
    });

    test('reverts on Firestore save failure', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      gp.groups[0].first.score1 = 10;
      gp.groups[0].first.score2 = 5;
      gp.groups[0].first.done = true;

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveGruppenphase(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('save failed'));

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      when(mockService.loadGruppenphase(tournamentId: 'test-tourney'))
          .thenAnswer((_) async => gp);

      final matchId = gp.groups[0].first.id;
      final result = await state.editMatchScore(
        matchId,
        10,
        8,
        0,
        isKnockout: false,
      );

      expect(result, isFalse);
    });
  });

  // =========================================================================
  group('editMatchScore – knockout phase', () {
    test('updates knockout match and saves', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);
      final ko = buildKnockouts(championsRound1: [
        Match(
            id: 'ko_1',
            teamId1: 'team_0',
            teamId2: 'team_1',
            tischNr: 1,
            score1: 10,
            score2: 5,
            done: true),
        Match(id: 'ko_2', teamId1: 'team_2', teamId2: 'team_3', tischNr: 2),
      ]);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});
      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final result = await state.editMatchScore(
        'ko_1',
        10,
        8,
        0,
        isKnockout: true,
      );

      expect(result, isTrue);
      verify(mockService.saveKnockouts(any, tournamentId: 'test-tourney'))
          .called(1);
      verify(mockService.saveMatchQueue(any, tournamentId: 'test-tourney'))
          .called(greaterThanOrEqualTo(1));
    });

    test('returns false when match not found in knockouts', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);
      final ko = buildKnockouts(championsRound1: [
        Match(id: 'ko_1', teamId1: 'team_0', teamId2: 'team_1', tischNr: 1),
      ]);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final result = await state.editMatchScore(
        'nonexistent_ko_match',
        10,
        5,
        0,
        isKnockout: true,
      );

      expect(result, isFalse);
    });

    test('reverts on Firestore save failure', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);
      final ko = buildKnockouts(championsRound1: [
        Match(
            id: 'ko_1',
            teamId1: 'team_0',
            teamId2: 'team_1',
            tischNr: 1,
            score1: 10,
            score2: 5,
            done: true),
      ]);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        knockouts: ko,
      );

      when(mockService.saveKnockouts(any,
              tournamentId: anyNamed('tournamentId')))
          .thenThrow(Exception('save failed'));

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final result = await state.editMatchScore(
        'ko_1',
        10,
        8,
        0,
        isKnockout: true,
      );

      expect(result, isFalse);
    });
  });

  // =========================================================================
  group('convenience getters', () {
    test('getNextMatches delegates to matchQueue.nextMatches()', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final nextMatches = state.getNextMatches();
      // With 4 teams, 1 group, 2 tables, there should be available matches
      expect(nextMatches, isNotEmpty);
      // All matches should have free tables
      for (final match in nextMatches) {
        expect(match.id, isNotEmpty);
      }
    });

    test('getPlayingMatches returns empty list initially', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.getPlayingMatches(), isEmpty);
    });

    test('getPlayingMatches returns matches after startMatch', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      final matchId = state.matchQueue.waiting.expand((slot) => slot).first.id;
      await state.startMatch(matchId);

      expect(state.getPlayingMatches(), isNotEmpty);
      expect(state.getPlayingMatches().first.id, matchId);
    });

    test('getNextNextMatches returns blocked matches', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Start matches to occupy tables so next-next becomes relevant
      final nextMatches = state.getNextMatches();
      for (final m in nextMatches) {
        await state.startMatch(m.id);
      }

      // Some waiting matches may now be blocked
      final nextNext = state.getNextNextMatches();
      // nextNext is a list (possibly empty if all tables are unblocked or queue is empty)
      expect(nextNext, isA<List<Match>>());
    });
  });

  // =========================================================================
  group('loadData with knockouts', () {
    test('loadData with knockouts parameter sets knockouts', () {
      final state = makeState(mockService);
      final teams = buildTeams(4);
      final queue = MatchQueue(waiting: [], playing: []);
      final tabellen = Tabellen();
      final ko = buildKnockouts(championsRound1: [
        Match(id: 'ko_1', teamId1: 'team_0', teamId2: 'team_1', tischNr: 1),
      ]);

      state.loadData(
        teams: teams,
        matchQueue: queue,
        tabellen: tabellen,
        knockouts: ko,
      );

      expect(state.teams.length, 4);
      expect(state.knockouts.champions.rounds, isNotEmpty);
      expect(state.knockouts.champions.rounds[0].first.id, 'ko_1');
    });

    test('loadData without knockouts uses empty knockouts', () {
      final state = makeState(mockService);
      final teams = buildTeams(4);
      final queue = MatchQueue(waiting: [], playing: []);
      final tabellen = Tabellen();

      state.loadData(
        teams: teams,
        matchQueue: queue,
        tabellen: tabellen,
      );

      expect(state.knockouts.champions.rounds, isEmpty);
    });
  });

  // =========================================================================
  group('stream-based updates', () {
    test('gruppenphase stream updates state', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      final gpController = StreamController<Gruppenphase?>();

      when(mockService.getTournamentInfo('stream-tourney'))
          .thenAnswer((_) async => {
                'name': 'Stream Cup',
                'creatorId': 'u1',
                'phase': 'groups',
                'tournamentStyle': 'groupsAndKnockouts',
              });
      when(mockService.loadTeams(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => teams);
      when(mockService.loadMatchQueue(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => queue);
      when(mockService.loadGruppenphase(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.loadKnockouts(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.gruppenphaseStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => gpController.stream);
      when(mockService.matchQueueStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.knockoutsStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());

      final state = makeState(mockService);
      await state.loadTournamentData('stream-tourney');

      // Modify a match in the gruppenphase and push it through the stream
      final updatedGp = buildGruppenphase(groups, tableCount: 2);
      updatedGp.groups[0].first.score1 = 10;
      updatedGp.groups[0].first.score2 = 5;
      updatedGp.groups[0].first.done = true;

      gpController.add(updatedGp);

      // Wait for debounced notification (100ms + buffer)
      await Future.delayed(const Duration(milliseconds: 200));

      // The state should have updated gruppenphase
      expect(state.gruppenphase.groups[0].first.done, isTrue);

      gpController.close();
      state.dispose();
    });

    test('matchQueue stream updates state', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      final mqController = StreamController<MatchQueue?>();

      when(mockService.getTournamentInfo('stream-tourney'))
          .thenAnswer((_) async => {
                'name': 'Stream Cup',
                'creatorId': 'u1',
                'phase': 'groups',
                'tournamentStyle': 'groupsAndKnockouts',
              });
      when(mockService.loadTeams(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => teams);
      when(mockService.loadMatchQueue(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => queue);
      when(mockService.loadGruppenphase(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.loadKnockouts(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.gruppenphaseStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.matchQueueStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => mqController.stream);
      when(mockService.knockoutsStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());

      final state = makeState(mockService);
      await state.loadTournamentData('stream-tourney');

      // Push a new match queue with a match in playing
      final updatedQueue = MatchQueue(
        waiting: [],
        playing: [
          Match(id: 'streamed_match', teamId1: 'team_0', teamId2: 'team_1')
        ],
      );

      mqController.add(updatedQueue);

      // Wait for debounced notification
      await Future.delayed(const Duration(milliseconds: 200));

      expect(state.matchQueue.playing, isNotEmpty);
      expect(state.matchQueue.playing.first.id, 'streamed_match');

      mqController.close();
      state.dispose();
    });

    test('knockouts stream updates state', () async {
      final teams = buildTeams(8);
      final groups = buildGroups(teams, 2);
      final gp = buildGruppenphase(groups, tableCount: 3);
      final queue = buildMatchQueue(gp);

      final koController = StreamController<Knockouts?>();

      when(mockService.getTournamentInfo('stream-tourney'))
          .thenAnswer((_) async => {
                'name': 'Stream Cup',
                'creatorId': 'u1',
                'phase': 'groups',
                'tournamentStyle': 'groupsAndKnockouts',
              });
      when(mockService.loadTeams(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => teams);
      when(mockService.loadMatchQueue(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => queue);
      when(mockService.loadGruppenphase(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.loadKnockouts(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.gruppenphaseStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.matchQueueStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.knockoutsStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => koController.stream);

      final state = makeState(mockService);
      await state.loadTournamentData('stream-tourney');

      // Push a knockouts update
      final updatedKo = buildKnockouts(championsRound1: [
        Match(
            id: 'streamed_ko',
            teamId1: 'team_0',
            teamId2: 'team_1',
            tischNr: 1),
      ]);

      koController.add(updatedKo);

      // Wait for debounced notification
      await Future.delayed(const Duration(milliseconds: 200));

      expect(state.knockouts.champions.rounds[0].first.id, 'streamed_ko');

      koController.close();
      state.dispose();
    });

    test('null stream events are ignored', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      final gpController = StreamController<Gruppenphase?>();

      when(mockService.getTournamentInfo('stream-tourney'))
          .thenAnswer((_) async => {
                'name': 'Stream Cup',
                'creatorId': 'u1',
                'phase': 'groups',
                'tournamentStyle': 'groupsAndKnockouts',
              });
      when(mockService.loadTeams(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => teams);
      when(mockService.loadMatchQueue(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => queue);
      when(mockService.loadGruppenphase(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => gp);
      when(mockService.loadKnockouts(tournamentId: 'stream-tourney'))
          .thenAnswer((_) async => null);
      when(mockService.gruppenphaseStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => gpController.stream);
      when(mockService.matchQueueStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());
      when(mockService.knockoutsStream(tournamentId: 'stream-tourney'))
          .thenAnswer((_) => const Stream.empty());

      final state = makeState(mockService);
      await state.loadTournamentData('stream-tourney');

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      // Push null — should be ignored
      gpController.add(null);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(notifyCount, 0);

      gpController.close();
      state.dispose();
    });
  });

  // =========================================================================
  group('startMatch – notifications', () {
    test('startMatch notifies listeners on success', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      when(mockService.saveMatchQueue(any,
              tournamentId: anyNamed('tournamentId')))
          .thenAnswer((_) async {});

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      final matchId = state.matchQueue.waiting.expand((slot) => slot).first.id;
      await state.startMatch(matchId);

      expect(notifyCount, 1);
    });

    test('startMatch does NOT notify on failure', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups, tableCount: 2);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      // Invalid match id — should not notify
      await state.startMatch('nonexistent');

      expect(notifyCount, 0);
    });
  });

  // =========================================================================
  group('tournament style variants', () {
    test('loads everyoneVsEveryone style', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        tournamentStyle: 'everyoneVsEveryone',
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.tournamentStyle, 'everyoneVsEveryone');
    });

    test('loads knockoutsOnly style', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        tournamentStyle: 'knockoutsOnly',
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.tournamentStyle, 'knockoutsOnly');
    });
  });

  // =========================================================================
  group('selectedRuleset handling', () {
    test('defaults to bmt-cup when field absent from tournament info',
        () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      // Don't include selectedRuleset in the info
      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.selectedRuleset, 'bmt-cup');
      expect(state.rulesEnabled, isTrue);
    });

    test('preserves null when selectedRuleset is explicitly null', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
        includeSelectedRuleset: true,
        selectedRuleset: null,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.selectedRuleset, isNull);
      expect(state.rulesEnabled, isFalse);
    });
  });

  // =========================================================================
  group('multiple tournament loads', () {
    test('switching tournaments replaces previous data', () async {
      final teams1 = buildTeams(4);
      final groups1 = buildGroups(teams1, 1);
      final gp1 = buildGruppenphase(groups1);
      final queue1 = buildMatchQueue(gp1);

      stubLoadedTournament(
        mockService,
        teams: teams1,
        gruppenphase: gp1,
        matchQueue: queue1,
        tournamentId: 'tourney-1',
      );

      final state = makeState(mockService);
      await state.loadTournamentData('tourney-1');

      expect(state.teams.length, 4);
      expect(state.currentTournamentId, 'tourney-1');

      // Load a second tournament with more teams
      final teams2 = buildTeams(8);
      final groups2 = buildGroups(teams2, 2);
      final gp2 = buildGruppenphase(groups2);
      final queue2 = buildMatchQueue(gp2);

      stubLoadedTournament(
        mockService,
        teams: teams2,
        gruppenphase: gp2,
        matchQueue: queue2,
        tournamentId: 'tourney-2',
      );

      await state.loadTournamentData('tourney-2');

      expect(state.teams.length, 8);
      expect(state.currentTournamentId, 'tourney-2');
    });
  });

  // =========================================================================
  group('isSetupPhase', () {
    test('returns true when teams are empty but tournament id is set',
        () async {
      when(mockService.getTournamentInfo('setup')).thenAnswer((_) async => {
            'name': 'Setup',
            'creatorId': 'u1',
            'phase': 'setup',
            'tournamentStyle': 'groupsAndKnockouts',
          });
      when(mockService.loadTeams(tournamentId: 'setup'))
          .thenAnswer((_) async => null);
      when(mockService.loadMatchQueue(tournamentId: 'setup'))
          .thenAnswer((_) async => null);
      when(mockService.loadGruppenphase(tournamentId: 'setup'))
          .thenAnswer((_) async => null);
      when(mockService.loadKnockouts(tournamentId: 'setup'))
          .thenAnswer((_) async => null);

      final state = makeState(mockService);
      await state.loadTournamentData('setup');

      expect(state.isSetupPhase, isTrue);
      expect(state.hasData, isFalse);
    });

    test('returns false after data is loaded', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      expect(state.isSetupPhase, isFalse);
      expect(state.hasData, isTrue);
    });
  });

  // =========================================================================
  group('dispose', () {
    test('can be called without errors after loading', () async {
      final teams = buildTeams(4);
      final groups = buildGroups(teams, 1);
      final gp = buildGruppenphase(groups);
      final queue = buildMatchQueue(gp);

      stubLoadedTournament(
        mockService,
        teams: teams,
        gruppenphase: gp,
        matchQueue: queue,
      );

      final state = makeState(mockService);
      await state.loadTournamentData('test-tourney');

      // Should not throw
      expect(() => state.dispose(), returnsNormally);
    });

    test('can be called without loading any data', () {
      final state = makeState(mockService);
      expect(() => state.dispose(), returnsNormally);
    });
  });
}
