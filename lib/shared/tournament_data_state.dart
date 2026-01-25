import 'dart:async';
import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service.dart';

/// Holds the current tournament data loaded from Firestore
class TournamentDataState extends ChangeNotifier {
  List<Team> _teams = [];
  MatchQueue _matchQueue = MatchQueue();
  Tabellen _tabellen = Tabellen();
  String _currentTournamentId = FirestoreService.defaultTournamentId;

  // Stream subscriptions for real-time updates
  StreamSubscription? _gruppenphaseSubscription;
  StreamSubscription? _matchQueueSubscription;

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
      final gruppenphase =
          await service.loadGruppenphase(tournamentId: tournamentId);

      if (teams != null && matchQueue != null && gruppenphase != null) {
        _teams = teams;
        _matchQueue = matchQueue;
        _tabellen = evalGruppen(gruppenphase);
        _currentTournamentId = tournamentId;
        // Start listening to real-time updates
        _setupStreams();
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
    _cancelStreams();
    notifyListeners();
  }

  /// Setup real-time streams from Firestore
  void _setupStreams() {
    _cancelStreams(); // Cancel any existing subscriptions

    final service = FirestoreService();

    // Listen to gruppenphase changes
    _gruppenphaseSubscription = service
        .gruppenphaseStream(tournamentId: _currentTournamentId)
        .listen((gruppenphase) {
      if (gruppenphase != null) {
        debugPrint('Gruppenphase updated from Firestore');
        _tabellen = evalGruppen(gruppenphase);
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Error in gruppenphase stream: $e');
    });

    // Listen to match queue changes
    _matchQueueSubscription = service
        .matchQueueStream(tournamentId: _currentTournamentId)
        .listen((queue) {
      if (queue != null) {
        debugPrint('Match queue updated from Firestore');
        _matchQueue = queue;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Error in match queue stream: $e');
    });
  }

  /// Cancel all stream subscriptions
  void _cancelStreams() {
    _gruppenphaseSubscription?.cancel();
    _matchQueueSubscription?.cancel();
  }

  @override
  void dispose() {
    _cancelStreams();
    super.dispose();
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
  Future<bool> startMatch(String matchId) async {
    // Store previous state for rollback
    final previousMatchQueue = _matchQueue.clone();

    final success = _matchQueue.switchPlaying(matchId);
    if (!success) return false;

    // Save updated match queue to Firestore
    try {
      final service = FirestoreService();
      await service.saveMatchQueue(_matchQueue,
          tournamentId: _currentTournamentId);
      debugPrint('Saved match queue after starting match $matchId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving match queue: $e');
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      debugPrint('Reverted local match queue changes for match $matchId');
      return false;
    }
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

    // Store previous state for rollback
    final previousMatchQueue = _matchQueue.clone();
    final previousTabellen = _tabellen.clone();

    // remove from playing
    _matchQueue.removeFromPlaying(matchId);

    // recalculate tables
    final updatedTables = evalGruppen(gruppenphase);
    _tabellen = updatedTables;

    // update Firestore
    try {
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
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      _tabellen = previousTabellen;
      debugPrint('Reverted local changes for match $matchId');
      return false;
    }
  }
}
