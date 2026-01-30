import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'firestore_base.dart';

/// Service for managing team data in Firestore
mixin TeamsService on FirestoreBase {
  /// Saves flat list of all teams to Firestore
  Future<void> saveTeams(
    List<Team> teams, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final data = {
      'teams': teams.map((t) => t.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'teams').set(data);
  }

  /// Loads flat list of all teams from Firestore
  /// Returns empty list if document exists but teams array is empty (setup phase)
  /// Returns null only if document doesn't exist
  Future<List<Team>?> loadTeams({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'teams').get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final teamsData = data['teams'];
    if (teamsData == null || teamsData is! List) return [];

    final teamsList =
        teamsData.map((t) => Team.fromJson(t as Map<String, dynamic>)).toList();
    return teamsList;
  }

  /// Stream of teams updates
  Stream<List<Team>?> teamsStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'teams').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final teamsList = (data['teams'] as List)
          .map((t) => Team.fromJson(t as Map<String, dynamic>))
          .toList();
      return teamsList;
    });
  }
}
