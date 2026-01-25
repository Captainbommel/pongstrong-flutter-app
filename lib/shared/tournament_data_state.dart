import 'package:flutter/material.dart';
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

  /// Remove a match from playing queue
  void finishMatch(String matchId) {
    _matchQueue.removeFromPlaying(matchId);
    notifyListeners();
  }
}
