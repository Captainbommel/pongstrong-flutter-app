import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/tournament_enums.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/join_code.dart';
import 'package:pongstrong/utils/password_hash.dart';

/// Firestore operations for tournament creation, authentication,
/// and participant management.
mixin TournamentAuthService on FirestoreBase {
  // ==================== TOURNAMENT CREATION ====================

  /// Creates a new empty tournament with just the name and creator info.
  ///
  /// Returns the tournament ID if successful, `null` if a tournament with
  /// the same name already exists.
  Future<String?> createTournament({
    required String tournamentName,
    required String creatorId,
    required String password,
  }) async {
    try {
      final tournamentId =
          tournamentName.trim().replaceAll(RegExp(r'\s+'), '-');

      if (await tournamentExists(tournamentId: tournamentId)) {
        return null;
      }

      // Generate a unique 4-char join code
      final joinCode = await _generateUniqueJoinCode();
      if (joinCode == null) {
        Logger.error('Could not create tournament: join code generation failed',
            tag: 'TournamentService');
        return null;
      }

      await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'name': tournamentName,
        'creatorId': creatorId,
        'password': PasswordHash.hash(password),
        'joinCode': joinCode,
        'participants': [creatorId],
        'phase': 'setup',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create empty placeholder documents for all collections
      final batch = firestore.batch();

      batch.set(getDoc(tournamentId, 'teams'), {
        'teams': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(getDoc(tournamentId, 'groups'), {
        'groups': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(getDoc(tournamentId, 'matchQueue'), {
        'queue': [],
        'currentIndex': 0,
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(getDoc(tournamentId, 'gruppenphase'), {
        'gruppen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(getDoc(tournamentId, 'tabellen'), {
        'tabellen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(getDoc(tournamentId, 'knockouts'), {
        BracketKey.gold.name: {'rounds': []},
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

  // ==================== AUTHENTICATION ====================

  //TODO: Use cloud function to handle this server-side for better security
  /// Verifies if the [password] is correct for a tournament.
  Future<bool> verifyTournamentPassword(
      String tournamentId, String password) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final storedHash = data['password'] as String?;
      if (storedHash == null) return false;

      return PasswordHash.verify(password, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Checks if a user is the creator of a tournament.
  Future<bool> isCreator(String tournamentId, String userId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['creatorId'] == userId;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a tournament has a password set.
  Future<bool> tournamentHasPassword(String tournamentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data.containsKey('password') &&
          data['password'] != null &&
          data['password'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ==================== QUERIES ====================

  /// Lists all tournament IDs.
  Future<List<String>> listTournaments() async {
    final snapshot =
        await firestore.collection(FirestoreBase.tournamentsCollection).get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets tournaments created by a specific [creatorId].
  Future<List<String>> listUserTournaments(String creatorId) async {
    final snapshot = await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .where('creatorId', isEqualTo: creatorId)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Checks if a tournament exists.
  Future<bool> tournamentExists({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await firestore
        .collection(FirestoreBase.tournamentsCollection)
        .doc(tournamentId)
        .get();
    return doc.exists;
  }

  /// Gets tournament info (name, creatorId, phase, style, joinCode, etc.).
  ///
  /// Returns `null` if the tournament does not exist. The password
  /// field is excluded from the returned map.
  Future<Map<String, dynamic>?> getTournamentInfo(String tournamentId) async {
    try {
      final doc = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final result = {
        'name': data['name'] ?? tournamentId,
        'creatorId': data['creatorId'],
        'phase': data['phase'] ?? 'groups',
        'tournamentStyle': data['tournamentStyle'] ?? 'groupsAndKnockouts',
        'createdAt': data['createdAt'],
        if (data.containsKey('joinCode')) 'joinCode': data['joinCode'],
      };

      if (data.containsKey('selectedRuleset')) {
        result['selectedRuleset'] = data['selectedRuleset'];
      }

      return result;
    } catch (e) {
      return null;
    }
  }

  // ==================== JOIN CODE ====================

  /// Looks up a tournament by its 4-char join code.
  ///
  /// Returns the tournament document ID, or `null` if no tournament
  /// with that code exists.
  Future<String?> findTournamentByCode(String code) async {
    try {
      final normalised = JoinCode.normalise(code);
      if (!JoinCode.isValid(normalised)) return null;

      final snapshot = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .where('joinCode', isEqualTo: normalised)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      Logger.error('Error finding tournament by code',
          tag: 'TournamentService', error: e);
      return null;
    }
  }

  /// Generates a unique join code that doesn't collide with existing ones.
  ///
  /// Returns `null` if no unique code could be generated after [maxAttempts].
  Future<String?> _generateUniqueJoinCode() async {
    const maxAttempts = 25;
    for (var i = 0; i < maxAttempts; i++) {
      final code = JoinCode.generate();
      final existing = await firestore
          .collection(FirestoreBase.tournamentsCollection)
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    Logger.error(
      'Failed to generate a unique join code after $maxAttempts attempts',
      tag: 'TournamentService',
    );
    return null;
  }

  // ==================== PARTICIPANT MANAGEMENT ====================

  /// Adds a user to the tournament's participants list.
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

      final data = doc.data()!;
      if (data['creatorId'] == userId) return true;

      final participants = data['participants'] as List<dynamic>? ?? [];
      return participants.contains(userId);
    } catch (e) {
      return false;
    }
  }
}
