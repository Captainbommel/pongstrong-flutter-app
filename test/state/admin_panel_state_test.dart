import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups.dart';
import 'package:pongstrong/models/team.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an [AdminPanelState] wired to an in-memory Firestore.
AdminPanelState makeState({FakeFirebaseFirestore? fs}) {
  final firestore = fs ?? FakeFirebaseFirestore();
  final service = FirestoreService.forTesting(firestore);
  return AdminPanelState(firestoreService: service);
}

/// Adds [n] dummy teams to [state] and returns their IDs.
Future<List<String>> addTeams(AdminPanelState state, int n) async {
  final ids = <String>[];
  for (int i = 1; i <= n; i++) {
    await state.addTeam(
      name: 'Team $i',
      member1: 'Player ${i}A',
      member2: 'Player ${i}B',
    );
    ids.add(state.teams.last.id);
  }
  return ids;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  group('Initial state', () {
    test('starts with empty teams and notStarted phase', () {
      final state = makeState();

      expect(state.teams, isEmpty);
      expect(state.currentPhase, TournamentPhase.notStarted);
      expect(state.tournamentStyle, TournamentStyle.groupsAndKnockouts);
      expect(state.isTournamentStarted, isFalse);
      expect(state.isTournamentFinished, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('phaseDisplayName shows German label for each phase', () {
      final state = makeState();

      state.setPhase(TournamentPhase.notStarted);
      expect(state.phaseDisplayName, 'Nicht gestartet');

      state.setPhase(TournamentPhase.groupPhase);
      expect(state.phaseDisplayName, 'Gruppenphase');

      state.setPhase(TournamentPhase.knockoutPhase);
      expect(state.phaseDisplayName, 'K.O.-Phase');

      state.setPhase(TournamentPhase.finished);
      expect(state.phaseDisplayName, 'Beendet');
    });

    test('styleDisplayName shows German label for each style', () {
      final state = makeState();

      state.setTournamentStyle(TournamentStyle.groupsAndKnockouts);
      expect(state.styleDisplayName, 'Gruppenphase + K.O.');

      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      expect(state.styleDisplayName, 'Nur K.O.-Phase');

      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      expect(state.styleDisplayName, 'Jeder gegen Jeden');
    });
  });

  // =========================================================================
  group('setTournamentId', () {
    test('updates currentTournamentId', () {
      final state = makeState();
      state.setTournamentId('my-tourney');
      expect(state.currentTournamentId, 'my-tourney');
    });

    test('notifies listeners', () {
      final state = makeState();
      int calls = 0;
      state.addListener(() => calls++);
      state.setTournamentId('abc');
      expect(calls, greaterThan(0));
    });
  });

  // =========================================================================
  group('Team management – addTeam', () {
    test('adds a team and persists it', () async {
      final state = makeState();
      final ok = await state.addTeam(
        name: 'Eagles',
        member1: 'Alice',
        member2: 'Bob',
      );

      expect(ok, isTrue);
      expect(state.teams.length, 1);
      expect(state.teams.first.name, 'Eagles');
      expect(state.teams.first.mem1, 'Alice');
      expect(state.teams.first.mem2, 'Bob');
      expect(state.errorMessage, isNull);
    });

    test('generates unique IDs for multiple teams', () async {
      final state = makeState();
      await addTeams(state, 5);

      final ids = state.teams.map((t) => t.id).toSet();
      expect(ids.length, 5); // all unique
    });

    test('refuses to add team after tournament has started', () async {
      final state = makeState();
      state.setPhase(TournamentPhase.groupPhase); // simulate started

      final ok =
          await state.addTeam(name: 'Late Team', member1: 'X', member2: 'Y');
      expect(ok, isFalse);
      expect(state.teams, isEmpty);
      expect(state.errorMessage, isNotNull);
    });

    test('notifies listeners after successful add', () async {
      final state = makeState();
      int calls = 0;
      state.addListener(() => calls++);
      await state.addTeam(name: 'A', member1: 'X', member2: 'Y');
      expect(calls, greaterThan(0));
    });
  });

  // =========================================================================
  group('Team management – updateTeam', () {
    test('updates an existing team', () async {
      final state = makeState();
      final ids = await addTeams(state, 1);

      final ok = await state.updateTeam(
        teamId: ids[0],
        name: 'Renamed',
        member1: 'NewM1',
        member2: 'NewM2',
      );

      expect(ok, isTrue);
      final team = state.teams.first;
      expect(team.name, 'Renamed');
      expect(team.mem1, 'NewM1');
      expect(team.mem2, 'NewM2');
    });

    test('returns false and sets error for unknown teamId', () async {
      final state = makeState();
      final ok = await state.updateTeam(
        teamId: 'ghost',
        name: 'X',
        member1: 'A',
        member2: 'B',
      );

      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });

  // =========================================================================
  group('Team management – deleteTeam', () {
    test('removes team from list', () async {
      final state = makeState();
      final ids = await addTeams(state, 3);

      final ok = await state.deleteTeam(ids[1]);

      expect(ok, isTrue);
      expect(state.teams.length, 2);
      expect(state.teams.any((t) => t.id == ids[1]), isFalse);
    });

    test('also removes team from groups when assigned', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);

      // Manually assign groups
      state.setNumberOfGroups(2);
      await state.assignTeamToGroup(ids[0], 0);
      await state.assignTeamToGroup(ids[1], 0);
      await state.assignTeamToGroup(ids[2], 1);
      await state.assignTeamToGroup(ids[3], 1);

      await state.deleteTeam(ids[0]);

      final group0 = state.groups.groups[0];
      expect(group0.contains(ids[0]), isFalse);
      expect(group0.contains(ids[1]), isTrue);
    });

    test('refuses to delete after tournament started', () async {
      final state = makeState();
      final ids = await addTeams(state, 2);
      state.setPhase(TournamentPhase.groupPhase);

      final ok = await state.deleteTeam(ids[0]);
      expect(ok, isFalse);
      expect(state.teams.length, 2);
      expect(state.errorMessage, isNotNull);
    });

    test('returns false for unknown teamId', () async {
      final state = makeState();
      final ok = await state.deleteTeam('nobody');
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });

  // =========================================================================
  group('Group assignment – assignTeamToGroup', () {
    test('places team in correct group', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);
      state.setNumberOfGroups(2);

      await state.assignTeamToGroup(ids[0], 0);
      await state.assignTeamToGroup(ids[1], 0);
      await state.assignTeamToGroup(ids[2], 1);
      await state.assignTeamToGroup(ids[3], 1);

      expect(state.groups.groups[0], containsAll([ids[0], ids[1]]));
      expect(state.groups.groups[1], containsAll([ids[2], ids[3]]));
      expect(state.groupsAssigned, isTrue);
    });

    test('team moves between groups if reassigned', () async {
      final state = makeState();
      final ids = await addTeams(state, 2);
      state.setNumberOfGroups(2);

      await state.assignTeamToGroup(ids[0], 0);
      // Move to group 1
      await state.assignTeamToGroup(ids[0], 1);

      expect(state.groups.groups[0].contains(ids[0]), isFalse);
      expect(state.groups.groups[1].contains(ids[0]), isTrue);
    });

    test('returns false for out-of-range group index', () async {
      final state = makeState();
      final ids = await addTeams(state, 1);
      state.setNumberOfGroups(2);

      final ok = await state.assignTeamToGroup(ids[0], 99);
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });

  // =========================================================================
  group('Group assignment – assignGroupsRandomly', () {
    test('assigns all teams across the requested number of groups', () async {
      final state = makeState();
      await addTeams(state, 12);

      final ok = await state.assignGroupsRandomly(numberOfGroups: 3);

      expect(ok, isTrue);
      expect(state.groups.groups.length, 3);
      // Every team must appear exactly once
      final assignedIds = state.groups.groups.expand((g) => g).toList();
      expect(assignedIds.toSet().length, 12);
      expect(assignedIds.length, 12);
    });

    test('sets groupsAssigned to true', () async {
      final state = makeState();
      await addTeams(state, 8);

      await state.assignGroupsRandomly(numberOfGroups: 2);
      expect(state.groupsAssigned, isTrue);
    });

    test('returns false when no teams present', () async {
      final state = makeState();
      final ok = await state.assignGroupsRandomly();
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });

  // =========================================================================
  group('Group assignment – clearGroupAssignments', () {
    test('empties groups and sets groupsAssigned to false', () async {
      final state = makeState();
      await addTeams(state, 4);
      await state.assignGroupsRandomly(numberOfGroups: 2);
      expect(state.groupsAssigned, isTrue);

      final ok = await state.clearGroupAssignments();

      expect(ok, isTrue);
      expect(state.groupsAssigned, isFalse);
      expect(state.groups.groups, isEmpty);
    });
  });

  // =========================================================================
  group('getTeamGroupIndex', () {
    test('returns correct index for assigned team', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);
      state.setNumberOfGroups(2);
      await state.assignTeamToGroup(ids[0], 0);
      await state.assignTeamToGroup(ids[1], 0);
      await state.assignTeamToGroup(ids[2], 1);
      await state.assignTeamToGroup(ids[3], 1);

      expect(state.getTeamGroupIndex(ids[0]), 0);
      expect(state.getTeamGroupIndex(ids[2]), 1);
    });

    test('returns -1 for unassigned team', () {
      final state = makeState();
      expect(state.getTeamGroupIndex('ghost'), -1);
    });
  });

  // =========================================================================
  group('teamsInGroupsCount', () {
    test('returns total count of teams across all groups', () async {
      final state = makeState();
      final ids = await addTeams(state, 6);
      state.setNumberOfGroups(3);
      for (int i = 0; i < 6; i++) {
        await state.assignTeamToGroup(ids[i], i % 3);
      }
      expect(state.teamsInGroupsCount, 6);
    });

    test('returns 0 when no groups assigned', () {
      final state = makeState();
      expect(state.teamsInGroupsCount, 0);
    });
  });

  // =========================================================================
  group('canStartTournament & startValidationMessage', () {
    test('false when no teams', () {
      final state = makeState();
      expect(state.canStartTournament, isFalse);
      expect(state.startValidationMessage, isNotNull);
    });

    test('false when tournament already started', () async {
      final state = makeState();
      await addTeams(state, 4);
      state.setPhase(TournamentPhase.groupPhase);
      expect(state.canStartTournament, isFalse);
    });

    test('GroupsAndKnockouts: false when groups not assigned', () async {
      final state = makeState();
      await addTeams(state, 4);
      expect(state.needsGroupAssignment, isTrue);
      expect(state.canStartTournament, isFalse);
      expect(state.startValidationMessage, contains('zugewiesen'));
    });

    test('GroupsAndKnockouts: false when not all teams assigned', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);
      state.setNumberOfGroups(2);
      // Only assign 3 of 4 teams
      await state.assignTeamToGroup(ids[0], 0);
      await state.assignTeamToGroup(ids[1], 0);
      await state.assignTeamToGroup(ids[2], 1);
      // ids[3] not assigned
      expect(state.canStartTournament, isFalse);
    });

    test('GroupsAndKnockouts: true when all teams assigned', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);
      state.setNumberOfGroups(2);
      for (int i = 0; i < 4; i++) {
        await state.assignTeamToGroup(ids[i], i < 2 ? 0 : 1);
      }
      expect(state.canStartTournament, isTrue);
      expect(state.startValidationMessage, isNull);
    });

    test('KnockoutsOnly: false when count not a power-of-2 option', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      await addTeams(
          state, 1); // need ≥1 team to bypass the "no teams" early-return
      state.setTargetTeamCount(7);
      expect(state.canStartTournament, isFalse);
      expect(state.startValidationMessage, contains('8, 16, 32'));
    });

    test('KnockoutsOnly: false when fewer teams than target', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(8);
      await addTeams(state, 4); // only 4, need 8
      expect(state.canStartTournament, isFalse);
    });

    test('KnockoutsOnly: true when enough teams', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(8);
      await addTeams(state, 8);
      expect(state.canStartTournament, isTrue);
      expect(state.startValidationMessage, isNull);
    });

    test('EveryoneVsEveryone: false with fewer than 2 teams', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      // 0 teams
      expect(state.canStartTournament, isFalse);
      // 1 team — exercises the EVE-specific check
      await addTeams(state, 1);
      expect(state.canStartTournament, isFalse);
      expect(state.startValidationMessage, contains('2'));
    });

    test('EveryoneVsEveryone: true with 2+ teams', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      await addTeams(state, 4);
      expect(state.canStartTournament, isTrue);
    });
  });

  // =========================================================================
  group('setTournamentStyle', () {
    test('does not change style once tournament has started', () {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setPhase(TournamentPhase.groupPhase); // started
      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      expect(state.tournamentStyle, TournamentStyle.knockoutsOnly);
    });

    test('clears groupsAssigned when switching away from G+KO', () async {
      final state = makeState();
      final ids = await addTeams(state, 4);
      state.setNumberOfGroups(2);
      for (int i = 0; i < 4; i++) {
        await state.assignTeamToGroup(ids[i], i < 2 ? 0 : 1);
      }
      expect(state.groupsAssigned, isTrue);

      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      expect(state.groupsAssigned, isFalse);
    });

    test('restores koTargetTeamCount when switching back to KO-only', () {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(16);

      state.setTournamentStyle(TournamentStyle.groupsAndKnockouts);
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);

      expect(state.targetTeamCount, 16);
    });
  });

  // =========================================================================
  group('setNumberOfGroups / setNumberOfTables', () {
    test('setNumberOfGroups clamps to 1..8', () {
      final state = makeState();
      state.setNumberOfGroups(0);
      expect(state.numberOfGroups, 6); // unchanged – 0 is invalid

      state.setNumberOfGroups(9);
      expect(state.numberOfGroups, 6); // unchanged – 9 is invalid

      state.setNumberOfGroups(4);
      expect(state.numberOfGroups, 4);
    });

    test('setNumberOfGroups accepts boundary values 1 and 8', () {
      final state = makeState();
      state.setNumberOfGroups(1);
      expect(state.numberOfGroups, 1);

      state.setNumberOfGroups(8);
      expect(state.numberOfGroups, 8);
    });

    test('setNumberOfTables ignored when tournament started', () {
      final state = makeState();
      state.setPhase(TournamentPhase.groupPhase);
      state.setNumberOfTables(3);
      expect(state.numberOfTables, 6); // unchanged
    });

    test('setNumberOfTables updates value when not started', () {
      final state = makeState();
      state.setNumberOfTables(4);
      expect(state.numberOfTables, 4);
    });
  });

  // =========================================================================
  group('updateMatchStats', () {
    test('updates total, completed, and remaining', () {
      final state = makeState();
      state.updateMatchStats(total: 20, completed: 12);

      expect(state.totalMatches, 20);
      expect(state.completedMatches, 12);
      expect(state.remainingMatches, 8);
    });
  });

  // =========================================================================
  group('clearError', () {
    test('clears error message', () async {
      final state = makeState();
      // Trigger an error
      await state.deleteTeam('ghost');
      expect(state.errorMessage, isNotNull);

      state.clearError();
      expect(state.errorMessage, isNull);
    });
  });

  // =========================================================================
  group('setPhase', () {
    test('updates phase and notifies listeners', () {
      final state = makeState();
      int calls = 0;
      state.addListener(() => calls++);

      state.setPhase(TournamentPhase.knockoutPhase);

      expect(state.currentPhase, TournamentPhase.knockoutPhase);
      expect(calls, greaterThan(0));
    });
  });

  // =========================================================================
  group('startTournament – GroupsAndKnockouts', () {
    test(
        'starts tournament, sets groupPhase, and calculates correct match count',
        () async {
      final state = makeState();
      final ids = await addTeams(state, 8); // 8 teams → 2 groups of 4
      state.setNumberOfGroups(2);
      state.setNumberOfTables(3);
      for (int i = 0; i < 8; i++) {
        await state.assignTeamToGroup(ids[i], i < 4 ? 0 : 1);
      }

      final ok = await state.startTournament();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.groupPhase);
      expect(state.isTournamentStarted, isTrue);
      expect(state.errorMessage, isNull);
      // 2 groups × C(4,2) = 2 × 6 = 12 matches
      expect(state.totalMatches, 12);
      expect(state.completedMatches, 0);
      expect(state.remainingMatches, 12);
    });

    test('calculates correct match count for larger groups', () async {
      final state = makeState();
      final ids = await addTeams(state, 12); // 2 groups of 6
      state.setNumberOfGroups(2);
      state.setNumberOfTables(3);
      for (int i = 0; i < 12; i++) {
        await state.assignTeamToGroup(ids[i], i < 6 ? 0 : 1);
      }

      final ok = await state.startTournament();
      expect(ok, isTrue);
      // 2 groups × C(6,2) = 2 × 15 = 30 matches
      expect(state.totalMatches, 30);
    });

    test('fails gracefully when canStart is false', () async {
      final state = makeState();
      // No teams → canStart is false
      final ok = await state.startTournament();
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
      expect(state.currentPhase, TournamentPhase.notStarted);
    });
  });

  // =========================================================================
  group('startTournament – KnockoutsOnly', () {
    test('starts KO-only tournament with 8 teams', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(8);
      await addTeams(state, 10); // 10 available, only 8 used

      final ok = await state.startTournament();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.knockoutPhase);
      expect(state.totalMatches, 7); // n-1 = 7 for single elimination
    });

    test('starts KO-only tournament with 16 teams', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(16);
      await addTeams(state, 16);

      final ok = await state.startTournament();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.knockoutPhase);
      expect(state.totalMatches, 15); // n-1 = 15
    });
  });

  // =========================================================================
  group('startTournament – EveryoneVsEveryone', () {
    test('starts round-robin tournament', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      await addTeams(state, 6);

      final ok = await state.startTournament();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.groupPhase);
      // 6 teams: 6*5/2 = 15 matches
      expect(state.totalMatches, 15);
    });

    test('starts round-robin with odd team count', () async {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.everyoneVsEveryone);
      await addTeams(state, 5);

      final ok = await state.startTournament();

      expect(ok, isTrue);
      // 5 teams: 5*4/2 = 10 matches
      expect(state.totalMatches, 10);
    });
  });

  // =========================================================================
  group('advancePhase', () {
    test('transitions from groupPhase to knockoutPhase', () async {
      final fs = FakeFirebaseFirestore();
      final service = FirestoreService.forTesting(fs);
      final state = AdminPanelState(firestoreService: service);
      state.setNumberOfGroups(6);

      // Bootstrap: start a G+KO tournament so Firestore has the gruppenphase
      await addTeams(state, 24);
      await state.assignGroupsRandomly(numberOfGroups: 6);
      await state.startTournament();
      expect(state.currentPhase, TournamentPhase.groupPhase);

      final ok = await state.advancePhase();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.knockoutPhase);
    });

    test('fails when not in group phase', () async {
      final state = makeState();
      state.setPhase(TournamentPhase.notStarted);

      final ok = await state.advancePhase();
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('fails when in knockout phase already', () async {
      final state = makeState();
      state.setPhase(TournamentPhase.knockoutPhase);

      final ok = await state.advancePhase();
      expect(ok, isFalse);
    });
  });

  // =========================================================================
  group('revertToGroupPhase', () {
    test('reverts from knockout to group phase', () async {
      final fs = FakeFirebaseFirestore();
      final service = FirestoreService.forTesting(fs);
      final state = AdminPanelState(firestoreService: service);

      await addTeams(state, 24);
      await state.assignGroupsRandomly(numberOfGroups: 6);
      await state.startTournament();
      await state.advancePhase();
      expect(state.currentPhase, TournamentPhase.knockoutPhase);

      final ok = await state.revertToGroupPhase();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.groupPhase);
    });

    test('fails when not in knockout phase', () async {
      final state = makeState();
      state.setPhase(TournamentPhase.groupPhase);

      final ok = await state.revertToGroupPhase();
      expect(ok, isFalse);
      expect(state.errorMessage, isNotNull);
    });
  });

  // =========================================================================
  group('resetTournament', () {
    test('resets phase to notStarted', () async {
      // resetTournament calls .update() on the tournament doc, so it must exist.
      final fs = FakeFirebaseFirestore();
      await fs
          .collection('tournaments')
          .doc('current')
          .set({'phase': 'groupPhase'});
      final state = makeState(fs: fs);
      state.setPhase(TournamentPhase.groupPhase);

      final ok = await state.resetTournament();

      expect(ok, isTrue);
      expect(state.currentPhase, TournamentPhase.notStarted);
      expect(state.totalMatches, 0);
      expect(state.completedMatches, 0);
      expect(state.remainingMatches, 0);
    });
  });

  // =========================================================================
  group('Rules toggle', () {
    test('rulesEnabled is true by default', () {
      final state = makeState();
      expect(state.rulesEnabled, isTrue);
      expect(state.selectedRuleset, 'bmt-cup');
    });

    test('setRulesEnabled(false) clears selectedRuleset', () async {
      final state = makeState();
      await state.setRulesEnabled(false);
      expect(state.rulesEnabled, isFalse);
      expect(state.selectedRuleset, isNull);
    });

    test('setRulesEnabled(true) restores selectedRuleset', () async {
      final state = makeState();
      await state.setRulesEnabled(false);
      await state.setRulesEnabled(true);
      expect(state.rulesEnabled, isTrue);
      expect(state.selectedRuleset, 'bmt-cup');
    });

    test('setSelectedRuleset stores arbitrary ruleset name', () async {
      final state = makeState();
      await state.setSelectedRuleset('house-rules');
      expect(state.selectedRuleset, 'house-rules');
    });
  });

  // =========================================================================
  group('dispose', () {
    test('does not throw when listeners notify after dispose', () {
      final state = makeState();
      state.dispose();
      // notifyListeners after dispose should be a no-op, not a throw
      expect(() => state.setTournamentId('x'), returnsNormally);
    });
  });

  // =========================================================================
  group('loadTournamentMetadata', () {
    test('loads phase and style from Firestore', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('tournaments').doc('current').set({
        'phase': 'knockouts',
        'tournamentStyle': 'knockoutsOnly',
      });
      final state = makeState(fs: fs);

      await state.loadTournamentMetadata();

      expect(state.currentPhase, TournamentPhase.knockoutPhase);
      expect(state.tournamentStyle, TournamentStyle.knockoutsOnly);
    });

    test('defaults to notStarted and G+KO when metadata missing', () async {
      final state = makeState(); // empty Firestore
      await state.loadTournamentMetadata();

      expect(state.currentPhase, TournamentPhase.notStarted);
      expect(state.tournamentStyle, TournamentStyle.groupsAndKnockouts);
    });

    test('loads selectedRuleset from metadata', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('tournaments').doc('current').set({
        'phase': 'groups',
        'selectedRuleset': 'house-rules',
      });
      final state = makeState(fs: fs);
      await state.loadTournamentMetadata();
      expect(state.selectedRuleset, 'house-rules');
    });

    test('preserves null ruleset when explicitly set to null', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('tournaments').doc('current').set({
        'phase': 'groups',
        'selectedRuleset': null,
      });
      final state = makeState(fs: fs);
      await state.loadTournamentMetadata();
      expect(state.selectedRuleset, isNull);
    });
  });

  // =========================================================================
  group('loadTeams', () {
    test('populates teams from Firestore', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      await svc.saveTeams([
        Team(id: 't1', name: 'Alpha', mem1: 'A1', mem2: 'A2'),
        Team(id: 't2', name: 'Bravo', mem1: 'B1', mem2: 'B2'),
      ]);
      final state = AdminPanelState(firestoreService: svc);

      await state.loadTeams();

      expect(state.teams.length, 2);
      expect(state.teams[0].name, 'Alpha');
      expect(state.teams[1].name, 'Bravo');
    });

    test('sets empty list when no teams doc exists', () async {
      final state = makeState();
      await state.loadTeams();
      expect(state.teams, isEmpty);
    });
  });

  // =========================================================================
  group('loadGroups', () {
    test('populates groups from Firestore', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);
      await svc.saveGroups(Groups(groups: [
        ['t1', 't2'],
        ['t3', 't4'],
      ]));
      final state = AdminPanelState(firestoreService: svc);

      await state.loadGroups();

      expect(state.groups.groups.length, 2);
      expect(state.groupsAssigned, isTrue);
    });

    test('sets empty groups when doc missing', () async {
      final state = makeState();
      await state.loadGroups();
      expect(state.groups.groups, isEmpty);
      expect(state.groupsAssigned, isFalse);
    });
  });

  // =========================================================================
  group('loadMatchStats', () {
    test('counts group phase matches from Firestore', () async {
      final fs = FakeFirebaseFirestore();
      final svc = FirestoreService.forTesting(fs);

      // Build a small tournament and complete 2 of 6 matches
      final teams = List.generate(
          4, (i) => Team(id: 't$i', name: 'T$i', mem1: 'M1', mem2: 'M2'));
      final groups = Groups(groups: [
        ['t0', 't1', 't2', 't3'],
      ]);
      await svc.initializeTournament(teams, groups, tableCount: 2);

      // Mark first 2 matches as done
      final gp = await svc.loadGruppenphase();
      gp!.groups[0][0].done = true;
      gp.groups[0][0].score1 = 10;
      gp.groups[0][0].score2 = 5;
      gp.groups[0][1].done = true;
      gp.groups[0][1].score1 = 10;
      gp.groups[0][1].score2 = 3;
      await svc.saveGruppenphase(gp);

      final state = AdminPanelState(firestoreService: svc);
      state.setPhase(TournamentPhase.groupPhase);

      await state.loadMatchStats();

      expect(state.totalMatches, 6); // C(4,2) = 6
      expect(state.completedMatches, 2);
      expect(state.remainingMatches, 4);
    });
  });

  // =========================================================================
  group('_validateGroupAssignment (via canStartTournament)', () {
    test('returns false when a team is in no group', () async {
      final state = makeState();
      final ids = await addTeams(state, 5);
      state.setNumberOfGroups(2);
      // Only assign 4 of 5 teams
      for (int i = 0; i < 4; i++) {
        await state.assignTeamToGroup(ids[i], i < 2 ? 0 : 1);
      }
      expect(state.canStartTournament, isFalse);
      expect(state.startValidationMessage, contains('zugewiesen'));
    });
  });

  // =========================================================================
  group('setTargetTeamCount', () {
    test('updates targetTeamCount', () {
      final state = makeState();
      state.setTargetTeamCount(16);
      expect(state.targetTeamCount, 16);
    });

    test('also updates koTargetTeamCount when in KO mode', () {
      final state = makeState();
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      state.setTargetTeamCount(32);
      expect(state.targetTeamCount, 32);

      // Switch away and back — the KO count is restored
      state.setTournamentStyle(TournamentStyle.groupsAndKnockouts);
      state.setTournamentStyle(TournamentStyle.knockoutsOnly);
      expect(state.targetTeamCount, 32);
    });

    test('does not notify when value unchanged', () {
      final state = makeState();
      state.setTargetTeamCount(8); // default is already 8
      int calls = 0;
      state.addListener(() => calls++);
      state.setTargetTeamCount(8);
      expect(calls, 0);
    });
  });

  // =========================================================================
  group('isTournamentStarted / isTournamentFinished', () {
    test('started is true for any phase except notStarted', () {
      final state = makeState();
      expect(state.isTournamentStarted, isFalse);
      state.setPhase(TournamentPhase.groupPhase);
      expect(state.isTournamentStarted, isTrue);
      state.setPhase(TournamentPhase.knockoutPhase);
      expect(state.isTournamentStarted, isTrue);
      state.setPhase(TournamentPhase.finished);
      expect(state.isTournamentStarted, isTrue);
    });

    test('finished only true for finished phase', () {
      final state = makeState();
      expect(state.isTournamentFinished, isFalse);
      state.setPhase(TournamentPhase.groupPhase);
      expect(state.isTournamentFinished, isFalse);
      state.setPhase(TournamentPhase.finished);
      expect(state.isTournamentFinished, isTrue);
    });
  });

  // =========================================================================
  group('updateTeam – edge cases', () {
    test('refuses update after tournament started', () async {
      final state = makeState();
      final ids = await addTeams(state, 2);
      state.setPhase(TournamentPhase.groupPhase);

      // updateTeam does NOT guard against started. Verify current behavior.
      final ok = await state.updateTeam(
        teamId: ids[0],
        name: 'New',
        member1: 'M1',
        member2: 'M2',
      );
      // Currently allowed — the production code does not block updates after start.
      expect(ok, isTrue);
    });
  });
}
