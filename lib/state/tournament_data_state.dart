import 'dart:async';
import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/app_logger.dart';

// TODO: Consider adding explicit caching layer for frequently accessed data
// While Firestore streams provide local caching, adding app-level caching for:
// - Team lookups by ID
// - Match lookups by ID
// - Table rankings

/// Holds the current tournament data loaded from Firestore
class TournamentDataState extends ChangeNotifier {
  List<Team> _teams = [];
  MatchQueue _matchQueue = MatchQueue();
  Gruppenphase _gruppenphase = Gruppenphase();
  Tabellen _tabellen = Tabellen();
  Knockouts _knockouts = Knockouts();
  String _currentTournamentId = FirestoreBase.defaultTournamentId;
  bool _isKnockoutMode = false;
  String _tournamentStyle = 'groupsAndKnockouts';
  String? _selectedRuleset = 'bmt-cup';

  // Stream subscriptions for real-time updates
  StreamSubscription? _groupPhaseSubscription;
  StreamSubscription? _matchQueueSubscription;
  StreamSubscription? _knockoutsSubscription;

  List<Team> get teams => _teams;
  MatchQueue get matchQueue => _matchQueue;
  Gruppenphase get gruppenphase => _gruppenphase;
  Tabellen get tabellen => _tabellen;
  Knockouts get knockouts => _knockouts;
  String get currentTournamentId => _currentTournamentId;
  bool get isKnockoutMode => _isKnockoutMode;
  String get tournamentStyle => _tournamentStyle;
  bool get rulesEnabled => _selectedRuleset != null;
  String? get selectedRuleset => _selectedRuleset;

  bool get hasData => _teams.isNotEmpty;

  /// Check if the tournament is in setup phase (no game data yet)
  bool get isSetupPhase => _teams.isEmpty && _currentTournamentId.isNotEmpty;

  /// Load tournament data from Firestore
  /// Returns true if tournament exists (even if in setup phase with no game data)
  Future<bool> loadTournamentData(String tournamentId) async {
    Logger.info('Loading tournament data: $tournamentId',
        tag: 'TournamentData');
    try {
      final service = FirestoreService();

      // First check if tournament exists at all
      final tournamentInfo = await service.getTournamentInfo(tournamentId);
      if (tournamentInfo == null) {
        Logger.warning('Tournament not found: $tournamentId',
            tag: 'TournamentData');
        return false;
      }

      // Store tournament metadata
      _tournamentStyle =
          tournamentInfo['tournamentStyle'] ?? 'groupsAndKnockouts';
      // Only default to 'bmt-cup' if the field doesn't exist (backwards compatibility)
      // If it exists and is null, keep it as null (user explicitly disabled rules)
      if (tournamentInfo.containsKey('selectedRuleset')) {
        _selectedRuleset = tournamentInfo['selectedRuleset'] as String?;
      } else {
        _selectedRuleset = 'bmt-cup'; // Default for old tournaments
      }

      final teams = await service.loadTeams(tournamentId: tournamentId);
      final matchQueue =
          await service.loadMatchQueue(tournamentId: tournamentId);
      final groupPhase =
          await service.loadGruppenphase(tournamentId: tournamentId);
      final knockouts = await service.loadKnockouts(tournamentId: tournamentId);

      // Tournament exists but may be in setup phase (no game data yet)
      if (teams != null && matchQueue != null && groupPhase != null) {
        _teams = teams;
        _matchQueue = matchQueue;
        _gruppenphase = groupPhase;
        _tabellen = evalGruppen(groupPhase);
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
        Logger.info(
            'Tournament loaded successfully: ${teams.length} teams, knockout mode: $_isKnockoutMode',
            tag: 'TournamentData');
      } else {
        // Tournament exists but is in setup phase - clear any old data
        _teams = [];
        _matchQueue = MatchQueue();
        _gruppenphase = Gruppenphase();
        _tabellen = Tabellen();
        _knockouts = Knockouts();
        _currentTournamentId = tournamentId;
        _isKnockoutMode = false;
        _cancelStreams();
        Logger.info('Tournament in setup phase: $tournamentId',
            tag: 'TournamentData');
      }

      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error loading tournament data',
          tag: 'TournamentData', error: e);
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
    Logger.debug('Clearing tournament data', tag: 'TournamentData');
    _teams = [];
    _matchQueue = MatchQueue();
    _gruppenphase = Gruppenphase();
    _tabellen = Tabellen();
    _knockouts = Knockouts();
    _isKnockoutMode = false;
    _tournamentStyle = 'groupsAndKnockouts';
    _selectedRuleset = 'bmt-cup';
    _cancelStreams();
    notifyListeners();
  }

