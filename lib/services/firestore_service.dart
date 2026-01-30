import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pongstrong/models/models.dart';

/// Firestore service for managing tournament data
///
/// Collection Structure:
/// - tournaments/{tournamentId}/teams - Flat list of all teams with IDs
/// - tournaments/{tournamentId}/groups - Team ID groupings by group
/// - tournaments/{tournamentId}/gruppenphase - Group phase matches
/// - tournaments/{tournamentId}/tabellen - Standings/tables
/// - tournaments/{tournamentId}/knockouts - Knockout phase data
/// - tournaments/{tournamentId}/matchQueue - Queue of matches
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default tournament ID (can be modified to support multiple tournaments)
  static const String defaultTournamentId = 'current';

  // Collection name
  static const String _tournamentsCollection = 'tournaments';

  // ==================== HELPER METHODS ====================

  /// Gets a document reference within a tournament
  DocumentReference _getDoc(String tournamentId, String docName) {
    return _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .collection(docName)
        .doc('data');
  }

  // ==================== TEAMS ====================

  /// Saves flat list of all teams to Firestore
  Future<void> saveTeams(
    List<Team> teams, {
    String tournamentId = defaultTournamentId,
  }) async {
    final data = {
      'teams': teams.map((t) => t.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _getDoc(tournamentId, 'teams').set(data);
  }

  /// Loads flat list of all teams from Firestore
  /// Returns empty list if document exists but teams array is empty (setup phase)
  /// Returns null only if document doesn't exist
  Future<List<Team>?> loadTeams({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'teams').get();
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
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'teams').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final teamsList = (data['teams'] as List)
          .map((t) => Team.fromJson(t as Map<String, dynamic>))
          .toList();
      return teamsList;
    });
  }

  // ==================== GROUPS (Team ID Groupings) ====================

  /// Saves groups (team ID groupings) to Firestore
  Future<void> saveGroups(
    Groups groups, {
    String tournamentId = defaultTournamentId,
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
    await _getDoc(tournamentId, 'groups').set(data);
  }

  /// Loads groups from Firestore
  Future<Groups?> loadGroups({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'groups').get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final groupsMap = data['groups'] as Map<String, dynamic>;
    final numberOfGroups = data['numberOfGroups'] as int;

    final groupsList = <List<String>>[];
    for (int i = 0; i < numberOfGroups; i++) {
      final group =
          (groupsMap['group$i'] as List).map((id) => id.toString()).toList();
      groupsList.add(group);
    }
    return Groups(groups: groupsList);
  }

  /// Stream of groups updates
  Stream<Groups?> groupsStream({
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'groups').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final groupsMap = data['groups'] as Map<String, dynamic>;
      final numberOfGroups = data['numberOfGroups'] as int;

      final groupsList = <List<String>>[];
      for (int i = 0; i < numberOfGroups; i++) {
        final group =
            (groupsMap['group$i'] as List).map((id) => id.toString()).toList();
        groupsList.add(group);
      }
      return Groups(groups: groupsList);
    });
  }

  // ==================== GRUPPENPHASE (GROUP PHASE MATCHES) ====================

  /// Saves group phase data to Firestore
  Future<void> saveGruppenphase(
    Gruppenphase gruppenphase, {
    String tournamentId = defaultTournamentId,
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
    await _getDoc(tournamentId, 'gruppenphase').set(data);
  }

  /// Loads group phase data from Firestore
  /// Returns empty Gruppenphase if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<Gruppenphase?> loadGruppenphase({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'gruppenphase').get();
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
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'gruppenphase').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final groupsMap = data['groups'] as Map<String, dynamic>;
      final numberOfGroups = data['numberOfGroups'] as int;

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
    String tournamentId = defaultTournamentId,
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

  // ==================== TABELLEN (STANDINGS) ====================

  /// Saves standings/tables to Firestore
  Future<void> saveTabellen(
    Tabellen tabellen, {
    String tournamentId = defaultTournamentId,
  }) async {
    // Convert nested array to map to avoid Firestore nested array limitation
    final tablesMap = <String, dynamic>{};
    for (int i = 0; i < tabellen.tables.length; i++) {
      tablesMap['table$i'] =
          tabellen.tables[i].map((row) => row.toJson()).toList();
    }

    final data = {
      'tables': tablesMap,
      'numberOfTables': tabellen.tables.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _getDoc(tournamentId, 'tabellen').set(data);
  }

  /// Loads standings from Firestore.
  /// Note: standings should be generated using evalGruppen,
  /// this is just for the case that no Gruppenphase data is available.
  Future<Tabellen?> loadTabellen({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'tabellen').get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final tablesMap = data['tables'] as Map<String, dynamic>;
    final numberOfTables = data['numberOfTables'] as int;

    final tables = <List<TableRow>>[];
    for (int i = 0; i < numberOfTables; i++) {
      final tableRows = (tablesMap['table$i'] as List)
          .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
          .toList();
      tables.add(tableRows);
    }
    return Tabellen(tables: tables);
  }

  /// Stream of standings/tables updates
  Stream<Tabellen?> tabellenStream({
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'tabellen').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final tablesMap = data['tables'] as Map<String, dynamic>;
      final numberOfTables = data['numberOfTables'] as int;

      final tables = <List<TableRow>>[];
      for (int i = 0; i < numberOfTables; i++) {
        final tableRows = (tablesMap['table$i'] as List)
            .map((row) => TableRow.fromJson(row as Map<String, dynamic>))
            .toList();
        tables.add(tableRows);
      }
      return Tabellen(tables: tables);
    });
  }

  // ==================== KNOCKOUTS ====================

  /// Saves knockout phase data to Firestore
  Future<void> saveKnockouts(
    Knockouts knockouts, {
    String tournamentId = defaultTournamentId,
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
    await _getDoc(tournamentId, 'knockouts').set(data);
  }

  /// Loads knockout phase data from Firestore
  /// Returns empty Knockouts if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<Knockouts?> loadKnockouts({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'knockouts').get();
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
      debugPrint('Error parsing knockouts: $e');
      return Knockouts();
    }
  }

  /// Stream of knockout phase updates
  Stream<Knockouts?> knockoutsStream({
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'knockouts').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;

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
    });
  }

  /// Updates a specific match in the knockout phase
  Future<void> updateKnockoutMatch(
    String matchId,
    int score1,
    int score2,
    bool done, {
    String tournamentId = defaultTournamentId,
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

  // ==================== MATCH QUEUE ====================

  /// Saves match queue to Firestore
  Future<void> saveMatchQueue(
    MatchQueue queue, {
    String tournamentId = defaultTournamentId,
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
    await _getDoc(tournamentId, 'matchQueue').set(data);
  }

  /// Loads match queue from Firestore
  /// Returns empty MatchQueue if document exists but has no data (setup phase)
  /// Returns null only if document doesn't exist
  Future<MatchQueue?> loadMatchQueue({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _getDoc(tournamentId, 'matchQueue').get();
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
    String tournamentId = defaultTournamentId,
  }) {
    return _getDoc(tournamentId, 'matchQueue').snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      final waitingMap = data['waiting'] as Map<String, dynamic>;
      final numberOfQueues = data['numberOfQueues'] as int;
      final playingList = data['playing'] as List;

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

  // ==================== TOURNAMENT INITIALIZATION ====================

  /// Initializes a new tournament from teams and groups
  /// This creates all necessary data structures
  Future<void> initializeTournament(
    List<Team> teams,
    Groups groups, {
    String tournamentId = defaultTournamentId,
  }) async {
    // Save flat list of teams
    await saveTeams(teams, tournamentId: tournamentId);

    // Save groups (team ID groupings)
    await saveGroups(groups, tournamentId: tournamentId);

    // Create and save group phase matches
    final gruppenphase = Gruppenphase.create(groups);
    await saveGruppenphase(gruppenphase, tournamentId: tournamentId);

    // Create and save match queue
    final queue = MatchQueue.create(gruppenphase);
    await saveMatchQueue(queue, tournamentId: tournamentId);

    // Create and save initial standings
    final tabellen = evalGruppen(gruppenphase);
    await saveTabellen(tabellen, tournamentId: tournamentId);

    // Create and save knockout structure (empty initially)
    final knockouts = Knockouts();
    knockouts.instantiate();
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Update tournament metadata (use update to preserve creatorId, password etc.)
    // Fall back to set with merge if document doesn't exist
    try {
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .update({
        'phase': 'groups', // 'groups' or 'knockouts'
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Document might not exist yet (legacy behavior)
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': 'groups',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Transitions tournament from group phase to knockout phase
  Future<void> transitionToKnockouts({
    String tournamentId = defaultTournamentId,
    required int numberOfGroups,
  }) async {
    // Load gruppenphase and calculate standings
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;
    final tabellen = evalGruppen(gruppenphase);

    // Evaluate and create knockouts
    final knockouts = numberOfGroups == 8
        ? evaluateGroups8(tabellen)
        : evaluateGroups6(tabellen);

    // Save knockouts
    await saveKnockouts(knockouts, tournamentId: tournamentId);

    // Update tournament phase
    await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .update({
      'phase': 'knockouts',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update match queue for knockouts
    final queue = await loadMatchQueue(tournamentId: tournamentId);
    if (queue != null) {
      queue.updateKnockQueue(knockouts);
      await saveMatchQueue(queue, tournamentId: tournamentId);
    }
  }

  /// Re-evaluates group standings based on current match results
  Future<void> updateStandings({
    String tournamentId = defaultTournamentId,
  }) async {
    final gruppenphase = await loadGruppenphase(tournamentId: tournamentId);
    if (gruppenphase == null) return;

    final tabellen = evalGruppen(gruppenphase);
    await saveTabellen(tabellen, tournamentId: tournamentId);
  }

  // ==================== TOURNAMENT MANAGEMENT ====================

  /// Gets tournament metadata (phase, timestamps, etc.)
  Future<Map<String, dynamic>?> getTournamentMetadata({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Stream of tournament metadata
  Stream<Map<String, dynamic>?> tournamentMetadataStream({
    String tournamentId = defaultTournamentId,
  }) {
    return _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    });
  }

  /// Deletes all tournament data
  Future<void> deleteTournament({
    String tournamentId = defaultTournamentId,
  }) async {
    final batch = _firestore.batch();

    // Delete all sub-collections
    batch.delete(_getDoc(tournamentId, 'teams'));
    batch.delete(_getDoc(tournamentId, 'gruppen'));
    batch.delete(_getDoc(tournamentId, 'tabellen'));
    batch.delete(_getDoc(tournamentId, 'knockouts'));
    batch.delete(_getDoc(tournamentId, 'matchQueue'));

    // Delete tournament document
    batch.delete(
        _firestore.collection(_tournamentsCollection).doc(tournamentId));

    await batch.commit();
  }

  /// Resets tournament to initial state (keeps teams and groups, resets everything else)
  Future<void> resetTournament({
    String tournamentId = defaultTournamentId,
  }) async {
    final teams = await loadTeams(tournamentId: tournamentId);
    final groups = await loadGroups(tournamentId: tournamentId);
    if (teams == null || groups == null) return;

    await deleteTournament(tournamentId: tournamentId);
    await initializeTournament(teams, groups, tournamentId: tournamentId);
  }

  // ==================== UTILITY METHODS ====================

  /// Lists all tournaments
  Future<List<String>> listTournaments() async {
    final snapshot = await _firestore.collection(_tournamentsCollection).get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Gets tournaments created by a specific user
  Future<List<String>> listUserTournaments(String creatorId) async {
    final snapshot = await _firestore
        .collection(_tournamentsCollection)
        .where('creatorId', isEqualTo: creatorId)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Checks if a tournament exists
  Future<bool> tournamentExists({
    String tournamentId = defaultTournamentId,
  }) async {
    final doc = await _firestore
        .collection(_tournamentsCollection)
        .doc(tournamentId)
        .get();
    return doc.exists;
  }

  /// Creates a new empty tournament with just the name and creator info
  /// Returns the tournament ID if successful, null otherwise
  /// Also creates empty placeholder documents for all collections so they're ready for data
  Future<String?> createTournament({
    required String tournamentName,
    required String creatorId,
    required String creatorEmail,
    required String password,
  }) async {
    try {
      // Use the tournament name as the ID (sanitized)
      final tournamentId =
          tournamentName.trim().replaceAll(RegExp(r'\s+'), '-');

      // Check if tournament already exists
      if (await tournamentExists(tournamentId: tournamentId)) {
        return null; // Tournament with this name already exists
      }

      // Create tournament document with metadata
      await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .set({
        'name': tournamentName,
        'creatorId': creatorId,
        'creatorEmail': creatorEmail,
        'password': password, // In production, this should be hashed
        'phase': 'setup', // 'setup', 'groups' or 'knockouts'
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create empty placeholder documents for all collections
      // This ensures the collections exist and are ready for data
      final batch = _firestore.batch();

      // Teams placeholder
      batch.set(_getDoc(tournamentId, 'teams'), {
        'teams': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Groups placeholder
      batch.set(_getDoc(tournamentId, 'gruppen'), {
        'groups': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Match queue placeholder
      batch.set(_getDoc(tournamentId, 'matchQueue'), {
        'queue': [],
        'currentIndex': 0,
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gruppenphase placeholder
      batch.set(_getDoc(tournamentId, 'gruppenphase'), {
        'gruppen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Tabellen placeholder
      batch.set(_getDoc(tournamentId, 'tabellen'), {
        'tabellen': [],
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Knockouts placeholder
      batch.set(_getDoc(tournamentId, 'knockouts'), {
        'champions': {'rounds': []},
        'losers': {'rounds': []},
        'initialized': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return tournamentId;
    } catch (e) {
      debugPrint('Error creating tournament: $e');
      return null;
    }
  }

  /// Verifies if the password is correct for a tournament
  Future<bool> verifyTournamentPassword(
      String tournamentId, String password) async {
    try {
      final doc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['password'] == password;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a user is the creator of a tournament
  Future<bool> isCreator(String tournamentId, String userId) async {
    try {
      final doc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data['creatorId'] == userId;
    } catch (e) {
      return false;
    }
  }

  /// Gets tournament info (name, creatorEmail, etc.)
  Future<Map<String, dynamic>?> getTournamentInfo(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      // Don't return the password - return available fields
      return {
        'name': data['name'] ?? tournamentId,
        'creatorId': data['creatorId'],
        'creatorEmail': data['creatorEmail'],
        'phase': data['phase'] ?? 'groups',
        'createdAt': data['createdAt'],
      };
    } catch (e) {
      return null;
    }
  }

  /// Checks if a tournament has a password set
  Future<bool> tournamentHasPassword(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection(_tournamentsCollection)
          .doc(tournamentId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      return data.containsKey('password') &&
          data['password'] != null &&
          data['password'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
