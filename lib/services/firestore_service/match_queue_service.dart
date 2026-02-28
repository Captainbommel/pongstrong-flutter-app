import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';

/// Service for managing match queue data in Firestore
mixin MatchQueueService on FirestoreBase {
  /// Saves match queue to Firestore
  Future<void> saveMatchQueue(
    MatchQueue queue, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final data = {
      'queue': queue.queue.map((e) => e.toJson()).toList(),
      'playing': queue.playing.map((m) => m.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'matchQueue').set(data);
  }

  /// Loads match queue from Firestore
  /// Returns empty MatchQueue if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<MatchQueue?> loadMatchQueue({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'matchQueue').get();
    if (!doc.exists) return null;

    final data = doc.data()! as Map<String, dynamic>;

    // Check if this is a placeholder document (setup phase)
    if (data['initialized'] == true &&
        (data['queue'] == null || (data['queue'] as List?)?.isEmpty == true)) {
      return MatchQueue();
    }

    final queueList = data['queue'] as List? ?? [];
    final playingList = data['playing'] as List? ?? [];

    if (queueList.isEmpty && playingList.isEmpty) {
      return MatchQueue();
    }

    final queueEntries = queueList
        .map((e) => MatchQueueEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final playing = playingList
        .map((m) => Match.fromJson(m as Map<String, dynamic>))
        .toList();

    return MatchQueue(queue: queueEntries, playing: playing);
  }

  /// Stream of match queue updates
  Stream<MatchQueue?> matchQueueStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'matchQueue').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()! as Map<String, dynamic>;

      // Check if this is a placeholder document (setup phase)
      if (data['initialized'] == true &&
          (data['queue'] == null ||
              (data['queue'] as List?)?.isEmpty == true)) {
        return MatchQueue();
      }

      final queueList = data['queue'] as List? ?? [];
      final playingList = data['playing'] as List? ?? [];

      if (queueList.isEmpty && playingList.isEmpty) {
        return MatchQueue();
      }

      final queueEntries = queueList
          .map((e) => MatchQueueEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      final playing = playingList
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();

      return MatchQueue(queue: queueEntries, playing: playing);
    });
  }
}
