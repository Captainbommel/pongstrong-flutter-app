import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_base.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// Converts a [KnockoutBracket]'s rounds to a Firestore-safe map structure.
Map<String, dynamic> _bracketToMap(KnockoutBracket bracket) {
  final roundsMap = <String, dynamic>{};
  for (int i = 0; i < bracket.rounds.length; i++) {
    roundsMap['round$i'] = bracket.rounds[i].map((m) => m.toJson()).toList();
  }
  return {
    'rounds': roundsMap,
    'numberOfRounds': bracket.rounds.length,
  };
}

/// Parses rounds from a Firestore map structure into a [KnockoutBracket].
/// Returns an empty bracket if data is missing or invalid.
KnockoutBracket _parseBracket(dynamic raw) {
  if (raw == null || raw is! Map<String, dynamic>) return KnockoutBracket();
  final roundsRaw = raw['rounds'];
  if (roundsRaw == null || roundsRaw is! Map<String, dynamic>) {
    return KnockoutBracket();
  }
  final roundsMap = roundsRaw;
  final numberOfRounds = raw['numberOfRounds'] as int? ?? 0;
  if (numberOfRounds == 0) return KnockoutBracket();

  final rounds = <List<Match>>[];
  for (int i = 0; i < numberOfRounds; i++) {
    final roundMatches = (roundsMap['round$i'] as List)
        .map((m) => Match.fromJson(m as Map<String, dynamic>))
        .toList();
    rounds.add(roundMatches);
  }
  return KnockoutBracket(rounds: rounds);
}

/// Service for managing knockout phase data in Firestore
mixin KnockoutsService on FirestoreBase {
  /// Saves knockout phase data to Firestore
  Future<void> saveKnockouts(
    Knockouts knockouts, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final data = {
      'champions': _bracketToMap(knockouts.champions),
      'europa': _bracketToMap(knockouts.europa),
      'conference': _bracketToMap(knockouts.conference),
      'super': knockouts.superCup.toJson(),
      'bracketNames': knockouts.bracketNames,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'knockouts').set(data);
  }

  /// Loads knockout phase data from Firestore.
  /// Returns empty Knockouts if document exists but has no data (setup phase).
  /// Returns null only if document doesn't exist.
  Future<Knockouts?> loadKnockouts({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'knockouts').get();
    if (!doc.exists) return null;

    final data = doc.data()! as Map<String, dynamic>;

    // Check if this is a placeholder document (setup phase)
    if (data['initialized'] == true) {
      final championsData = data['champions'] as Map<String, dynamic>?;
      if (championsData == null || championsData['numberOfRounds'] == null) {
        return Knockouts();
      }
    }

    try {
      final superMatches = (data['super'] as List)
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();

      final namesRaw = data['bracketNames'] as Map<String, dynamic>?;
      final bracketNames = namesRaw?.map((k, v) => MapEntry(k, v.toString()));

      return Knockouts(
        champions: _parseBracket(data['champions']),
        europa: _parseBracket(data['europa']),
        conference: _parseBracket(data['conference']),
        superCup: Super(matches: superMatches),
        bracketNames: bracketNames,
      );
    } catch (e) {
      Logger.error('Error parsing knockouts',
          tag: 'KnockoutsService', error: e);
      return Knockouts();
    }
  }

  /// Stream of knockout phase updates
  Stream<Knockouts?> knockoutsStream({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) {
    return getDoc(tournamentId, 'knockouts').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()! as Map<String, dynamic>;

      // Check if this is a placeholder document (setup phase)
      if (data['initialized'] == true) {
        final championsData = data['champions'] as Map<String, dynamic>?;
        if (championsData == null || championsData['numberOfRounds'] == null) {
          return Knockouts();
        }
      }

      final champions = _parseBracket(data['champions']);
      if (champions.rounds.isEmpty) return Knockouts();

      final superList = data['super'] as List?;
      final superMatches = superList
              ?.map((m) => Match.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];

      final namesRaw = data['bracketNames'] as Map<String, dynamic>?;
      final bracketNames = namesRaw?.map((k, v) => MapEntry(k, v.toString()));

      return Knockouts(
        champions: champions,
        europa: _parseBracket(data['europa']),
        conference: _parseBracket(data['conference']),
        superCup: Super(matches: superMatches),
        bracketNames: bracketNames,
      );
    });
  }

  /// Updates a specific match in the knockout phase
  Future<void> updateKnockoutMatch(
    String matchId,
    int score1,
    int score2,
    bool done, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final knockouts = await loadKnockouts(tournamentId: tournamentId);
    if (knockouts == null) return;

    final updated = knockouts.updateMatchScore(matchId, score1, score2);
    if (updated) {
      knockouts.update();
      await saveKnockouts(knockouts, tournamentId: tournamentId);
    }
  }
}
