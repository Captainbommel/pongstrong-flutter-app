import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';
import 'package:pongstrong/services/firestore_service/groups_service.dart';
import 'package:pongstrong/services/firestore_service/gruppenphase_service.dart';
import 'package:pongstrong/services/firestore_service/knockouts_service.dart';
import 'package:pongstrong/services/firestore_service/match_queue_service.dart';
import 'package:pongstrong/services/firestore_service/tabellen_service.dart';
import 'package:pongstrong/services/firestore_service/teams_service.dart';

/// Service for tournament initialization, phase transitions, and lifecycle management.
mixin TournamentManagementService
    on
        FirestoreBase,
        TeamsService,
        GroupsService,
        GruppenphaseService,
        TabellenService,
        KnockoutsService,
        MatchQueueService {
  // ==================== TOURNAMENT INITIALIZATION ====================

  /// Initializes a new tournament from teams, groups, and tables
  /// This creates all necessary data structures
  Future<void> initializeTournament(
    List<Team> teams,
    Groups groups, {
    String tournamentId = FirestoreBase.defaultTournamentId,
    int tableCount = 6,
  }) async {
    // Save flat list of teams
    await saveTeams(teams, tournamentId: tournamentId);

    // Save groups (team ID groupings)
    await saveGroups(groups, tournamentId: tournamentId);

    // Create and save group phase matches
    final gruppenphase = Gruppenphase.create(groups, tableCount: tableCount);
    await saveGruppenphase(gruppenphase, tournamentId: tournamentId);

    // Create and save match queue
    final queue = MatchQueue.create(gruppenphase);
    await saveMatchQueue(queue, tournamentId: tournamentId);

    // Create and save initial standings
    final tabellen = evalGruppen(gruppenphase);
    await saveTabellen(tabellen, tournamentId: tournamentId);

    // Create and save knockout structure (empty initially)
    final knockouts = Knockouts();
    knockouts.instantiate();
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Update tournament metadata (use set+merge to preserve creatorId, password etc.)
    await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .set({
      'phase': 'groups',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Imports teams and groups only WITHOUT starting the tournament
  /// Use this for JSON import where tournament should remain in 'notStarted' state
  Future<void> importTeamsAndGroups(
    List<Team> teams,
    Groups groups, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Save flat list of teams
    await saveTeams(teams, tournamentId: tournamentId);

    // Save groups (team ID groupings)
    await saveGroups(groups, tournamentId: tournamentId);

    // Update tournament metadata - keep phase as 'notStarted'
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'notStarted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Document might not exist yet
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'notStarted',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Imports teams only (without groups) for round-robin / KO-only modes
  Future<void> importTeamsOnly(
    List<Team> teams, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    await saveTeams(teams, tournamentId: tournamentId);

    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'notStarted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'notStarted',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Updates the tournament style in Firebase metadata
  Future<void> updateTournamentStyle({
    String tournamentId = FirestoreBase.defaultTournamentId,
    required String style,
  }) async {
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'tournamentStyle': style,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'tournamentStyle': style,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Initializes a KO-only tournament (single elimination bracket)
  /// Teams must be a power of 2 (8, 16, 32, 64)
  Future<void> initializeKOOnlyTournament(
    List<Team> teams, {
    String tournamentId = FirestoreBase.defaultTournamentId,
    int tableCount = 6,
  }) async {
    // Save teams
    await saveTeams(teams, tournamentId: tournamentId);

    // Build single-elimination bracket
    final numTeams = teams.length;
    final numRounds = _log2(numTeams);

    // Create knockout rounds
    final rounds = <List<Match>>[];
    // First round has numTeams/2 matches
    final firstRound = <Match>[];
    for (int i = 0; i < numTeams ~/ 2; i++) {
      firstRound.add(Match(
        teamId1: teams[i * 2].id,
        teamId2: teams[i * 2 + 1].id,
        id: 'ko_r1_${i + 1}',
        tableNumber: (i % tableCount) + 1,
      ));
    }
    rounds.add(firstRound);

    // Subsequent rounds are empty until teams advance
    int matchesInRound = numTeams ~/ 4;
    for (int r = 2; r <= numRounds; r++) {
      final round = <Match>[];
      for (int i = 0; i < matchesInRound; i++) {
        round.add(Match(
          id: 'ko_r${r}_${i + 1}',
          tableNumber: (i % tableCount) + 1,
        ));
      }
      rounds.add(round);
      matchesInRound ~/= 2;
    }

    // Store as a simplified Knockouts structure using only champions bracket
    final knockouts = Knockouts(
      champions: Champions(rounds: rounds),
    );
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Create match queue with first-round matches
    final queue = MatchQueue(
      waiting: List.generate(tableCount, (_) => <Match>[]),
      playing: [],
    );
    for (final match in firstRound) {
      queue.waiting[match.tableNumber - 1].add(match);
    }
    await saveMatchQueue(queue, tournamentId: tournamentId);

    // Save empty gruppenphase (not used in KO-only)
    await saveGruppenphase(Gruppenphase(), tournamentId: tournamentId);

    // Save empty groups
    await saveGroups(Groups(), tournamentId: tournamentId);

    // Update metadata
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'knockouts',
        'tournamentStyle': 'knockoutsOnly',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'knockouts',
        'tournamentStyle': 'knockoutsOnly',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Initializes a round-robin tournament (everyone vs everyone)
  Future<void> initializeRoundRobinTournament(
    List<Team> teams, {
    String tournamentId = FirestoreBase.defaultTournamentId,
    int tableCount = 6,
  }) async {
    // Save teams
    await saveTeams(teams, tournamentId: tournamentId);

    // ── Circle-method round-robin scheduling ──
    // Produces (N-1) rounds where every team plays exactly once per round.
    // This ensures fair distribution: no team plays twice before all others
    // have played once.
    final n = teams.length;
    final isOdd = n % 2 != 0;
    final effectiveN = isOdd ? n + 1 : n; // virtual BYE slot if odd
    final numRounds = effectiveN - 1;
    final halfN = effectiveN ~/ 2;

    // Rotating index array – position 0 stays fixed, rest rotate each round
    final idx = List.generate(effectiveN, (i) => i);

    final matches = <Match>[];
    int matchId = 1;
    int tableSlot = 0; // cycles through 6 tables

    for (int round = 0; round < numRounds; round++) {
      for (int i = 0; i < halfN; i++) {
        final home = idx[i];
        final away = idx[effectiveN - 1 - i];

        // Skip BYE matches (virtual slot == effectiveN - 1 when odd)
        if (isOdd && (home >= n || away >= n)) continue;

        matches.add(Match(
          teamId1: teams[home].id,
          teamId2: teams[away].id,
          id: 'rr_$matchId',
          tableNumber: (tableSlot % tableCount) + 1,
        ));
        matchId++;
        tableSlot++;
      }

      // Rotate: keep idx[0] fixed, shift idx[1..end] by one position
      final last = idx.removeLast();
      idx.insert(1, last);
    }

    // Store matches as a single-group Gruppenphase (reuse existing structure)
    final gruppenphase = Gruppenphase(groups: [matches]);
    await saveGruppenphase(gruppenphase, tournamentId: tournamentId);

    // Build match queue – each table's queue receives matches in generation
    // order, so matches from the same round land on different tables and can
    // be started concurrently.
    final queue = MatchQueue(
      waiting: List.generate(tableCount, (_) => <Match>[]),
      playing: [],
    );
    for (final match in matches) {
      queue.waiting[match.tableNumber - 1].add(match);
    }
    await saveMatchQueue(queue, tournamentId: tournamentId);

    // Save empty groups (not used in round-robin)
    await saveGroups(Groups(), tournamentId: tournamentId);

    // Save empty knockouts
    final knockouts = Knockouts();
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Initial standings
    final tabellen = evalGruppen(gruppenphase);
    await saveTabellen(tabellen, tournamentId: tournamentId);

    // Update metadata
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'groups',
        'tournamentStyle': 'everyoneVsEveryone',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'groups',
        'tournamentStyle': 'everyoneVsEveryone',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Helper: integer log2
  int _log2(int n) {
    var value = n;
    int result = 0;
    while (value > 1) {
      value ~/= 2;
      result++;
    }
    return result;
  }

  /// Transitions tournament from group phase to knockout phase
  Future<void> transitionToKnockouts({
    String tournamentId = FirestoreBase.defaultTournamentId,
    required int numberOfGroups,
    int tableCount = 6,
    bool splitTables = false,
  }) async {
    // Load gruppenphase and calculate standings
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;
    final tabellen = evalGruppen(gruppenphase);

    // Evaluate and create knockouts
    final knockouts = evaluateGroups(tabellen,
        tableCount: tableCount, splitTables: splitTables);

    // Save knockouts
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Update tournament phase
    await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .update({
      'phase': 'knockouts',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create a fresh match queue with one waiting slot per table
    // instead of reusing the group-phase queue which may have fewer slots
    final queue = MatchQueue(
      waiting: List.generate(tableCount, (_) => <Match>[]),
      playing: [],
    );
    queue.updateKnockQueue(knockouts);
    await saveMatchQueue(queue, tournamentId: tournamentId);
  }

  /// Reverts tournament from knockout phase back to group phase.
  /// Clears knockout trees and rebuilds the match queue with unfinished group matches.
  Future<void> revertToGroupPhase({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Load current gruppenphase (still in Firestore from group phase)
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;

    // Derive table count from existing matches
    int maxTable = 6;
    for (final group in gruppenphase.groups) {
      for (final match in group) {
        if (match.tableNumber > maxTable) maxTable = match.tableNumber;
      }
    }

    // Rebuild match queue with only unfinished group matches
    final queue = MatchQueue(
      waiting: List.generate(maxTable, (_) => <Match>[]),
      playing: [],
    );
    for (final group in gruppenphase.groups) {
      for (final match in group) {
        if (!match.done) {
          queue.waiting[match.tableNumber - 1].add(match);
        }
      }
    }

    // Save empty knockouts (clears the trees)
    final knockouts = Knockouts();
    knockouts.instantiate();
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Save rebuilt match queue
    await saveMatchQueue(queue, tournamentId: tournamentId);

    // Update tournament phase back to groups
    await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .update({
      'phase': 'groups',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Re-evaluates group standings based on current match results
  Future<void> updateStandings({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;

    final tabellen = evalGruppen(gruppenphase);
    await saveTabellen(tabellen, tournamentId: tournamentId);
  }

  // ==================== TOURNAMENT MANAGEMENT ====================

  /// Gets tournament metadata (phase, timestamps, etc.)
  Future<Map<String, dynamic>?> getTournamentMetadata({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .get();
    if (!doc.exists) return null;
    return doc.data()!;
  }

  /// Stream of tournament metadata
  Stream<Map<String, dynamic>?> tournamentMetadataStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  /// Deletes all tournament data
  Future<void> deleteTournament({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final batch = firestore.batch();

    // Delete all sub-collections
    batch.delete(getDoc(tournamentId, 'teams'));
    batch.delete(getDoc(tournamentId, 'groups'));
    batch.delete(getDoc(tournamentId, 'gruppenphase'));
    batch.delete(getDoc(tournamentId, 'tabellen'));
    batch.delete(getDoc(tournamentId, 'knockouts'));
    batch.delete(getDoc(tournamentId, 'matchQueue'));

    // Delete tournament document
    batch.delete(firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId));

    await batch.commit();
  }

  /// Resets tournament to notStarted state (keeps teams and groups, deletes everything else)
  Future<void> resetTournament({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Delete gruppenphase
    await getDoc(tournamentId, 'gruppenphase').delete();

    // Delete match queue
    await getDoc(tournamentId, 'matchQueue').delete();

    // Delete knockouts
    await getDoc(tournamentId, 'knockouts').delete();

    // Delete tabellen
    await getDoc(tournamentId, 'tabellen').delete();

    // Reset tournament phase to notStarted
    await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .update({
      'phase': 'notStarted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