  /// Update the selected ruleset (called from admin panel to sync state)
  void updateSelectedRuleset(String? ruleset) {
    _selectedRuleset = ruleset;
    notifyListeners();
  }

  /// Setup real-time streams from Firestore
  void _setupStreams() {
    _cancelStreams(); // Cancel any existing subscriptions
    Logger.debug(
        'Setting up Firestore streams for tournament: $_currentTournamentId',
        tag: 'TournamentData');

    final service = FirestoreService();

    // Listen to group phase changes
    _groupPhaseSubscription = service
        .gruppenphaseStream(tournamentId: _currentTournamentId)
        .listen((groupPhase) {
      if (groupPhase != null) {
        Logger.debug('Group phase updated from Firestore',
            tag: 'TournamentData');
        _gruppenphase = groupPhase;
        _tabellen = evalGruppen(groupPhase);
        notifyListeners();
      }
    }, onError: (e) {
      Logger.error('Error in group phase stream',
          tag: 'TournamentData', error: e);
    });

    // Listen to match queue changes
    _matchQueueSubscription = service
        .matchQueueStream(tournamentId: _currentTournamentId)
        .listen((queue) {
      if (queue != null) {
        Logger.debug('Match queue updated from Firestore',
            tag: 'TournamentData');
        _matchQueue = queue;
        notifyListeners();
      }
    }, onError: (e) {
      Logger.error('Error in match queue stream',
          tag: 'TournamentData', error: e);
    });

    // Listen to knockouts changes
    _knockoutsSubscription = service
        .knockoutsStream(tournamentId: _currentTournamentId)
        .listen((knockouts) {
      if (knockouts != null) {
        Logger.debug('Knockouts updated from Firestore', tag: 'TournamentData');
        _knockouts = knockouts;
        notifyListeners();
      }
    }, onError: (e) {
      Logger.error('Error in knockouts stream',
          tag: 'TournamentData', error: e);
    });
  }

  /// Cancel all stream subscriptions
  void _cancelStreams() {
    Logger.debug('Cancelling Firestore streams', tag: 'TournamentData');
    _groupPhaseSubscription?.cancel();
    _matchQueueSubscription?.cancel();
    _knockoutsSubscription?.cancel();
  }

