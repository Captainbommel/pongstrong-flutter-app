// Barrel export for FirestoreService
// All service mixins are combined into one class

export 'firestore_base.dart';
export 'teams_service.dart';
export 'groups_service.dart';
export 'gruppenphase_service.dart';
export 'tabellen_service.dart';
export 'knockouts_service.dart';
export 'match_queue_service.dart';
export 'tournament_management_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_base.dart';
import 'teams_service.dart';
import 'groups_service.dart';
import 'gruppenphase_service.dart';
import 'tabellen_service.dart';
import 'knockouts_service.dart';
import 'match_queue_service.dart';
import 'tournament_management_service.dart';

/// Firestore service for managing tournament data
///
/// Collection Structure:
/// - tournaments/{tournamentId}/teams - Flat list of all teams with IDs
/// - tournaments/{tournamentId}/groups - Team ID groupings by group
/// - tournaments/{tournamentId}/gruppenphase - Group phase matches
/// - tournaments/{tournamentId}/tabellen - Standings/tables
/// - tournaments/{tournamentId}/knockouts - Knockout phase data
/// - tournaments/{tournamentId}/matchQueue - Queue of matches
///
/// This class combines all service mixins into a single interface.
/// The default factory returns the singleton that uses [FirebaseFirestore.instance].
/// For tests, use [FirestoreService.forTesting] to inject a [FakeFirebaseFirestore].
class FirestoreService extends Object
    with
        FirestoreBase,
        TeamsService,
        GroupsService,
        GruppenphaseService,
        TabellenService,
        KnockoutsService,
        MatchQueueService,
        TournamentManagementService {
  static final FirestoreService _instance = FirestoreService._internal();

  /// Singleton access – always returns the same instance backed by the real
  /// [FirebaseFirestore.instance].
  factory FirestoreService() => _instance;

  // Backing field; null means "use FirebaseFirestore.instance" (lazy singleton)
  final FirebaseFirestore? _firestoreOverride;

  FirestoreService._internal() : _firestoreOverride = null;
  FirestoreService._withOverride(FirebaseFirestore fs)
      : _firestoreOverride = fs;

  /// Creates a **non-singleton** instance that uses the supplied [firestore]
  /// instead of [FirebaseFirestore.instance].  Use this in unit tests:
  ///
  /// ```dart
  /// final fakeFirestore = FakeFirebaseFirestore();
  /// final service = FirestoreService.forTesting(fakeFirestore);
  /// ```
  factory FirestoreService.forTesting(FirebaseFirestore firestore) {
    return FirestoreService._withOverride(firestore);
  }

  /// Overrides the mixin default so the injected instance is used everywhere.
  @override
  FirebaseFirestore get firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
}
