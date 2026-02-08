import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/password_hash.dart';
import 'firestore_base.dart';
import 'teams_service.dart';
import 'groups_service.dart';
import 'gruppenphase_service.dart';
import 'tabellen_service.dart';
import 'knockouts_service.dart';
import 'match_queue_service.dart';

/// Service for tournament initialization, management, and authentication
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

  /// Initializes a new tournament from teams and groups
  /// This creates all necessary data structures
  Future<void> initializeTournament(
    List<Team> teams,
    Groups groups, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Save flat list of teams
    await saveTeams(teams, tournamentId: tournamentId);

    // Save groups (team ID groupings)
    await saveGroups(groups, tournamentId: tournamentId);

    // Create and save group phase matches
    final gruppenphase = Gruppenphase.create(groups);
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

    // Update tournament metadata (use update to preserve creatorId, password etc.)
    // Fall back to set with merge if document doesn't exist
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'groups', // 'groups' or 'knockouts'
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Document might not exist yet (legacy behavior)
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'groups',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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
        tischNr: (i % 6) + 1,
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
          tischNr: (i % 6) + 1,
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
      waiting: List.generate(6, (_) => <Match>[]),
      playing: [],
    );
    for (var match in firstRound) {
      queue.waiting[match.tischNr - 1].add(match);
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
          tischNr: (tableSlot % 6) + 1,
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
      waiting: List.generate(6, (_) => <Match>[]),
      playing: [],
    );
    for (var match in matches) {
      queue.waiting[match.tischNr - 1].add(match);
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
    int result = 0;
    while (n > 1) {
      n ~/= 2;
      result++;
    }
    return result;
  }

  /// Transitions tournament from group phase to knockout phase
  Future<void> transitionToKnockouts({
    String tournamentId = FirestoreBase.defaultTournamentId,
    required int numberOfGroups,
  }) async {
    // Load gruppenphase and calculate standings
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;
    final tabellen = evalGruppen(gruppenphase);

    // Evaluate and create knockouts
    final knockouts = numberOfGroups == 8
        ? evaluateGroups8(tabellen)
        : evaluateGroups6(tabellen);

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

    // Update match queue for knockouts - clear old group matches first
    final queue = await loadMatchQueue(tournamentId: tournamentId);
    if (queue != null) {
      queue.clearQueue(); // Clear remaining group phase matches
      queue.updateKnockQueue(knockouts);
      await saveMatchQueue(queue, tournamentId: tournamentId);
    }
  }

  /// Reverts tournament from knockout phase back to group phase.
  /// Clears knockout trees and rebuilds the match queue with unfinished group matches.
  Future<void> revertToGroupPhase({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Load current gruppenphase (still in Firestore from group phase)
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;

    // Rebuild match queue with only unfinished group matches
    final queue = MatchQueue(
      waiting: List.generate(6, (_) => <Match>[]),
      playing: [],
    );
    for (var group in gruppenphase.groups) {
      for (var match in group) {
        if (!match.done) {
          queue.waiting[match.tischNr - 1].add(match);
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
    return doc.data() as Map<String, dynamic>;
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
      return doc.data() as Map<String, dynamic>;
    });
  }

  /// Deletes all tournament data
  Future<void> deleteTournament({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final batch = firestore.batch();

    // Delete all sub-collections
    batch.delete(getDoc(tournamentId, 'teams'));
    batch.delete(getDoc(tournamentId, 'gruppen'));
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

  // ==================== UTILITY METHODS ====================

  /// Lists all tournaments
  Future<List<String>> listTournaments() async {
    final snapshot =
        await firestore.collection(FirestoreBase.tournamentsCollection).get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets tournaments created by a specific user
  Future<List<String>> listUserTournaments(String creatorId) async {
    final snapshot = await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .where('creatorId', isEqualTo: creatorId)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Checks if a tournament exists
  Future<bool> tournamentExists({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .get();
    return doc.exists;
  }

  /// Creates a new empty tournament with just the name and creator info
  /// Returns the tournament ID if successful, null otherwise
  /// Also creates empty placeholder documents for all collections so they're ready for data
  Future<String?> createTournament({
    required String tournamentName,
    required String creatorId,
    required String creatorEmail,
    required String password,
  }) async {
    try {
      // Use the tournament name as the ID (sanitized)
      final tournamentId =
          tournamentName.trim().replaceAll(RegExp(r'\s+'), '-');

      // Check if tournament already exists
      if (await tournamentExists(tournamentId: tournamentId)) {
        return null; // Tournament with this name already exists
      }

      // Create tournament document with metadata
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'name': tournamentName,
        'creatorId': creatorId,
        'creatorEmail': creatorEmail,
        'password': PasswordHash.hash(password), // Hashed for security
        'participants': [creatorId], // Creator is automatically a participant
        'phase': 'setup', // 'setup', 'groups' or 'knockouts'
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create empty placeholder documents for all collections
      // This ensures the collections exist and are ready for data
      final batch = firestore.batch();

      // Teams placeholder
      batch.set(getDoc(tournamentId, 'teams'), {
        'teams': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Groups placeholder
      batch.set(getDoc(tournamentId, 'gruppen'), {
        'groups': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Match queue placeholder
      batch.set(getDoc(tournamentId, 'matchQueue'), {
        'queue': [],
        'currentIndex': 0,
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gruppenphase placeholder
      batch.set(getDoc(tournamentId, 'gruppenphase'), {
        'gruppen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Tabellen placeholder
      batch.set(getDoc(tournamentId, 'tabellen'), {
        'tabellen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Knockouts placeholder
      batch.set(getDoc(tournamentId, 'knockouts'), {
        'champions': {'rounds': []},
        'losers': {'rounds': []},
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return tournamentId;
    } catch (e) {
      Logger.error('Error creating tournament',
          tag: 'TournamentService', error: e);
      return null;
    }
  }

  /// Verifies if the password is correct for a tournament
  Future<bool> verifyTournamentPassword(
      String tournamentId, String password) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final storedHash = data['password'] as String?;
      if (storedHash == null) return false;

      return PasswordHash.verify(password, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Checks if a user is the creator of a tournament
  Future<bool> isCreator(String tournamentId, String userId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['creatorId'] == userId;
    } catch (e) {
      return false;
    }
  }

  /// Gets tournament info (name, creatorEmail, etc.)
  Future<Map<String, dynamic>?> getTournamentInfo(String tournamentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      // Don't return the password - return available fields
      return {
        'name': data['name'] ?? tournamentId,
        'creatorId': data['creatorId'],
        'creatorEmail': data['creatorEmail'],
        'phase': data['phase'] ?? 'groups',
        'tournamentStyle': data['tournamentStyle'] ?? 'groupsAndKnockouts',
        'selectedRuleset': data['selectedRuleset'] as String? ?? 'bmt-cup',
        'createdAt': data['createdAt'],
      };
    } catch (e) {
      return null;
    }
  }

  /// Checks if a tournament has a password set
  Future<bool> tournamentHasPassword(String tournamentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data.containsKey('password') &&
          data['password'] != null &&
          data['password'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== PARTICIPANT MANAGEMENT ====================

  /// Adds a user to the tournament's participants list.
  /// Called after password verification or when creator creates the tournament.
  Future<bool> joinTournament(String tournamentId, String userId) async {
    try {
      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .update({
        'participants': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('Error joining tournament',
          tag: 'TournamentService', error: e);
      return false;
    }
  }

  /// Checks if a user is a participant of (or creator of) a tournament.
  Future<bool> isParticipant(String tournamentId, String userId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;

      // Creator is always considered a participant
      if (data['creatorId'] == userId) return true;

      final participants = data['participants'] as List<dynamic>? ?? [];
      return participants.contains(userId);
    } catch (e) {
      return false;
    }
  }
}
