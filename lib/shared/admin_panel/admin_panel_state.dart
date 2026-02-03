import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/app_logger.dart';

/// Tournament phase enum
enum TournamentPhase {
  notStarted,
  groupPhase,
  knockoutPhase,
  finished,
}

/// Tournament style enum
enum TournamentStyle {
  groupsAndKnockouts,
  knockoutsOnly,
  everyoneVsEveryone,
}

/// Admin panel state management with Firebase integration
class AdminPanelState extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Tournament info
  String _currentTournamentId = FirestoreBase.defaultTournamentId;

  // Tournament status
  TournamentPhase _currentPhase = TournamentPhase.notStarted;
  TournamentStyle _tournamentStyle = TournamentStyle.groupsAndKnockouts;

  // Teams management
  List<Team> _teams = [];

  // Groups management
  Groups _groups = Groups();
  bool _groupsAssigned = false;
  int _numberOfGroups = 6; // Default number of groups (only 6 implemented)

  // Match statistics
  int _totalMatches = 0;
  int _completedMatches = 0;
  int _remainingMatches = 0;

  // Loading/error states
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String get currentTournamentId => _currentTournamentId;
  TournamentPhase get currentPhase => _currentPhase;
  TournamentStyle get tournamentStyle => _tournamentStyle;
  List<Team> get teams => List.unmodifiable(_teams);
  Groups get groups => _groups;
  bool get groupsAssigned => _groupsAssigned;
  int get numberOfGroups => _numberOfGroups;
  int get totalTeams => _teams.length;
  int get totalMatches => _totalMatches;
  int get completedMatches => _completedMatches;
  int get remainingMatches => _remainingMatches;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTournamentStarted => _currentPhase != TournamentPhase.notStarted;
  bool get isTournamentFinished => _currentPhase == TournamentPhase.finished;

  /// Count of teams that are assigned to groups
  int get teamsInGroupsCount {
    int count = 0;
    for (var group in _groups.groups) {
      count += group.length;
    }
    return count;
  }

  /// Check if groups need to be assigned before starting
  bool get needsGroupAssignment =>
      _tournamentStyle == TournamentStyle.groupsAndKnockouts &&
      !_groupsAssigned;

  /// Check if the tournament can be started
  bool get canStartTournament {
    if (_teams.isEmpty) return false;
    if (isTournamentStarted) return false;

    // For group phase tournaments, groups must be assigned
    if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
      return _groupsAssigned && _validateGroupAssignment();
    }

    return true;
  }

  /// Get validation message for why tournament can't start
  String? get startValidationMessage {
    if (_teams.isEmpty) {
      return 'Es müssen mindestens Teams registriert sein.';
    }
    if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
      if (!_groupsAssigned) {
        return 'Gruppen müssen vor dem Start zugewiesen werden.';
      }
      if (!_validateGroupAssignment()) {
        return 'Nicht alle Teams sind einer Gruppe zugewiesen.';
      }
    }
    return null;
  }

  // Phase display name
  String get phaseDisplayName {
    switch (_currentPhase) {
      case TournamentPhase.notStarted:
        return 'Nicht gestartet';
      case TournamentPhase.groupPhase:
        return 'Gruppenphase';
      case TournamentPhase.knockoutPhase:
        return 'K.O.-Phase';
      case TournamentPhase.finished:
        return 'Beendet';
    }
  }

  // Tournament style display name
  String get styleDisplayName {
    switch (_tournamentStyle) {
      case TournamentStyle.groupsAndKnockouts:
        return 'Gruppenphase + K.O.';
      case TournamentStyle.knockoutsOnly:
        return 'Nur K.O.-Phase';
      case TournamentStyle.everyoneVsEveryone:
        return 'Jeder gegen Jeden';
    }
  }

  /// Initialize with tournament ID
  void setTournamentId(String tournamentId) {
    _currentTournamentId = tournamentId;
    notifyListeners();
  }

  /// Load tournament metadata (phase, etc.) from Firebase
  Future<void> loadTournamentMetadata() async {
    _setLoading(true);
    _clearError();

    try {
      final metadata = await _firestoreService.getTournamentMetadata(
          tournamentId: _currentTournamentId);
      if (metadata != null) {
        final phase = metadata['phase'] as String?;
        if (phase != null) {
          switch (phase) {
            case 'groups':
              _currentPhase = TournamentPhase.groupPhase;
              break;
            case 'knockouts':
              _currentPhase = TournamentPhase.knockoutPhase;
              break;
            case 'finished':
              _currentPhase = TournamentPhase.finished;
              break;
            default:
              _currentPhase = TournamentPhase.notStarted;
          }
        }
        Logger.info('Loaded tournament phase: $_currentPhase',
            tag: 'AdminPanel');
      }
      notifyListeners();
    } catch (e) {
      _setError('Fehler beim Laden der Turnierdaten: $e');
      Logger.error('Error loading tournament metadata',
          tag: 'AdminPanel', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Load teams from Firebase
  Future<void> loadTeams() async {
    _setLoading(true);
    _clearError();

    try {
      final loadedTeams =
          await _firestoreService.loadTeams(tournamentId: _currentTournamentId);
      if (loadedTeams != null) {
        _teams = loadedTeams;
        Logger.debug('Loaded ${_teams.length} teams', tag: 'AdminPanel');
      } else {
        _teams = [];
      }
      notifyListeners();
    } catch (e) {
      _setError('Fehler beim Laden der Teams: $e');
      Logger.error('Error loading teams', tag: 'AdminPanel', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Load groups from Firebase
  Future<void> loadGroups() async {
    _setLoading(true);
    _clearError();

    try {
      final loadedGroups = await _firestoreService.loadGroups(
          tournamentId: _currentTournamentId);
      if (loadedGroups != null) {
        _groups = loadedGroups;
        _groupsAssigned = _groups.groups.isNotEmpty;
        // Always use 6 groups (only implemented option)
        _numberOfGroups = 6;
        Logger.debug('Loaded ${_groups.groups.length} groups',
            tag: 'AdminPanel');
      } else {
        _groups = Groups();
        _groupsAssigned = false;
      }
      notifyListeners();
    } catch (e) {
      _setError('Fehler beim Laden der Gruppen: $e');
      Logger.error('Error loading groups', tag: 'AdminPanel', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Add a new team with Firebase sync and rollback support
  Future<bool> addTeam({
    required String name,
    required String member1,
    required String member2,
  }) async {
    if (isTournamentStarted) {
      _setError(
          'Teams können nach Turnierstart nicht mehr hinzugefügt werden.');
      return false;
    }

    _setLoading(true);
    _clearError();

    // Create new team with unique ID
    final newTeam = Team(
      id: _generateTeamId(),
      name: name,
      mem1: member1,
      mem2: member2,
    );

    // Add to local list first (optimistic update)
    _teams.add(newTeam);
    notifyListeners();

    try {
      // Save to Firebase
      await _firestoreService.saveTeams(_teams,
          tournamentId: _currentTournamentId);
      Logger.info('Team "${newTeam.name}" saved to Firebase',
          tag: 'AdminPanel');
      return true;
    } catch (e) {
      // Rollback: remove the team from local list
      _teams.removeWhere((t) => t.id == newTeam.id);
      _setError('Fehler beim Speichern: $e');
      Logger.error('Error saving team, rolling back',
          tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing team
  Future<bool> updateTeam({
    required String teamId,
    required String name,
    required String member1,
    required String member2,
  }) async {
    _setLoading(true);
    _clearError();

    // Find and store previous state for rollback
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index == -1) {
      _setError('Team nicht gefunden.');
      _setLoading(false);
      return false;
    }

    final previousTeam = Team(
      id: _teams[index].id,
      name: _teams[index].name,
      mem1: _teams[index].mem1,
      mem2: _teams[index].mem2,
    );

    // Update locally (optimistic update)
    _teams[index] = Team(
      id: teamId,
      name: name,
      mem1: member1,
      mem2: member2,
    );
    notifyListeners();

    try {
      // Save to Firebase
      await _firestoreService.saveTeams(_teams,
          tournamentId: _currentTournamentId);
      Logger.info('Team "$name" updated in Firebase', tag: 'AdminPanel');
      return true;
    } catch (e) {
      // Rollback
      _teams[index] = previousTeam;
      _setError('Fehler beim Aktualisieren: $e');
      Logger.error('Error updating team, rolling back',
          tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a team
  Future<bool> deleteTeam(String teamId) async {
    if (isTournamentStarted) {
      _setError('Teams können nach Turnierstart nicht mehr gelöscht werden.');
      return false;
    }

    _setLoading(true);
    _clearError();

    // Store for rollback
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index == -1) {
      _setError('Team nicht gefunden.');
      _setLoading(false);
      return false;
    }

    final deletedTeam = _teams[index];

    // Remove locally (optimistic update)
    _teams.removeAt(index);

    // Also remove from groups if assigned
    final previousGroups = Groups(
      groups: _groups.groups.map((g) => List<String>.from(g)).toList(),
    );
    for (var group in _groups.groups) {
      group.remove(teamId);
    }
    notifyListeners();

    try {
      // Save to Firebase
      await _firestoreService.saveTeams(_teams,
          tournamentId: _currentTournamentId);
      if (_groupsAssigned) {
        await _firestoreService.saveGroups(_groups,
            tournamentId: _currentTournamentId);
      }
      Logger.info('Team "${deletedTeam.name}" deleted from Firebase',
          tag: 'AdminPanel');
      return true;
    } catch (e) {
      // Rollback
      _teams.insert(index, deletedTeam);
      _groups = previousGroups;
      _setError('Fehler beim Löschen: $e');
      Logger.error('Error deleting team, rolling back',
          tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Assign teams to groups randomly
  Future<bool> assignGroupsRandomly({int? numberOfGroups}) async {
    if (_teams.isEmpty) {
      _setError('Keine Teams zum Zuweisen vorhanden.');
      return false;
    }

    _setLoading(true);
    _clearError();

    final groupCount = numberOfGroups ?? _numberOfGroups;

    // Shuffle teams randomly
    final shuffledTeamIds = _teams.map((t) => t.id).toList()..shuffle(Random());

    // Create empty groups
    final newGroups = List.generate(groupCount, (_) => <String>[]);

    // Distribute teams evenly across groups
    for (int i = 0; i < shuffledTeamIds.length; i++) {
      newGroups[i % groupCount].add(shuffledTeamIds[i]);
    }

    // Store previous state for rollback
    final previousGroups = _groups;
    final previousAssigned = _groupsAssigned;

    // Update locally
    _groups = Groups(groups: newGroups);
    _groupsAssigned = true;
    _numberOfGroups = groupCount;
    notifyListeners();

    try {
      // Save to Firebase
      await _firestoreService.saveGroups(_groups,
          tournamentId: _currentTournamentId);
      Logger.info('Groups assigned randomly and saved to Firebase',
          tag: 'AdminPanel');
      return true;
    } catch (e) {
      // Rollback
      _groups = previousGroups;
      _groupsAssigned = previousAssigned;
      _setError('Fehler beim Speichern der Gruppen: $e');
      Logger.error('Error saving groups, rolling back',
          tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Assign a team to a specific group manually
  Future<bool> assignTeamToGroup(String teamId, int groupIndex) async {
    if (groupIndex < 0 || groupIndex >= _numberOfGroups) {
      _setError('Ungültiger Gruppenindex.');
      return false;
    }

    _setLoading(true);
    _clearError();

    // Initialize groups if not already
    if (_groups.groups.isEmpty) {
      _groups = Groups(
        groups: List.generate(_numberOfGroups, (_) => <String>[]),
      );
    }

    // Store previous state
    final previousGroups = Groups(
      groups: _groups.groups.map((g) => List<String>.from(g)).toList(),
    );

    // Remove team from any existing group
    for (var group in _groups.groups) {
      group.remove(teamId);
    }

    // Add to new group
    _groups.groups[groupIndex].add(teamId);
    _groupsAssigned = true;
    notifyListeners();

    try {
      await _firestoreService.saveGroups(_groups,
          tournamentId: _currentTournamentId);
      Logger.debug('Team assigned to group $groupIndex', tag: 'AdminPanel');
      return true;
    } catch (e) {
      _groups = previousGroups;
      _setError('Fehler beim Zuweisen: $e');
      Logger.error('Error assigning team to group, rolling back',
          tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get the group index for a team (-1 if not assigned)
  int getTeamGroupIndex(String teamId) {
    for (int i = 0; i < _groups.groups.length; i++) {
      if (_groups.groups[i].contains(teamId)) {
        return i;
      }
    }
    return -1;
  }

  /// Set number of groups
  void setNumberOfGroups(int count) {
    if (count > 0 && count <= 8) {
      _numberOfGroups = count;
      notifyListeners();
    }
  }

  /// Clear all group assignments
  Future<bool> clearGroupAssignments() async {
    _setLoading(true);
    _clearError();

    final previousGroups = _groups;
    final previousAssigned = _groupsAssigned;

    _groups = Groups();
    _groupsAssigned = false;
    notifyListeners();

    try {
      await _firestoreService.saveGroups(_groups,
          tournamentId: _currentTournamentId);
      Logger.info('Group assignments cleared', tag: 'AdminPanel');
      return true;
    } catch (e) {
      _groups = previousGroups;
      _groupsAssigned = previousAssigned;
      _setError('Fehler beim Löschen der Gruppen: $e');
      Logger.error('Error clearing groups', tag: 'AdminPanel', error: e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Validate that all teams are assigned to a group
  bool _validateGroupAssignment() {
    if (_groups.groups.isEmpty) return false;

    final assignedTeamIds = <String>{};
    for (var group in _groups.groups) {
      assignedTeamIds.addAll(group);
    }

    return _teams.every((team) => assignedTeamIds.contains(team.id));
  }

  /// Set tournament phase
  void setPhase(TournamentPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  /// Set tournament style
  void setTournamentStyle(TournamentStyle style) {
    if (!isTournamentStarted) {
      _tournamentStyle = style;
      // Clear group assignments if switching away from group phase
      if (style != TournamentStyle.groupsAndKnockouts) {
        _groupsAssigned = false;
      }
      notifyListeners();
    }
  }

  /// Update match statistics
  void updateMatchStats({
    int? total,
    int? completed,
  }) {
    if (total != null) _totalMatches = total;
    if (completed != null) _completedMatches = completed;
    _remainingMatches = _totalMatches - _completedMatches;
    notifyListeners();
  }

  /// Generate a unique team ID
  String _generateTeamId() {
    return 'team_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  // Loading state helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear error message
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Start the tournament - creates Gruppenphase, MatchQueue and saves to Firebase
  Future<bool> startTournament() async {
    if (!canStartTournament) {
      _setError(
          startValidationMessage ?? 'Turnier kann nicht gestartet werden.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Use initializeTournament which creates all necessary structures
      await _firestoreService.initializeTournament(
        _teams,
        _groups,
        tournamentId: _currentTournamentId,
      );

      // Calculate total matches for group phase (6 matches per group × 6 groups = 36)
      _totalMatches = _numberOfGroups *
          6; // Each group has 6 matches (round robin of 4 teams)
      _completedMatches = 0;
      _remainingMatches = _totalMatches;

      // Set phase to group phase
      _currentPhase = TournamentPhase.groupPhase;

      Logger.info(
          'Tournament started successfully with ${_teams.length} teams in $_numberOfGroups groups',
          tag: 'AdminPanel');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Fehler beim Starten des Turniers: $e');
      Logger.error('Error starting tournament', tag: 'AdminPanel', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Advance to the next tournament phase (only group → knockout)
  Future<bool> advancePhase() async {
    if (_currentPhase == TournamentPhase.notStarted) {
      _setError('Turnier muss zuerst gestartet werden.');
      return false;
    }

    if (_currentPhase != TournamentPhase.groupPhase) {
      _setError(
          'Phasenwechsel ist nur von der Gruppenphase zur K.O.-Phase möglich.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Transition from group phase to knockout phase
      await _firestoreService.transitionToKnockouts(
        tournamentId: _currentTournamentId,
        numberOfGroups: _numberOfGroups,
      );

      _currentPhase = TournamentPhase.knockoutPhase;
      Logger.info('Advanced to knockout phase', tag: 'AdminPanel');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Fehler beim Phasenwechsel: $e');
      Logger.error('Error advancing phase', tag: 'AdminPanel', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset the tournament (dangerous - deletes all progress but keeps teams and groups)
  Future<bool> resetTournament() async {
    _setLoading(true);
    _clearError();

    try {
      // Reset tournament data in Firebase (keeps teams and groups, resets matches)
      await _firestoreService.resetTournament(
          tournamentId: _currentTournamentId);

      // Reset local state
      _currentPhase = TournamentPhase.notStarted;
      _totalMatches = 0;
      _completedMatches = 0;
      _remainingMatches = 0;

      Logger.info('Tournament reset successfully', tag: 'AdminPanel');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Fehler beim Zurücksetzen: $e');
      Logger.error('Error resetting tournament', tag: 'AdminPanel', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void shuffleMatches() {
    // TODO: Implement match shuffling logic
    Logger.debug('Shuffling matches...', tag: 'AdminPanel');
  }

  void importFromJson() {
    // TODO: Implement JSON import logic
    Logger.debug('Importing from JSON...', tag: 'AdminPanel');
  }

  void exportToJson() {
    // TODO: Implement JSON export logic
    Logger.debug('Exporting to JSON...', tag: 'AdminPanel');
  }
}
