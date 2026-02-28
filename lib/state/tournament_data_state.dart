import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// Holds the current tournament data loaded from Firestore
/// with performance optimizations including caching for teams and tables
class TournamentDataState extends ChangeNotifier {
  final FirestoreService _firestoreService;

  /// Creates a [TournamentDataState].
  ///
  /// [firestoreService] is optional – production code omits it and the shared
  /// singleton is used. Pass [FirestoreService.forTesting] in unit tests.
  TournamentDataState({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<Team> _teams = [];
  MatchQueue _matchQueue = MatchQueue();
  Gruppenphase _gruppenphase = Gruppenphase();
  Tabellen _tabellen = Tabellen();
  Knockouts _knockouts = Knockouts();
  String _currentTournamentId = FirestoreBase.defaultTournamentId;
  bool _isKnockoutMode = false;
  String _tournamentStyle = 'groupsAndKnockouts';
  String? _selectedRuleset = 'bmt-cup';
  String? _joinCode;

  // UI-only toggle: show league colors instead of table colors on playing field.
  // Persisted in RAM across navigations, not saved to Firebase.
  bool _showLeagueColors = false;

  // Async lock to serialise match operations and prevent interleaved
  // read-modify-write on the local match queue.
  // Note: Multi-client safety would additionally require Firestore transactions.
  Future<void>? _matchOperationLock;

  // Performance optimization: Team lookup cache (O(1) instead of O(n))
  Map<String, Team> _teamCache = {};

  // Performance optimization: Tabellen caching to avoid unnecessary recalculation
  String _tabellenHash = '';

  // Performance optimization: Debounce timer for notifyListeners
  Timer? _notifyTimer;

  // Stream subscriptions for real-time updates
  StreamSubscription? _groupPhaseSubscription;
  StreamSubscription? _matchQueueSubscription;
  StreamSubscription? _knockoutsSubscription;

  /// All teams in the current tournament.
  List<Team> get teams => _teams;

  /// The current match scheduling queue.
  MatchQueue get matchQueue => _matchQueue;

  /// The group phase match data.
  Gruppenphase get gruppenphase => _gruppenphase;

  /// Computed standings tables for the group phase.
  Tabellen get tabellen => _tabellen;

  /// The knockout bracket structure.
  Knockouts get knockouts => _knockouts;

  /// The Firestore ID of the currently loaded tournament.
  String get currentTournamentId => _currentTournamentId;

  /// Whether the tournament is in the knockout phase.
  bool get isKnockoutMode => _isKnockoutMode;

  /// The tournament format style (e.g. 'groupsAndKnockouts').
  String get tournamentStyle => _tournamentStyle;

  /// Whether a ruleset is active for this tournament.
  bool get rulesEnabled => _selectedRuleset != null;

  /// Whether to show league colors instead of table colors on the playing field.
  bool get showLeagueColors => _showLeagueColors;

  /// Toggles the league-color display mode (RAM only, not persisted to Firebase).
  void toggleLeagueColors() {
    _showLeagueColors = !_showLeagueColors;
    notifyListeners();
  }

  /// The selected ruleset identifier, or `null` if disabled.
  String? get selectedRuleset => _selectedRuleset;

  /// The 4-char join code for this tournament, or `null` if not set.
  String? get joinCode => _joinCode;

  /// Whether team data has been loaded.
  bool get hasData => _teams.isNotEmpty;

  /// Check if the tournament is in setup phase (no game data yet)
  bool get isSetupPhase => _teams.isEmpty && _currentTournamentId.isNotEmpty;

  /// Load tournament data from Firestore
  /// Returns true if tournament exists (even if in setup phase with no game data)
  Future<bool> loadTournamentData(String tournamentId) async {
    Logger.info('Loading tournament data: $tournamentId',
        tag: 'TournamentData');
    try {
      final service = _firestoreService;

      // First check if tournament exists at all
      final tournamentInfo = await service.getTournamentInfo(tournamentId);
      if (tournamentInfo == null) {
        Logger.warning('Tournament not found: $tournamentId',
            tag: 'TournamentData');
        return false;
      }

      // Store tournament metadata
      final meta = TournamentMetadata.fromMap(tournamentInfo);
      _tournamentStyle = meta.styleFirestoreKey;
      _joinCode = meta.joinCode;
      _selectedRuleset = meta.selectedRuleset;

      final teams = await service.loadTeams(tournamentId: tournamentId);
      final matchQueue =
          await service.loadMatchQueue(tournamentId: tournamentId);
      final groupPhase =
          await service.loadGruppenphase(tournamentId: tournamentId);
      final knockouts = await service.loadKnockouts(tournamentId: tournamentId);

      // Tournament exists but may be in setup phase (no game data yet)
      if (teams != null && matchQueue != null && groupPhase != null) {
        _teams = teams;
        _rebuildTeamCache(); // Build O(1) lookup cache
        _matchQueue = matchQueue;
        _gruppenphase = groupPhase;
        _tabellen = evalGruppen(groupPhase);
        _tabellenHash = _computeGruppenphaseHash(groupPhase);
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

  /// Updates a bracket's display name and persists to Firestore.
  Future<bool> updateBracketName(BracketKey bracketKey, String newName) async {
    try {
      _knockouts.bracketNames[bracketKey] = newName;
      await _firestoreService.saveKnockouts(
        _knockouts,
        tournamentId: _currentTournamentId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error updating bracket name',
          tag: 'TournamentData', error: e);
      return false;
    }
  }

  /// Setup real-time streams from Firestore
  void _setupStreams() {
    _cancelStreams(); // Cancel any existing subscriptions
    Logger.debug(
        'Setting up Firestore streams for tournament: $_currentTournamentId',
        tag: 'TournamentData');

    final service = _firestoreService;

    // Listen to group phase changes
    _groupPhaseSubscription = service
        .gruppenphaseStream(tournamentId: _currentTournamentId)
        .listen((groupPhase) {
      if (groupPhase != null) {
        Logger.debug('Group phase updated from Firestore',
            tag: 'TournamentData');
        _gruppenphase = groupPhase;

        // Only recalculate tables if match data actually changed
        final newHash = _computeGruppenphaseHash(groupPhase);
        if (newHash != _tabellenHash) {
          Logger.debug('Recalculating tables due to match changes',
              tag: 'TournamentData');
          _tabellen = evalGruppen(groupPhase);
          _tabellenHash = newHash;
        } else {
          Logger.debug('Using cached table calculations',
              tag: 'TournamentData');
        }

        _notifyListenersDebounced();
      } else {
        // Document was deleted (e.g. tournament reset) — clear local state
        Logger.debug('Group phase document deleted, clearing local state',
            tag: 'TournamentData');
        _gruppenphase = Gruppenphase();
        _tabellen = Tabellen();
        _tabellenHash = '';
        _notifyListenersDebounced();
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
        _notifyListenersDebounced();
      } else {
        // Document was deleted (e.g. tournament reset) — clear local state
        Logger.debug('Match queue document deleted, clearing local state',
            tag: 'TournamentData');
        _matchQueue = MatchQueue();
        _notifyListenersDebounced();
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
        _notifyListenersDebounced();
      } else {
        // Document was deleted (e.g. tournament reset) — clear local state
        Logger.debug('Knockouts document deleted, clearing local state',
            tag: 'TournamentData');
        _knockouts = Knockouts();
        _isKnockoutMode = false;
        _notifyListenersDebounced();
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
    _notifyTimer?.cancel();
    _cancelStreams();
    super.dispose();
  }

  /// Rebuild team cache for O(1) lookups
  void _rebuildTeamCache() {
    _teamCache = {for (final team in _teams) team.id: team};
    Logger.debug('Rebuilt team cache with ${_teamCache.length} teams',
        tag: 'TournamentData');
  }

  /// Compute hash of gruppenphase state to detect actual changes
  String _computeGruppenphaseHash(Gruppenphase phase) {
    final buffer = StringBuffer();
    for (final group in phase.groups) {
      for (final match in group) {
        if (match.done) {
          buffer.write('${match.id}:${match.score1}:${match.score2}|');
        }
      }
    }
    return buffer.toString();
  }

  /// Debounced notifyListeners to prevent rapid-fire updates
  void _notifyListenersDebounced() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      notifyListeners();
    });
  }

  /// Get team by ID - O(1) cached lookup
  Team? getTeam(String teamId) {
    return _teamCache[teamId];
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

  /// Serialises [operation] so that only one match mutation runs at a time.
  /// This prevents interleaved async reads/writes on the local match queue.
  Future<T> _withMatchLock<T>(Future<T> Function() operation) async {
    // Wait for any previous operation to complete
    while (_matchOperationLock != null) {
      try {
        await _matchOperationLock;
      } catch (_) {
        // Previous operation failed – safe to proceed
      }
    }

    final completer = Completer<void>();
    _matchOperationLock = completer.future;
    try {
      final result = await operation();
      return result;
    } finally {
      _matchOperationLock = null;
      completer.complete();
    }
  }

  // ─── Shared save helpers ──────────────────────────────────

  /// Find a match inside the Gruppenphase by its ID.
  /// Returns the match and its group index, or `null` if not found.
  static (Match match, int groupIndex)? _findGroupPhaseMatch(
    Gruppenphase phase,
    String matchId,
  ) {
    for (int i = 0; i < phase.groups.length; i++) {
      for (final m in phase.groups[i]) {
        if (m.id == matchId) return (m, i);
      }
    }
    return null;
  }

  /// Save knockouts + match queue with automatic rollback on failure.
  /// Pass [rollbackKnockouts] / [rollbackQueue] if mutations happened
  /// before calling this method.
  Future<bool> _saveKnockoutsAndQueue(
    String context, {
    Knockouts? rollbackKnockouts,
    MatchQueue? rollbackQueue,
  }) async {
    final prevKnockouts = rollbackKnockouts ?? _knockouts.clone();
    final prevQueue = rollbackQueue ?? _matchQueue.clone();
    try {
      final s = _firestoreService;
      await s.saveKnockouts(_knockouts, tournamentId: _currentTournamentId);
      await s.saveMatchQueue(_matchQueue, tournamentId: _currentTournamentId);
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error saving $context', tag: 'TournamentData', error: e);
      _knockouts = prevKnockouts;
      _matchQueue = prevQueue;
      return false;
    }
  }

  /// Save gruppenphase + tabellen + match queue with automatic rollback.
  /// Pass [rollbackQueue] / [rollbackTabellen] if mutations happened
  /// before calling this method.
  Future<bool> _saveGroupPhaseAndTables(
    Gruppenphase groupPhase,
    Tabellen tables, {
    bool saveQueue = true,
    MatchQueue? rollbackQueue,
    Tabellen? rollbackTabellen,
  }) async {
    final prevQueue = rollbackQueue ?? _matchQueue.clone();
    final prevTabellen = rollbackTabellen ?? _tabellen.clone();
    try {
      final s = _firestoreService;
      await s.saveGruppenphase(groupPhase, tournamentId: _currentTournamentId);
      await s.saveTabellen(tables, tournamentId: _currentTournamentId);
      if (saveQueue) {
        await s.saveMatchQueue(_matchQueue, tournamentId: _currentTournamentId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('Error saving group phase data',
          tag: 'TournamentData', error: e);
      _matchQueue = prevQueue;
      _tabellen = prevTabellen;
      return false;
    }
  }

  /// Move a match from waiting to playing queue
  Future<bool> startMatch(String matchId) {
    return _withMatchLock(() => _startMatchUnsafe(matchId));
  }

  Future<bool> _startMatchUnsafe(String matchId) async {
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
      final service = _firestoreService;
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
  Future<bool> finishMatch(String matchId, {int? score1, int? score2}) {
    return _withMatchLock(
        () => _finishMatchUnsafe(matchId, score1: score1, score2: score2));
  }

  Future<bool> _finishMatchUnsafe(String matchId,
      {int? score1, int? score2}) async {
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

    // Update scores if provided (from dialog)
    if (score1 != null && score2 != null) {
      match.score1 = score1;
      match.score2 = score2;
      match.done = true;
    }

    // validate score from queue
    Logger.debug(
        'Validating match $matchId: score1=${match.score1} (${match.score1.runtimeType}), score2=${match.score2} (${match.score2.runtimeType})',
        tag: 'TournamentData');
    final points = match.getPoints();
    if (points == null) {
      Logger.warning(
          'Invalid score for match $matchId: ${match.score1}-${match.score2} - not updating standings',
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
    final service = _firestoreService;
    final groupPhase =
        await service.loadGruppenphase(tournamentId: _currentTournamentId);

    if (groupPhase == null) {
      Logger.error('Could not load group phase for match: $matchId',
          tag: 'TournamentData');
      return false;
    }

    final found = _findGroupPhaseMatch(groupPhase, matchId);
    if (found == null) {
      Logger.warning('Match $matchId not found in group phase',
          tag: 'TournamentData');
      return false;
    }

    final (groupPhaseMatch, groupIndex) = found;
    groupPhaseMatch.score1 = match.score1;
    groupPhaseMatch.score2 = match.score2;
    groupPhaseMatch.done = true;

    Logger.info(
      'Updated match $matchId in group $groupIndex: ${match.score1}-${match.score2}',
      tag: 'TournamentData',
    );

    final prevQueue = _matchQueue.clone();
    final prevTabellen = _tabellen.clone();

    _matchQueue.removeFromPlaying(matchId);
    _tabellen = evalGruppen(groupPhase);

    final saved = await _saveGroupPhaseAndTables(
      groupPhase,
      _tabellen,
      rollbackQueue: prevQueue,
      rollbackTabellen: prevTabellen,
    );

    if (saved) {
      // Update local gruppenphase immediately so it reflects the finished
      // match without waiting for the Firestore stream round-trip.
      _gruppenphase = groupPhase;
      _tabellenHash = _computeGruppenphaseHash(groupPhase);
    }
    return saved;
  }

  /// Finish a knockout match
  Future<bool> _finishKnockoutMatch(String matchId, Match match) async {
    Logger.debug('Finishing knockout match: $matchId', tag: 'TournamentData');

    bool findAndUpdateMatch(List<List<Match>> rounds) {
      for (final round in rounds) {
        for (final m in round) {
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

    bool found = findAndUpdateMatch(_knockouts.champions.rounds) ||
        findAndUpdateMatch(_knockouts.europa.rounds) ||
        findAndUpdateMatch(_knockouts.conference.rounds);

    if (!found) {
      for (final m in _knockouts.superCup.matches) {
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

    final prevKnockouts = _knockouts.clone();
    final prevQueue = _matchQueue.clone();

    _matchQueue.removeFromPlaying(matchId);
    _knockouts.update();
    _matchQueue.updateKnockQueue(_knockouts);

    return _saveKnockoutsAndQueue(
      'knockout finish: $matchId',
      rollbackKnockouts: prevKnockouts,
      rollbackQueue: prevQueue,
    );
  }

  /// Transition from group phase to knockout phase
  /// This will evaluate the group standings and populate the knockout structure
  Future<bool> transitionToKnockouts(
      {int? numberOfGroups,
      int tableCount = 6,
      bool splitTables = false}) async {
    try {
      final service = _firestoreService;

      // Load current group phase to calculate standings
      final groupPhase =
          await service.loadGruppenphase(tournamentId: _currentTournamentId);

      if (groupPhase == null) {
        Logger.error('Could not load group phase for knockout transition',
            tag: 'TournamentData');
        return false;
      }

      // Auto-detect number of groups if not provided
      final groupCount = numberOfGroups ?? groupPhase.groups.length;

      Logger.info('Transitioning to knockouts with $groupCount groups',
          tag: 'TournamentData');

      // Calculate final standings
      final tabellen = evalGruppen(groupPhase);

      // Evaluate and create knockouts based on number of groups
      final knockouts = evaluateGroups(tabellen,
          tableCount: tableCount, splitTables: splitTables);

      // Store previous state for rollback
      final previousKnockouts = _knockouts.clone();
      final previousMatchQueue = _matchQueue.clone();
      final previousIsKnockoutMode = _isKnockoutMode;

      // Clear match queue and fill with knockout matches
      _matchQueue = MatchQueue();
      _matchQueue.updateKnockQueue(knockouts);

      Logger.debug('Match queue updated with knockout matches',
          tag: 'TournamentData');

      // Save knockouts and match queue to Firestore
      try {
        await service.saveKnockouts(knockouts,
            tournamentId: _currentTournamentId);
        await service.saveMatchQueue(_matchQueue,
            tournamentId: _currentTournamentId);

        Logger.info(
          'Successfully transitioned to knockouts with $groupCount groups',
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
        // Revert local changes on Firestore save failure
        _knockouts = previousKnockouts;
        _matchQueue = previousMatchQueue;
        _isKnockoutMode = previousIsKnockoutMode;
        Logger.warning('Reverted local changes for knockout transition',
            tag: 'TournamentData');
        return false;
      }
    } catch (e) {
      Logger.error('Error in knockout transition preparation',
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
  }) {
    Logger.info(
      'Editing match $matchId: $newScore1-$newScore2 (knockout: $isKnockout)',
      tag: 'TournamentData',
    );

    if (!isValid(newScore1, newScore2)) {
      Logger.warning(
        'Rejecting invalid scores $newScore1-$newScore2 for match $matchId',
        tag: 'TournamentData',
      );
      return Future.value(false);
    }

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

    try {
      final groupPhase = await _firestoreService.loadGruppenphase(
          tournamentId: _currentTournamentId);
      if (groupPhase == null) {
        Logger.error('Could not load group phase', tag: 'TournamentData');
        return false;
      }

      final result = _findGroupPhaseMatch(groupPhase, matchId);
      if (result == null) return false;
      final (targetMatch, _) = result;

      targetMatch.score1 = newScore1;
      targetMatch.score2 = newScore2;

      final updatedTables = evalGruppen(groupPhase);
      final saved = await _saveGroupPhaseAndTables(groupPhase, updatedTables,
          saveQueue: false);

      if (saved) {
        _gruppenphase = groupPhase;
        _tabellen = updatedTables;
        _tabellenHash = _computeGruppenphaseHash(groupPhase);
      }
      return saved;
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

    // Snapshot BEFORE mutating so we can rollback on failure
    final prevKnockouts = _knockouts.clone();
    final prevQueue = _matchQueue.clone();

    try {
      _knockouts.clearDependentMatches(matchId);

      if (!_knockouts.updateMatchScore(matchId, newScore1, newScore2)) {
        Logger.warning('Match $matchId not found in knockouts',
            tag: 'TournamentData');
        // Revert the clearDependentMatches mutation
        _knockouts = prevKnockouts;
        return false;
      }

      _knockouts.update();
      _matchQueue.updateKnockQueue(_knockouts);

      return _saveKnockoutsAndQueue(
        'knockout edit: $matchId',
        rollbackKnockouts: prevKnockouts,
        rollbackQueue: prevQueue,
      );
    } catch (e) {
      Logger.error('Error editing knockout match',
          tag: 'TournamentData', error: e);
      _knockouts = prevKnockouts;
      _matchQueue = prevQueue;
      return false;
    }
  }

  // ===================== SNAPSHOT RESTORE =====================

  /// Restores the full tournament state from a snapshot and persists it
  /// to Firestore.
  ///
  /// This is the counterpart of [toJson] – it takes the parsed snapshot
  /// fields and writes them into both the local state and Firestore so
  /// they survive a page reload.
  ///
  /// All Firestore writes happen inside a single try/catch so a partial
  /// failure doesn't leave the local state out of sync.
  Future<void> restoreFromSnapshot({
    required List<Team> teams,
    required MatchQueue matchQueue,
    required Gruppenphase gruppenphase,
    required Tabellen tabellen,
    required Knockouts knockouts,
    required bool isKnockoutMode,
    required String tournamentStyle,
    required String? selectedRuleset,
    required String tournamentId,
    int numberOfTables = 6,
    Groups? groups,
  }) async {
    final service = _firestoreService;

    // Determine the phase from the state
    String phase;
    if (teams.isEmpty) {
      phase = 'notStarted';
    } else if (isKnockoutMode) {
      phase = 'knockouts';
    } else {
      phase = 'groups';
    }

    // Persist everything to Firestore – wrap in try/catch so that a
    // partial failure doesn't leave local state corrupted.
    try {
      await service.saveTeams(teams, tournamentId: tournamentId);
      await service.saveGruppenphase(gruppenphase, tournamentId: tournamentId);
      await service.saveMatchQueue(matchQueue, tournamentId: tournamentId);
      await service.saveTabellen(tabellen, tournamentId: tournamentId);
      await service.saveKnockouts(knockouts, tournamentId: tournamentId);

      // Persist group assignments if provided
      if (groups != null && groups.groups.isNotEmpty) {
        await service.saveGroups(groups, tournamentId: tournamentId);
      }

      // Update tournament metadata (including numberOfTables)
      await service.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(tournamentId)
          .set({
        'phase': phase,
        'tournamentStyle': tournamentStyle,
        'selectedRuleset': selectedRuleset,
        'numberOfTables': numberOfTables,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Logger.error('Error persisting snapshot to Firestore',
          tag: 'TournamentData', error: e);
      rethrow;
    }

    // Update local state only after all Firestore writes succeed
    _teams = teams;
    _rebuildTeamCache();
    _matchQueue = matchQueue;
    _gruppenphase = gruppenphase;
    _tabellen = tabellen;
    _knockouts = knockouts;
    _currentTournamentId = tournamentId;
    _isKnockoutMode = isKnockoutMode;
    _tournamentStyle = tournamentStyle;
    _selectedRuleset = selectedRuleset;
    _tabellenHash = _computeGruppenphaseHash(gruppenphase);

    _setupStreams();

    Logger.info(
      'Restored snapshot: ${teams.length} teams, style=$tournamentStyle, knockoutMode=$isKnockoutMode',
      tag: 'TournamentData',
    );

    notifyListeners();
  }

  /// Convert the tournament state to JSON
  Map<String, dynamic> toJson() {
    return {
      'teams': _teams.map((team) => team.toJson()).toList(),
      'matchQueue': _matchQueue.toJson(),
      'gruppenphase': _gruppenphase.toJson(),
      'tabellen': _tabellen.toJson(),
      'knockouts': _knockouts.toJson(),
      'currentTournamentId': _currentTournamentId,
      'isKnockoutMode': _isKnockoutMode,
      'tournamentStyle': _tournamentStyle,
      'selectedRuleset': _selectedRuleset,
    };
  }
}
