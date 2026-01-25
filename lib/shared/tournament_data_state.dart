import 'dart:async';
import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service.dart';

/// Holds the current tournament data loaded from Firestore
class TournamentDataState extends ChangeNotifier {
  List<Team> _teams = [];
  MatchQueue _matchQueue = MatchQueue();
  Tabellen _tabellen = Tabellen();
  Knockouts _knockouts = Knockouts();
  String _currentTournamentId = FirestoreService.defaultTournamentId;
  bool _isKnockoutMode = false;

  // Stream subscriptions for real-time updates
  StreamSubscription? _gruppenphaseSubscription;
  StreamSubscription? _matchQueueSubscription;
  StreamSubscription? _knockoutsSubscription;

  List<Team> get teams => _teams;
  MatchQueue get matchQueue => _matchQueue;
  Tabellen get tabellen => _tabellen;
  Knockouts get knockouts => _knockouts;
  String get currentTournamentId => _currentTournamentId;
  bool get isKnockoutMode => _isKnockoutMode;

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
      final knockouts = await service.loadKnockouts(tournamentId: tournamentId);

      if (teams != null && matchQueue != null && gruppenphase != null) {
        _teams = teams;
        _matchQueue = matchQueue;
        _tabellen = evalGruppen(gruppenphase);
        _knockouts = knockouts ?? Knockouts();
        _currentTournamentId = tournamentId;
        // Check if knockouts have been initialized to determine mode
        _isKnockoutMode = knockouts != null &&
            knockouts.champions.rounds.isNotEmpty &&
            knockouts.champions.rounds[0].isNotEmpty &&
            (knockouts.champions.rounds[0][0].teamId1.isNotEmpty ||
                knockouts.champions.rounds[0][0].teamId2.isNotEmpty);
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
    Knockouts? knockouts,
  }) {
    _teams = teams;
    _matchQueue = matchQueue;
    _tabellen = tabellen;
    _knockouts = knockouts ?? Knockouts();
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _teams = [];
    _matchQueue = MatchQueue();
    _tabellen = Tabellen();
    _knockouts = Knockouts();
    _isKnockoutMode = false;
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

    // Listen to knockouts changes
    _knockoutsSubscription = service
        .knockoutsStream(tournamentId: _currentTournamentId)
        .listen((knockouts) {
      if (knockouts != null) {
        debugPrint('Knockouts updated from Firestore');
        _knockouts = knockouts;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Error in knockouts stream: $e');
    });
  }

  /// Cancel all stream subscriptions
  void _cancelStreams() {
    _gruppenphaseSubscription?.cancel();
    _matchQueueSubscription?.cancel();
    _knockoutsSubscription?.cancel();
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

    // Route to appropriate handler based on mode
    if (_isKnockoutMode) {
      return _finishKnockoutMatch(matchId, match);
    } else {
      return _finishGroupMatch(matchId, match);
    }
  }

  /// Finish a group phase match
  Future<bool> _finishGroupMatch(String matchId, Match match) async {
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

  /// Finish a knockout match
  Future<bool> _finishKnockoutMatch(String matchId, Match match) async {
    final service = FirestoreService();

    // Helper function to find and update match in knockout structure
    bool findAndUpdateMatch(List<List<Match>> rounds) {
      for (var round in rounds) {
        for (var m in round) {
          if (m.id == matchId) {
            m.score1 = match.score1;
            m.score2 = match.score2;
            m.done = true;
            return true;
          }
        }
      }
      return false;
    }

    // Search and update in all knockout structures
    bool found = findAndUpdateMatch(_knockouts.champions.rounds) ||
        findAndUpdateMatch(_knockouts.europa.rounds) ||
        findAndUpdateMatch(_knockouts.conference.rounds);

    // Search in super cup if not found in other tournaments
    if (!found) {
      for (var m in _knockouts.superCup.matches) {
        if (m.id == matchId) {
          m.score1 = match.score1;
          m.score2 = match.score2;
          m.done = true;
          found = true;
          break;
        }
      }
    }

    if (!found) {
      debugPrint('Match $matchId not found in knockouts');
      return false;
    }

    debugPrint(
      'Updated match $matchId in knockouts: ${match.score1}-${match.score2}',
    );

    // Store previous state for rollback
    final previousMatchQueue = _matchQueue.clone();

    // Remove from playing
    _matchQueue.removeFromPlaying(matchId);

    // Update knockout structure to move winners forward
    _knockouts.update();

    // Add new ready matches to queue
    _matchQueue.updateKnockQueue(_knockouts);

    // Save to Firestore
    try {
      await service.saveKnockouts(
        _knockouts,
        tournamentId: _currentTournamentId,
      );
      await service.saveMatchQueue(
        _matchQueue,
        tournamentId: _currentTournamentId,
      );

      debugPrint('Saved updated knockouts and match queue');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      debugPrint('Reverted local changes for match $matchId');
      return false;
    }
  }

  /// Transition from group phase to knockout phase
  /// This will evaluate the group standings and populate the knockout structure
  Future<bool> transitionToKnockouts({int numberOfGroups = 8}) async {
    try {
      final service = FirestoreService();

      debugPrint("Here 0");

      // Load current gruppenphase to calculate standings
      final gruppenphase =
          await service.loadGruppenphase(tournamentId: _currentTournamentId);

      debugPrint("Here 1");

      if (gruppenphase == null) {
        debugPrint('Could not load gruppenphase for knockout transition');
        return false;
      }

      debugPrint("Here 2");

      // Calculate final standings
      final tabellen = evalGruppen(gruppenphase);

      debugPrint("Here 3");

      // Evaluate and create knockouts based on number of groups
      final knockouts = numberOfGroups == 8
          ? evaluateGroups8(tabellen)
          : evaluateGroups6(tabellen);

      debugPrint("Here 4");

      // Clear match queue and fill with knockout matches
      _matchQueue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );
      _matchQueue.updateKnockQueue(knockouts);

      debugPrint("Match queue updated with knockout matches");

      // Save knockouts and match queue to Firestore
      await service.saveKnockouts(knockouts,
          tournamentId: _currentTournamentId);
      await service.saveMatchQueue(_matchQueue,
          tournamentId: _currentTournamentId);

      debugPrint(
        'Successfully transitioned to knockouts with $numberOfGroups groups',
      );

      // Update local state
      _knockouts = knockouts;
      _isKnockoutMode = true;
      notifyListeners();

      debugPrint("Here 5");

      return true;
    } catch (e) {
      debugPrint('Error transitioning to knockouts: $e');
      return false;
    }
  }
}
