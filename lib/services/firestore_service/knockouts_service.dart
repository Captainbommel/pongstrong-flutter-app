import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'firestore_base.dart';

/// Service for managing knockout phase data in Firestore
mixin KnockoutsService on FirestoreBase {
  /// Saves knockout phase data to Firestore
  Future<void> saveKnockouts(
    Knockouts knockouts, {
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    // Convert Champions nested arrays to map
    final championsMap = <String, dynamic>{};
    for (int i = 0; i < knockouts.champions.rounds.length; i++) {
      championsMap['round$i'] =
          knockouts.champions.rounds[i].map((m) => m.toJson()).toList();
    }

    // Convert Europa nested arrays to map
    final europaMap = <String, dynamic>{};
    for (int i = 0; i < knockouts.europa.rounds.length; i++) {
      europaMap['round$i'] =
          knockouts.europa.rounds[i].map((m) => m.toJson()).toList();
    }

    // Convert Conference nested arrays to map
    final conferenceMap = <String, dynamic>{};
    for (int i = 0; i < knockouts.conference.rounds.length; i++) {
      conferenceMap['round$i'] =
          knockouts.conference.rounds[i].map((m) => m.toJson()).toList();
    }

    final data = {
      'champions': {
        'rounds': championsMap,
        'numberOfRounds': knockouts.champions.rounds.length,
      },
      'europa': {
        'rounds': europaMap,
        'numberOfRounds': knockouts.europa.rounds.length,
      },
      'conference': {
        'rounds': conferenceMap,
        'numberOfRounds': knockouts.conference.rounds.length,
      },
      'super': knockouts.superCup.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await getDoc(tournamentId, 'knockouts').set(data);
  }

  /// Loads knockout phase data from Firestore
  /// Returns empty Knockouts if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<Knockouts?> loadKnockouts({
    String tournamentId = FirestoreBase.defaultTournamentId,
  }) async {
    final doc = await getDoc(tournamentId, 'knockouts').get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;

    // Check if this is a placeholder document (setup phase)
    if (data['initialized'] == true) {
      final championsData = data['champions'] as Map<String, dynamic>?;
      if (championsData == null || championsData['numberOfRounds'] == null) {
        return Knockouts();
      }
    }

    try {
      // Reconstruct Champions rounds from map
      final championsData = data['champions'] as Map<String, dynamic>;
      final championsRoundsMap =
          championsData['rounds'] as Map<String, dynamic>;
      final championsNumberOfRounds = championsData['numberOfRounds'] as int;
      final championsRounds = <List<Match>>[];
      for (int i = 0; i < championsNumberOfRounds; i++) {
        final roundMatches = (championsRoundsMap['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        championsRounds.add(roundMatches);
      }

      // Reconstruct Europa rounds from map
      final europaData = data['europa'] as Map<String, dynamic>;
      final europaRoundsMap = europaData['rounds'] as Map<String, dynamic>;
      final europaNumberOfRounds = europaData['numberOfRounds'] as int;
      final europaRounds = <List<Match>>[];
      for (int i = 0; i < europaNumberOfRounds; i++) {
        final roundMatches = (europaRoundsMap['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        europaRounds.add(roundMatches);
      }

      // Reconstruct Conference rounds from map
      final conferenceData = data['conference'] as Map<String, dynamic>;
      final conferenceRoundsMap =
          conferenceData['rounds'] as Map<String, dynamic>;
      final conferenceNumberOfRounds = conferenceData['numberOfRounds'] as int;
      final conferenceRounds = <List<Match>>[];
      for (int i = 0; i < conferenceNumberOfRounds; i++) {
        final roundMatches = (conferenceRoundsMap['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        conferenceRounds.add(roundMatches);
      }

      // Reconstruct Super
      final superMatches = (data['super'] as List)
          .map((m) => Match.fromJson(m as Map<String, dynamic>))
          .toList();

      return Knockouts(
        champions: Champions(rounds: championsRounds),
        europa: Europa(rounds: europaRounds),
        conference: Conference(rounds: conferenceRounds),
        superCup: Super(matches: superMatches),
      );
    } catch (e) {
      // If parsing fails, return empty knockouts
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
      final data = doc.data() as Map<String, dynamic>;

      // Check if this is a placeholder document (setup phase)
      if (data['initialized'] == true && data['champions'] is! Map) {
        return Knockouts();
      }

      // Safely check if champions data exists and is valid
      final championsData = data['champions'];
      if (championsData == null || championsData is! Map<String, dynamic>) {
        return Knockouts();
      }

      final championsRoundsMap =
          championsData['rounds'] as Map<String, dynamic>?;
      final championsNumberOfRounds =
          championsData['numberOfRounds'] as int? ?? 0;
      if (championsRoundsMap == null || championsNumberOfRounds == 0) {
        return Knockouts();
      }

      final championsRounds = <List<Match>>[];
      for (int i = 0; i < championsNumberOfRounds; i++) {
        final roundMatches = (championsRoundsMap['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        championsRounds.add(roundMatches);
      }

      // Reconstruct Europa rounds from map
      final europaRaw = data['europa'];
      final europaData = europaRaw is Map<String, dynamic> ? europaRaw : null;
      final europaRoundsMap = europaData?['rounds'] as Map<String, dynamic>?;
      final europaNumberOfRounds = europaData?['numberOfRounds'] as int? ?? 0;
      final europaRounds = <List<Match>>[];
      for (int i = 0; i < europaNumberOfRounds; i++) {
        final roundMatches = (europaRoundsMap!['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        europaRounds.add(roundMatches);
      }

      // Reconstruct Conference rounds from map
      final conferenceRaw = data['conference'];
      final conferenceData =
          conferenceRaw is Map<String, dynamic> ? conferenceRaw : null;
      final conferenceRoundsMap =
          conferenceData?['rounds'] as Map<String, dynamic>?;
      final conferenceNumberOfRounds =
          conferenceData?['numberOfRounds'] as int? ?? 0;
      final conferenceRounds = <List<Match>>[];
      for (int i = 0; i < conferenceNumberOfRounds; i++) {
        final roundMatches = (conferenceRoundsMap!['round$i'] as List)
            .map((m) => Match.fromJson(m as Map<String, dynamic>))
            .toList();
        conferenceRounds.add(roundMatches);
      }

      // Reconstruct Super
      final superList = data['super'] as List?;
      final superMatches = superList
              ?.map((m) => Match.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];

      return Knockouts(
        champions: Champions(rounds: championsRounds),
        europa: Europa(rounds: europaRounds),
        conference: Conference(rounds: conferenceRounds),
        superCup: Super(matches: superMatches),
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

    // Determine which league based on matchId prefix
    bool matchFound = false;

    if (matchId.startsWith('c')) {
      // Champions league
      for (var round in knockouts.champions.rounds) {
        for (var match in round) {
          if (match.id == matchId) {
            match.score1 = score1;
            match.score2 = score2;
            match.done = done;
            matchFound = true;
            break;
          }
        }
        if (matchFound) break;
      }
    } else if (matchId.startsWith('e')) {
      // Europa league
      for (var round in knockouts.europa.rounds) {
        for (var match in round) {
          if (match.id == matchId) {
            match.score1 = score1;
            match.score2 = score2;
            match.done = done;
            matchFound = true;
            break;
          }
        }
        if (matchFound) break;
      }
    } else if (matchId.startsWith('f')) {
      // Conference league
      for (var round in knockouts.conference.rounds) {
        for (var match in round) {
          if (match.id == matchId) {
            match.score1 = score1;
            match.score2 = score2;
            match.done = done;
            matchFound = true;
            break;
          }
        }
        if (matchFound) break;
      }
    } else if (matchId.startsWith('s')) {
      // Super cup
      for (var match in knockouts.superCup.matches) {
        if (match.id == matchId) {
          match.score1 = score1;
          match.score2 = score2;
          match.done = done;
          matchFound = true;
          break;
        }
      }
    }

    if (matchFound) {
      // Update knockout state and save
      knockouts.update();
      await saveKnockouts(knockouts, tournamentId: tournamentId);
    }
  }
}
