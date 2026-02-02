import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pongstrong/models/models.dart';
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
        'password': password, // In production, this should be hashed
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
      debugPrint('Error creating tournament: $e');
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
      return data['password'] == password;
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
}