  @override
  void dispose() {
    Logger.debug('Disposing TournamentDataState', tag: 'TournamentData');
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
  // TODO: Potential race condition - if two matches start/finish simultaneously,
  // both read the same initial state and may overwrite each other's changes.
  // Consider using Firestore transactions for atomic updates.
  Future<bool> startMatch(String matchId) async {
    Logger.info('Starting match: $matchId', tag: 'TournamentData');
    // Store previous state for rollback
    final previousMatchQueue = _matchQueue.clone();

    final success = _matchQueue.switchPlaying(matchId);
    if (!success) {
      Logger.warning('Failed to switch match to playing: $matchId',
          tag: 'TournamentData');
      return false;
    }

    // Save updated match queue to Firestore
    try {
      final service = FirestoreService();
      await service.saveMatchQueue(_matchQueue,
          tournamentId: _currentTournamentId);
      Logger.info('Match started successfully: $matchId',
          tag: 'TournamentData');
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error saving match queue', tag: 'TournamentData', error: e);
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      Logger.warning('Reverted local match queue changes for match: $matchId',
          tag: 'TournamentData');
      return false;
    }
  }

  /// Remove a match from playing queue and update standings
  Future<bool> finishMatch(String matchId) async {
    Logger.info('Finishing match: $matchId', tag: 'TournamentData');
    // find the match in playing
    final match = _matchQueue.playing.firstWhere(
      (m) => m.id == matchId,
      orElse: () => Match(),
    );
    if (match.id.isEmpty) {
      Logger.warning('Match not found in playing queue: $matchId',
          tag: 'TournamentData');
      return false; // match not found
    }

    // validate score from queue
    final points = match.getPoints();
    if (points == null) {
      Logger.warning(
          'Invalid score for match $matchId - not updating standings',
          tag: 'TournamentData');
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
    Logger.debug('Finishing group match: $matchId', tag: 'TournamentData');
    // load group phase
    final service = FirestoreService();
    final groupPhase =
        await service.loadGruppenphase(tournamentId: _currentTournamentId);

    if (groupPhase == null) {
      Logger.error('Could not load group phase for match: $matchId',
          tag: 'TournamentData');
      return false;
    }

    // Find which group contains this match and update it
    int groupIndex = -1;
    Match? groupPhaseMatch;
    for (int i = 0; i < groupPhase.groups.length; i++) {
      for (var m in groupPhase.groups[i]) {
        if (m.id == matchId) {
          groupIndex = i;
          groupPhaseMatch = m;
          break;
        }
      }
      if (groupPhaseMatch != null) break;
    }

    if (groupPhaseMatch == null) {
      Logger.warning('Match $matchId not found in group phase',
          tag: 'TournamentData');
      return false;
    }

    // update the match with final scores
    groupPhaseMatch.score1 = match.score1;
    groupPhaseMatch.score2 = match.score2;
    groupPhaseMatch.done = true;

    Logger.info(
      'Updated match $matchId in group phase: ${match.score1}-${match.score2}',
      tag: 'TournamentData',
    );

    // Store previous state for rollback
    final previousMatchQueue = _matchQueue.clone();
    final previousTabellen = _tabellen.clone();

    // remove from playing
    _matchQueue.removeFromPlaying(matchId);

    // recalculate tables
    final updatedTables = evalGruppen(groupPhase);
    _tabellen = updatedTables;

    // update Firestore
    try {
      await service.saveGruppenphase(
        groupPhase,
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

      Logger.info(
        'Saved updated group phase, tables, and match queue for group $groupIndex',
        tag: 'TournamentData',
      );

      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error saving to Firestore',
          tag: 'TournamentData', error: e);
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      _tabellen = previousTabellen;
      Logger.warning('Reverted local changes for match: $matchId',
          tag: 'TournamentData');
      return false;
    }
  }

  /// Finish a knockout match
  Future<bool> _finishKnockoutMatch(String matchId, Match match) async {
    Logger.debug('Finishing knockout match: $matchId', tag: 'TournamentData');
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
      Logger.warning('Match $matchId not found in knockouts',
          tag: 'TournamentData');
      return false;
    }

    Logger.info(
      'Updated match $matchId in knockouts: ${match.score1}-${match.score2}',
      tag: 'TournamentData',
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

      Logger.info('Saved updated knockouts and match queue',
          tag: 'TournamentData');

      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error saving knockouts to Firestore',
          tag: 'TournamentData', error: e);
      // Revert local changes on Firestore save failure
      _matchQueue = previousMatchQueue;
      Logger.warning('Reverted local changes for match: $matchId',
          tag: 'TournamentData');
      return false;
    }
  }

  /// Transition from group phase to knockout phase
  /// This will evaluate the group standings and populate the knockout structure
  Future<bool> transitionToKnockouts({int numberOfGroups = 8}) async {
    Logger.info('Transitioning to knockouts with $numberOfGroups groups',
        tag: 'TournamentData');
    try {
      final service = FirestoreService();

      // Load current group phase to calculate standings
      final groupPhase =
          await service.loadGruppenphase(tournamentId: _currentTournamentId);

      if (groupPhase == null) {
        Logger.error('Could not load group phase for knockout transition',
            tag: 'TournamentData');
        return false;
      }

      // Calculate final standings
      final tabellen = evalGruppen(groupPhase);

      // Evaluate and create knockouts based on number of groups
      final knockouts = numberOfGroups == 8
          ? evaluateGroups8(tabellen)
          : evaluateGroups6(tabellen);

      // Clear match queue and fill with knockout matches
      _matchQueue = MatchQueue(
        waiting: List.generate(6, (_) => <Match>[]),
        playing: [],
      );
      _matchQueue.updateKnockQueue(knockouts);

      Logger.debug('Match queue updated with knockout matches',
          tag: 'TournamentData');

      // Save knockouts and match queue to Firestore
      await service.saveKnockouts(knockouts,
          tournamentId: _currentTournamentId);
      await service.saveMatchQueue(_matchQueue,
          tournamentId: _currentTournamentId);

      Logger.info(
        'Successfully transitioned to knockouts with $numberOfGroups groups',
        tag: 'TournamentData',
      );

      // Update local state
      _knockouts = knockouts;
      _isKnockoutMode = true;
      notifyListeners();

      return true;
    } catch (e) {
      Logger.error('Error transitioning to knockouts',
          tag: 'TournamentData', error: e);
      return false;
    }
  }

