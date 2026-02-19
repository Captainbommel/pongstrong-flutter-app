import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';

/// Service for managing group data in Firestore
mixin GroupsService on FirestoreBase {
  /// Saves groups (team ID groupings) to Firestore
  Future<void> saveGroups(
    Groups groups, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Convert nested array to map to avoid Firestore nested array limitation
    final groupsMap = <String, dynamic>{};
    for (int i = 0; i < groups.groups.length; i++) {
      groupsMap['group$i'] = groups.groups[i];
    }

    final data = {
      'groups': groupsMap,
      'numberOfGroups': groups.groups.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'groups').set(data);
  }

  /// Loads groups from Firestore
  Future<Groups?> loadGroups({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'groups').get();
    if (!doc.exists) return null;

    final data = doc.data()! as Map<String, dynamic>;
    final groupsRaw = data['groups'];
    if (groupsRaw == null || groupsRaw is! Map<String, dynamic>) {
      return Groups();
    }
    final numberOfGroups = data['numberOfGroups'] as int? ?? 0;
    if (numberOfGroups == 0) return Groups();

    final groupsList = <List<String>>[];
    for (int i = 0; i < numberOfGroups; i++) {
      final group =
          (groupsRaw['group$i'] as List).map((id) => id.toString()).toList();
      groupsList.add(group);
    }
    return Groups(groups: groupsList);
  }

  /// Stream of groups updates
  Stream<Groups?> groupsStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'groups').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()! as Map<String, dynamic>;
      final groupsRaw = data['groups'];
      if (groupsRaw == null || groupsRaw is! Map<String, dynamic>) {
        return Groups();
      }
      final numberOfGroups = data['numberOfGroups'] as int? ?? 0;
      if (numberOfGroups == 0) return Groups();

      final groupsList = <List<String>>[];
      for (int i = 0; i < numberOfGroups; i++) {
        final group =
            (groupsRaw['group$i'] as List).map((id) => id.toString()).toList();
        groupsList.add(group);
      }
      return Groups(groups: groupsList);
    });
  }
}
