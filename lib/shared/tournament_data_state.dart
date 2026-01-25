import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service.dart';

/// Holds the current tournament data loaded from Firestore
class TournamentDataState extends ChangeNotifier {
  List<Team> _teams = [];
  MatchQueue _matchQueue = MatchQueue();
  Tabellen _tabellen = Tabellen();
  String _currentTournamentId = FirestoreService.defaultTournamentId;

  List<Team> get teams => _teams;
  MatchQueue get matchQueue => _matchQueue;
  Tabellen get tabellen => _tabellen;
  String get currentTournamentId => _currentTournamentId;

  bool get hasData => _teams.isNotEmpty;

  /// Load tournament data from Firestore
  Future<bool> loadTournamentData(String tournamentId) async {
    try {
      final service = FirestoreService();

      final teams = await service.loadTeams(tournamentId: tournamentId);
      final matchQueue =
          await service.loadMatchQueue(tournamentId: tournamentId);
      final tabellen = await service.loadTabellen(tournamentId: tournamentId);

      if (teams != null && matchQueue != null && tabellen != null) {
        _teams = teams;
        _matchQueue = matchQueue;
        _tabellen = tabellen;
        _currentTournamentId = tournamentId;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading tournament data: $e');
      return false;
    }
  }

  /// Load tournament data from Firestore
  void loadData({
    required List<Team> teams,
    required MatchQueue matchQueue,
    required Tabellen tabellen,
  }) {
    _teams = teams;
    _matchQueue = matchQueue;
    _tabellen = tabellen;
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _teams = [];
    _matchQueue = MatchQueue();
    _tabellen = Tabellen();
    notifyListeners();
  }

  /// Get team by ID
  Team? getTeam(String teamId) {
    try {
      return _teams.firstWhere((t) => t.id == teamId);
    } catch (e) {
      return null;
    }
  }

  /// Get next matches (waiting and available to play)
  List<Match> getNextMatches() {
    return _matchQueue.nextMatches();
  }

  /// Get next-next matches (waiting but table occupied)
  List<Match> getNextNextMatches() {
    return _matchQueue.nextNextMatches();
  }

  /// Get currently playing matches
  List<Match> getPlayingMatches() {
    return _matchQueue.playing;
  }

  /// Move a match from waiting to playing queue
  bool startMatch(String matchId) {
    final success = _matchQueue.switchPlaying(matchId);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// Remove a match from playing queue and update standings
  Future<bool> finishMatch(String matchId) async {
    // find the match in playing
    final match = _matchQueue.playing.firstWhere(
      (m) => m.id == matchId,
      orElse: () => Match(),
    );
    if (match.id.isEmpty) return false; // match not found

    // validate score from queue
    final points = match.getPoints();
    if (points == null) {
      debugPrint('Invalid score for match $matchId - not updating standings');
      return false; // invalid score
    }

    // load gruppenphase
    final service = FirestoreService();
    final gruppenphase =
        await service.loadGruppenphase(tournamentId: _currentTournamentId);

    if (gruppenphase == null) {
      debugPrint('Could not load gruppenphase for match $matchId');
      return false;
    }

    // Find which group contains this match and update it
    int groupIndex = -1;
    Match? gruppenphasMatch;
    for (int i = 0; i < gruppenphase.groups.length; i++) {
      for (var m in gruppenphase.groups[i]) {
        if (m.id == matchId) {
          groupIndex = i;
          gruppenphasMatch = m;
          break;
        }
      }
      if (gruppenphasMatch != null) break;
    }

    if (gruppenphasMatch == null) {
      debugPrint('Match $matchId not found in gruppenphase');
      return false;
    }

    // update the match with final scores
    gruppenphasMatch.score1 = match.score1;
    gruppenphasMatch.score2 = match.score2;
    gruppenphasMatch.done = true;

    debugPrint(
      'Updated match $matchId in gruppenphase: ${match.score1}-${match.score2}',
    );

    // remove from playing
    _matchQueue.removeFromPlaying(matchId);

    // recalculate tables
    final updatedTables = evalGruppen(gruppenphase);
    _tabellen = updatedTables;

    // update Firestore
    await service.saveGruppenphase(
      gruppenphase,
      tournamentId: _currentTournamentId,
    );
    await service.saveTabellen(
      _tabellen,
      tournamentId: _currentTournamentId,
    );
    await service.saveMatchQueue(
      _matchQueue,
      tournamentId: _currentTournamentId,
    );

    debugPrint(
      'Saved updated gruppenphase, tables, and match queue for group $groupIndex',
    );

    notifyListeners();
    return true;
  }
}