  /// Edit a finished match score
  /// For knockout matches, this will clear all dependent matches (with cascade reset)
  Future<bool> editMatchScore(
    String matchId,
    int newScore1,
    int newScore2,
    int groupIndex, {
    required bool isKnockout,
  }) async {
    Logger.info(
      'Editing match $matchId: $newScore1-$newScore2 (knockout: $isKnockout)',
      tag: 'TournamentData',
    );

    if (isKnockout) {
      return _editKnockoutMatch(matchId, newScore1, newScore2);
    } else {
      return _editGroupMatch(matchId, newScore1, newScore2, groupIndex);
    }
  }

  /// Edit a group phase match
  Future<bool> _editGroupMatch(
    String matchId,
    int newScore1,
    int newScore2,
    int groupIndex,
  ) async {
    Logger.debug('Editing group match: $matchId', tag: 'TournamentData');
    final service = FirestoreService();

    try {
      // Load current group phase
      final groupPhase =
          await service.loadGruppenphase(tournamentId: _currentTournamentId);

      if (groupPhase == null) {
        Logger.error('Could not load group phase', tag: 'TournamentData');
        return false;
      }

      // Find and update the match
      Match? targetMatch;
      for (int i = 0; i < groupPhase.groups.length; i++) {
        for (var match in groupPhase.groups[i]) {
          if (match.id == matchId) {
            match.score1 = newScore1;
            match.score2 = newScore2;
            targetMatch = match;
            break;
          }
        }
        if (targetMatch != null) break;
      }

      if (targetMatch == null) {
        Logger.warning('Match $matchId not found in group phase',
            tag: 'TournamentData');
        return false;
      }

      Logger.info('Updated match $matchId scores to $newScore1-$newScore2',
          tag: 'TournamentData');

      // Recalculate tables
      final updatedTables = evalGruppen(groupPhase);

      // Save to Firestore
      await service.saveGruppenphase(
        groupPhase,
        tournamentId: _currentTournamentId,
      );
      await service.saveTabellen(
        updatedTables,
        tournamentId: _currentTournamentId,
      );

      Logger.info('Saved updated group phase and tables',
          tag: 'TournamentData');

      // Update local state
      _tabellen = updatedTables;
      notifyListeners();

      return true;
    } catch (e) {
      Logger.error('Error editing group match',
          tag: 'TournamentData', error: e);
      return false;
    }
  }

  /// Edit a knockout match (with cascade reset of dependent matches)
  Future<bool> _editKnockoutMatch(
    String matchId,
    int newScore1,
    int newScore2,
  ) async {
    Logger.debug('Editing knockout match: $matchId', tag: 'TournamentData');
    final service = FirestoreService();

    try {
      // Clear dependent matches first
      final clearedIds = _knockouts.clearDependentMatches(matchId);

      if (clearedIds.isNotEmpty) {
        Logger.info(
          'Cleared ${clearedIds.length} dependent matches: ${clearedIds.join(", ")}',
          tag: 'TournamentData',
        );
      }

      // Update the target match score
      final updated =
          _knockouts.updateMatchScore(matchId, newScore1, newScore2);

      if (!updated) {
        Logger.warning('Match $matchId not found in knockouts',
            tag: 'TournamentData');
        return false;
      }

      Logger.info('Updated match $matchId scores to $newScore1-$newScore2',
          tag: 'TournamentData');

      // Recalculate knockout progression
      _knockouts.update();

      // Update match queue with new ready matches
      _matchQueue.updateKnockQueue(_knockouts);

      // Save to Firestore
      await service.saveKnockouts(
        _knockouts,
        tournamentId: _currentTournamentId,
      );
      await service.saveMatchQueue(
        _matchQueue,
        tournamentId: _currentTournamentId,
      );

      Logger.info('Saved updated knockouts and match queue',
          tag: 'TournamentData');

      notifyListeners();

      return true;
    } catch (e) {
      Logger.error('Error editing knockout match',
          tag: 'TournamentData', error: e);
      return false;
    }
  }
}
