import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'firestore_base.dart';

/// Service for managing match queue data in Firestore
mixin MatchQueueService on FirestoreBase {
  /// Saves match queue to Firestore
  Future<void> saveMatchQueue(
    MatchQueue queue, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Convert nested array to map to avoid Firestore nested array limitation
    final waitingMap = <String, dynamic>{};
    for (int i = 0; i < queue.waiting.length; i++) {
      waitingMap['group$i'] = queue.waiting[i].map((m) => m.toJson()).toList();
    }

    final data = {
      'waiting': waitingMap,
      'numberOfQueues': queue.waiting.length,
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

    final data = doc.data() as Map<String, dynamic>;

    // Check if this is a placeholder document (setup phase)
    if (data['initialized'] == true &&
        (data['numberOfQueues'] == null || data['numberOfQueues'] == 0)) {
      return MatchQueue();
    }

    final waitingMap = data['waiting'] as Map<String, dynamic>?;
    final numberOfQueues = data['numberOfQueues'] as int? ?? 0;
    final playingList = data['playing'] as List? ?? [];

    if (waitingMap == null || numberOfQueues == 0) {
      return MatchQueue();
    }

    final waiting = <List<Match>>[];
    for (int i = 0; i < numberOfQueues; i++) {
      final queueMatches = (waitingMap['group$i'] as List)
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();
      waiting.add(queueMatches);
    }

    final playing = playingList
        .map((m) => Match.fromJson(m as Map<String, dynamic>))
        .toList();

    return MatchQueue(waiting: waiting, playing: playing);
  }

  /// Stream of match queue updates
  Stream<MatchQueue?> matchQueueStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'matchQueue').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;

      // Check if this is a placeholder document (setup phase)
      if (data['initialized'] == true &&
          (data['numberOfQueues'] == null || data['numberOfQueues'] == 0)) {
        return MatchQueue();
      }

      final waitingMap = data['waiting'] as Map<String, dynamic>?;
      final numberOfQueues = data['numberOfQueues'] as int? ?? 0;
      final playingList = data['playing'] as List? ?? [];

      if (waitingMap == null || numberOfQueues == 0) {
        return MatchQueue();
      }

      final waiting = <List<Match>>[];
      for (int i = 0; i < numberOfQueues; i++) {
        final queueMatches = (waitingMap['group$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        waiting.add(queueMatches);
      }

      final playing = playingList
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();

      return MatchQueue(waiting: waiting, playing: playing);
    });
  }
}
