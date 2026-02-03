import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'firestore_base.dart';

/// Service for managing group phase data in Firestore
mixin GruppenphaseService on FirestoreBase {
  /// Saves group phase data to Firestore
  Future<void> saveGruppenphase(
    Gruppenphase gruppenphase, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Convert nested array to map to avoid Firestore nested array limitation
    final groupsMap = <String, dynamic>{};
    for (int i = 0; i < gruppenphase.groups.length; i++) {
      groupsMap['group$i'] =
          gruppenphase.groups[i].map((m) => m.toJson()).toList();
    }

    final data = {
      'groups': groupsMap,
      'numberOfGroups': gruppenphase.groups.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'gruppenphase').set(data);
  }

  /// Loads group phase data from Firestore
  /// Returns empty Gruppenphase if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<Gruppenphase?> loadGruppenphase({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'gruppenphase').get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;

    // Check if this is a placeholder document (setup phase)
    if (data['initialized'] == true &&
        (data['numberOfGroups'] == null || data['numberOfGroups'] == 0)) {
      return Gruppenphase(groups: []);
    }

    final groupsMap = data['groups'] as Map<String, dynamic>?;
    final numberOfGroups = data['numberOfGroups'] as int? ?? 0;

    if (groupsMap == null || numberOfGroups == 0) {
      return Gruppenphase(groups: []);
    }

    final groups = <List<Match>>[];
    for (int i = 0; i < numberOfGroups; i++) {
      final groupMatches = (groupsMap['group$i'] as List)
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();
      groups.add(groupMatches);
    }
    return Gruppenphase(groups: groups);
  }

  /// Stream of group phase updates
  Stream<Gruppenphase?> gruppenphaseStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'gruppenphase').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;

      // Check if this is a placeholder document (setup phase)
      if (data['initialized'] == true &&
          (data['numberOfGroups'] == null || data['numberOfGroups'] == 0)) {
        return Gruppenphase(groups: []);
      }

      final groupsMap = data['groups'] as Map<String, dynamic>?;
      final numberOfGroups = data['numberOfGroups'] as int? ?? 0;

      if (groupsMap == null || numberOfGroups == 0) {
        return Gruppenphase(groups: []);
      }

      final groups = <List<Match>>[];
      for (int i = 0; i < numberOfGroups; i++) {
        final groupMatches = (groupsMap['group$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        groups.add(groupMatches);
      }
      return Gruppenphase(groups: groups);
    });
  }

  /// Updates a specific match in the group phase
  Future<void> updateGruppenphaseMatch(
    String matchId,
    int score1,
    int score2,
    bool done, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;

    // Find and update the match
    for (var group in gruppenphase.groups) {
      for (var match in group) {
        if (match.id == matchId) {
          match.score1 = score1;
          match.score2 = score2;
          match.done = done;
          break;
        }
      }
    }

    await saveGruppenphase(gruppenphase, tournamentId: tournamentId);
  }
}
