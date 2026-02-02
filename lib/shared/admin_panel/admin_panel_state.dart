import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';

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

  /// Load teams from Firebase
  Future<void> loadTeams() async {
    _setLoading(true);
    _clearError();

    try {
      final loadedTeams =
          await _firestoreService.loadTeams(tournamentId: _currentTournamentId);
      if (loadedTeams != null) {
        _teams = loadedTeams;
      } else {
        _teams = [];
      }
      notifyListeners();
    } catch (e) {
      _setError('Fehler beim Laden der Teams: $e');
      debugPrint('Error loading teams: $e');
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
      } else {
        _groups = Groups();
        _groupsAssigned = false;
      }
      notifyListeners();
    } catch (e) {
      _setError('Fehler beim Laden der Gruppen: $e');
      debugPrint('Error loading groups: $e');
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
      debugPrint('Team "${newTeam.name}" saved to Firebase');
      return true;
    } catch (e) {
      // Rollback: remove the team from local list
      _teams.removeWhere((t) => t.id == newTeam.id);
      _setError('Fehler beim Speichern: $e');
      debugPrint('Error saving team, rolling back: $e');
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
      debugPrint('Team "$name" updated in Firebase');
      return true;
    } catch (e) {
      // Rollback
      _teams[index] = previousTeam;
      _setError('Fehler beim Aktualisieren: $e');
      debugPrint('Error updating team, rolling back: $e');
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
      debugPrint('Team "${deletedTeam.name}" deleted from Firebase');
      return true;
    } catch (e) {
      // Rollback
      _teams.insert(index, deletedTeam);
      _groups = previousGroups;
      _setError('Fehler beim Löschen: $e');
      debugPrint('Error deleting team, rolling back: $e');
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
      debugPrint('Groups assigned randomly and saved to Firebase');
      return true;
    } catch (e) {
      // Rollback
      _groups = previousGroups;
      _groupsAssigned = previousAssigned;
      _setError('Fehler beim Speichern der Gruppen: $e');
      debugPrint('Error saving groups, rolling back: $e');
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
      debugPrint('Team assigned to group $groupIndex');
      return true;
    } catch (e) {
      _groups = previousGroups;
      _setError('Fehler beim Zuweisen: $e');
      debugPrint('Error assigning team to group, rolling back: $e');
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
      debugPrint('Group assignments cleared');
      return true;
    } catch (e) {
      _groups = previousGroups;
      _groupsAssigned = previousAssigned;
      _setError('Fehler beim Löschen der Gruppen: $e');
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

  // Placeholder methods for future functionality
  void startTournament() {
    // TODO: Implement tournament start logic
    debugPrint('Starting tournament...');
  }

  void advancePhase() {
    // TODO: Implement phase advancement logic
    debugPrint('Advancing to next phase...');
  }

  void shuffleMatches() {
    // TODO: Implement match shuffling logic
    debugPrint('Shuffling matches...');
  }

  void importFromJson() {
    // TODO: Implement JSON import logic
    debugPrint('Importing from JSON...');
  }

  void exportToJson() {
    // TODO: Implement JSON export logic
    debugPrint('Exporting to JSON...');
  }
}
