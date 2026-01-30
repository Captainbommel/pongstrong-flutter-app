import 'package:cloud_firestore/cloud_firestore.dart';

/// Base class for Firestore services with shared configuration
///
/// Collection Structure:
/// - tournaments/{tournamentId}/teams - Flat list of all teams with IDs
/// - tournaments/{tournamentId}/groups - Team ID groupings by group
/// - tournaments/{tournamentId}/gruppenphase - Group phase matches
/// - tournaments/{tournamentId}/tabellen - Standings/tables
/// - tournaments/{tournamentId}/knockouts - Knockout phase data
/// - tournaments/{tournamentId}/matchQueue - Queue of matches
mixin FirestoreBase {
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // Default tournament ID (can be modified to support multiple tournaments)
  static const String defaultTournamentId = 'current';

  // Collection name
  static const String tournamentsCollection = 'tournaments';

  /// Gets a document reference within a tournament
  DocumentReference getDoc(String tournamentId, String docName) {
    return firestore
        .collection(tournamentsCollection)
        .doc(tournamentId)
        .collection(docName)
        .doc('data');
  }
}
