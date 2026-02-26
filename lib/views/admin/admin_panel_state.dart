import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/models/tournament_enums.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/app_logger.dart';

export 'package:pongstrong/models/tournament_enums.dart';

/// Admin panel state management with Firebase integration
class AdminPanelState extends ChangeNotifier {
  final FirestoreService _firestoreService;
  bool _disposed = false;

  /// Creates an [AdminPanelState].
  ///
  /// [firestoreService] is optional – production code omits it and the shared
  /// singleton is used.  Pass [FirestoreService.forTesting] in unit tests.
  AdminPanelState({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  // Tournament info
  String _currentTournamentId = FirestoreBase.defaultTournamentId;
  String _tournamentName = '';

  // Tournament status
  TournamentPhase _currentPhase = TournamentPhase.notStarted;
  TournamentStyle _tournamentStyle = TournamentStyle.groupsAndKnockouts;

  // Teams management
  List<Team> _teams = [];

  // Groups management
  Groups _groups = Groups();
  bool _groupsAssigned = false;
  int _numberOfGroups = 6;
  int _numberOfTables = 6;

  // Selected team count for KO-only and round-robin modes
  // (controls how many of the saved teams are used when starting)
  int _targetTeamCount = 8;
  // Remembers the last KO bracket size so it survives mode switches
  int _koTargetTeamCount = 8;

  // Rules configuration
  String? _selectedRuleset = 'bmt-cup';

  // Reserve (bench) team IDs – persisted in tournament metadata
  Set<String> _reserveTeamIds = {};

  // Match statistics
  int _totalMatches = 0;
  int _completedMatches = 0;
  int _remainingMatches = 0;

  // Loading/error states
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String get currentTournamentId => _currentTournamentId;
  String get tournamentName => _tournamentName;
  TournamentPhase get currentPhase => _currentPhase;
  TournamentStyle get tournamentStyle => _tournamentStyle;
  List<Team> get teams => List.unmodifiable(_teams);
  Groups get groups => _groups;
  bool get groupsAssigned => _groupsAssigned;
  int get numberOfGroups => _numberOfGroups;
  int get numberOfTables => _numberOfTables;
  int get totalTeams => _teams.length;
  int get activeTeamCount =>
      _teams.where((t) => !_reserveTeamIds.contains(t.id)).length;
  int get targetTeamCount => _targetTeamCount;
  int get totalMatches => _totalMatches;
  int get completedMatches => _completedMatches;
  int get remainingMatches => _remainingMatches;
  bool get rulesEnabled => _selectedRuleset != null;
  String? get selectedRuleset => _selectedRuleset;
  Set<String> get reserveTeamIds => Set.unmodifiable(_reserveTeamIds);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTournamentStarted => _currentPhase != TournamentPhase.notStarted;
  bool get isTournamentFinished => _currentPhase == TournamentPhase.finished;

  int get teamsInGroupsCount {
    int count = 0;
    for (final group in _groups.groups) {
      count += group.length;
    }
    return count;
  }

  bool get needsGroupAssignment =>
      _tournamentStyle == TournamentStyle.groupsAndKnockouts &&
      !_groupsAssigned;

  bool get canStartTournament {
    if (_teams.isEmpty) return false;
    if (isTournamentStarted) return false;
    if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
      return _groupsAssigned && _validateGroupAssignment();
    }
    if (_tournamentStyle == TournamentStyle.knockoutsOnly) {
      final validCounts = [8, 16, 32, 64];
      return validCounts.contains(_targetTeamCount) &&
          _teams.length >= _targetTeamCount;
    }
    if (_tournamentStyle == TournamentStyle.everyoneVsEveryone) {
      return _teams.length >= 2;
    }
    return true;
  }

  String? get startValidationMessage {
    if (_teams.isEmpty) {
      return 'Es müssen mindestens Teams registriert sein.';
    }
    if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
      if (!_groupsAssigned) {
        return 'Gruppen müssen vor dem Start zugewiesen werden.';
      }
      if (!_validateGroupAssignment()) {
        final needed = _numberOfGroups * 4;
        final assigned =
            _groups.groups.fold<int>(0, (total, g) => total + g.length);
        if (_groups.groups.length != _numberOfGroups) {
          return 'Es werden $_numberOfGroups Gruppen benötigt, aber ${_groups.groups.length} sind vorhanden.';
        }
        return 'Es müssen genau $needed Teams auf $_numberOfGroups Gruppen verteilt sein ($assigned aktuell zugewiesen).';
      }
    }
    if (_tournamentStyle == TournamentStyle.knockoutsOnly) {
      final validCounts = [8, 16, 32, 64];
      if (!validCounts.contains(_targetTeamCount)) {
        return 'Für die K.O.-Phase werden 8, 16, 32 oder 64 Teams benötigt (gewählt: $_targetTeamCount).';
      }
      if (_teams.length < _targetTeamCount) {
        return 'Es sind nur ${_teams.length} Teams vorhanden, aber $_targetTeamCount gewählt.';
      }
    }
    if (_tournamentStyle == TournamentStyle.everyoneVsEveryone) {
      if (_teams.length < 2) {
        return 'Es werden mindestens 2 Teams für Jeder gegen Jeden benötigt.';
      }
    }
    return null;
  }

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

  void setTournamentId(String tournamentId) {
    _currentTournamentId = tournamentId;
    notifyListeners();
  }

  Future<void> loadTournamentMetadata() async {
    _setLoading(true);
    _clearError();
    try {
      final metadata = await _firestoreService.getTournamentMetadata(
          tournamentId: _currentTournamentId);
      if (metadata != null) {
        _tournamentName = (metadata['name'] as String?) ?? '';
        final phase = metadata['phase'] as String?;
        if (phase != null) {
          switch (phase) {
            case 'groups':
              _currentPhase = TournamentPhase.groupPhase;
            case 'knockouts':
              _currentPhase = TournamentPhase.knockoutPhase;
            case 'finished':
              _currentPhase = TournamentPhase.finished;
            default:
              _currentPhase = TournamentPhase.notStarted;
          }
        }
        // Load tournament style from metadata
        final styleStr = metadata['tournamentStyle'] as String?;
        if (styleStr != null) {
          switch (styleStr) {
            case 'knockoutsOnly':
              _tournamentStyle = TournamentStyle.knockoutsOnly;
            case 'everyoneVsEveryone':
              _tournamentStyle = TournamentStyle.everyoneVsEveryone;
            default:
              _tournamentStyle = TournamentStyle.groupsAndKnockouts;
          }
        }
        // Load rules setting from metadata
        if (metadata.containsKey('selectedRuleset')) {
          _selectedRuleset = metadata['selectedRuleset'] as String?;
        } else {
          _selectedRuleset = 'bmt-cup';
        }

        // Load number of tables from metadata
        if (metadata.containsKey('numberOfTables')) {
          _numberOfTables = (metadata['numberOfTables'] as num).toInt();
          if (_numberOfTables < 1) _numberOfTables = 6;
        }

        // Load target team count (persisted for KO-only mode)
        if (metadata.containsKey('targetTeamCount')) {
          final tc = (metadata['targetTeamCount'] as num).toInt();
          _targetTeamCount = tc;
          if (_tournamentStyle == TournamentStyle.knockoutsOnly) {
            _koTargetTeamCount = tc;
          }
        }

        // Load reserve (bench) team IDs from metadata
        if (metadata.containsKey('reserveTeamIds')) {
          final reserveList = metadata['reserveTeamIds'];
          if (reserveList is List) {
            _reserveTeamIds = reserveList.cast<String>().toSet();
          }
        } else {
          _reserveTeamIds = {};
        }

        Logger.info(
            'Loaded tournament phase: $_currentPhase, style: $_tournamentStyle',
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

  Future<void> loadGroups() async {
    _setLoading(true);
    _clearError();
    try {
      final loadedGroups = await _firestoreService.loadGroups(
          tournamentId: _currentTournamentId);
      if (loadedGroups != null) {
        _groups = loadedGroups;
        _groupsAssigned = _groups.groups.isNotEmpty;
        // Sync group count from saved data (initial load / reload)
        if (_groups.groups.isNotEmpty) {
          _numberOfGroups = _groups.groups.length.clamp(2, 10);
          if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
            _targetTeamCount = _numberOfGroups * 4;
          }
        }
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

  /// Load and calculate match statistics for the current phase only
  Future<void> loadMatchStats() async {
    try {
      int totalMatches = 0;
      int completedMatches = 0;

      if (_currentPhase == TournamentPhase.knockoutPhase) {
        // In KO phase: only count knockout matches
        final knockouts = await _firestoreService.loadKnockouts(
            tournamentId: _currentTournamentId);
        if (knockouts != null) {
          for (final round in knockouts.champions.rounds) {
            for (final match in round) {
              totalMatches++;
              if (match.done) completedMatches++;
            }
          }
          for (final round in knockouts.europa.rounds) {
            for (final match in round) {
              totalMatches++;
              if (match.done) completedMatches++;
            }
          }
          for (final round in knockouts.conference.rounds) {
            for (final match in round) {
              totalMatches++;
              if (match.done) completedMatches++;
            }
          }
          for (final match in knockouts.superCup.matches) {
            totalMatches++;
            if (match.done) completedMatches++;
          }
        }
      } else {
        // In group phase (or other phases): only count group matches
        final gruppenphase = await _firestoreService.loadGruppenphase(
            tournamentId: _currentTournamentId);
        if (gruppenphase != null) {
          for (final group in gruppenphase.groups) {
            totalMatches += group.length;
            completedMatches += group.where((m) => m.done).length;
          }
        }
      }

      _totalMatches = totalMatches;
      _completedMatches = completedMatches;
      _remainingMatches = totalMatches - completedMatches;

      Logger.debug(
          'Match stats loaded: $completedMatches/$totalMatches completed',
          tag: 'AdminPanel');
      notifyListeners();
    } catch (e) {
      Logger.error('Error loading match stats', tag: 'AdminPanel', error: e);
    }
  }

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
    final newTeam = Team(
      id: _generateTeamId(),
      name: name,
      member1: member1,
      member2: member2,
    );
    _teams.add(newTeam);
    notifyListeners();
    try {
      await _firestoreService.saveTeams(_teams,
          tournamentId: _currentTournamentId);
      Logger.info('Team "${newTeam.name}" saved to Firebase',
          tag: 'AdminPanel');
      return true;
    } catch (e) {
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

  Future<bool> updateTeam({
    required String teamId,
    required String name,
    required String member1,
    required String member2,
  }) async {
    _setLoading(true);
    _clearError();
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index == -1) {
      _setError('Team nicht gefunden.');
      _setLoading(false);
      return false;
    }
    final previousTeam = Team(
      id: _teams[index].id,
      name: _teams[index].name,
      member1: _teams[index].member1,
      member2: _teams[index].member2,
    );
    _teams[index] =
        Team(id: teamId, name: name, member1: member1, member2: member2);
    notifyListeners();
    try {
      await _firestoreService.saveTeams(_teams,
          tournamentId: _currentTournamentId);
      Logger.info('Team "$name" updated in Firebase', tag: 'AdminPanel');
      return true;
    } catch (e) {
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

  Future<bool> deleteTeam(String teamId) async {
    if (isTournamentStarted) {
      _setError('Teams können nach Turnierstart nicht mehr gelöscht werden.');
      return false;
    }
    _setLoading(true);
    _clearError();
    final index = _teams.indexWhere((t) => t.id == teamId);
    if (index == -1) {
      _setError('Team nicht gefunden.');
      _setLoading(false);
      return false;
    }
    final deletedTeam = _teams[index];
    _teams.removeAt(index);
    final previousGroups = Groups(
      groups: _groups.groups.map((g) => List<String>.from(g)).toList(),
    );
    for (final group in _groups.groups) {
      group.remove(teamId);
    }
    notifyListeners();
    try {
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

  Future<bool> assignGroupsRandomly({int? numberOfGroups}) async {
    if (_teams.isEmpty) {
      _setError('Keine Teams zum Zuweisen vorhanden.');
      return false;
    }
    _setLoading(true);
    _clearError();
    final groupCount = numberOfGroups ?? _numberOfGroups;
    final teamsNeeded = groupCount * 4;
    // Exclude reserve (bench) teams from group assignment
    final eligibleIds = _teams
        .where((t) => !_reserveTeamIds.contains(t.id))
        .map((t) => t.id)
        .toList()
      ..shuffle(Random());
    final selectedTeams = eligibleIds.take(teamsNeeded).toList();
    final newGroups = List.generate(groupCount, (_) => <String>[]);
    for (int i = 0; i < selectedTeams.length; i++) {
      newGroups[i % groupCount].add(selectedTeams[i]);
    }
    final previousGroups = _groups;
    final previousAssigned = _groupsAssigned;
    _groups = Groups(groups: newGroups);
    _groupsAssigned = true;
    _numberOfGroups = groupCount;
    notifyListeners();
    try {
      await _firestoreService.saveGroups(_groups,
          tournamentId: _currentTournamentId);
      Logger.info('Groups assigned randomly and saved to Firebase',
          tag: 'AdminPanel');
      return true;
    } catch (e) {
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

  /// Reorder teams so that active (tournament) teams come first in the list.
  /// This ensures `_teams.take(targetTeamCount)` selects the correct teams
  /// when starting a KO-only tournament.
  Future<void> reorderTeams(Set<String> activeTeamIds) async {
    final activeTeams = <Team>[];
    final reserveTeams = <Team>[];
    for (final team in _teams) {
      if (activeTeamIds.contains(team.id)) {
        activeTeams.add(team);
      } else {
        reserveTeams.add(team);
      }
    }
    final reordered = [...activeTeams, ...reserveTeams];
    if (_teams.length == reordered.length) {
      _teams = reordered;
      try {
        await _firestoreService.saveTeams(_teams,
            tournamentId: _currentTournamentId);
        Logger.debug(
            'Teams reordered: ${activeTeams.length} active, ${reserveTeams.length} reserve',
            tag: 'AdminPanel');
      } catch (e) {
        Logger.error('Error reordering teams', tag: 'AdminPanel', error: e);
      }
      notifyListeners();
    }
  }

  /// Shuffle groups locally without saving to Firebase.
  /// Returns a map of teamId -> groupIndex for the caller to apply.
  /// The caller is responsible for saving via the normal save flow.
  Map<String, int>? shuffleGroupsLocally({int? numberOfGroups}) {
    if (_teams.isEmpty) return null;
    final groupCount = numberOfGroups ?? _numberOfGroups;
    final teamsNeeded = groupCount * 4;
    // Exclude reserve (bench) teams from group shuffle
    final eligibleIds = _teams
        .where((t) => !_reserveTeamIds.contains(t.id))
        .map((t) => t.id)
        .toList()
      ..shuffle(Random());
    final selectedTeams = eligibleIds.take(teamsNeeded).toList();
    final result = <String, int>{};
    for (int i = 0; i < selectedTeams.length; i++) {
      result[selectedTeams[i]] = i % groupCount;
    }
    return result;
  }

  Future<bool> assignTeamToGroup(String teamId, int groupIndex) async {
    if (groupIndex < 0 || groupIndex >= _numberOfGroups) {
      _setError('Ungültiger Gruppenindex.');
      return false;
    }
    _setLoading(true);
    _clearError();
    if (_groups.groups.isEmpty) {
      _groups = Groups(
        groups: List.generate(_numberOfGroups, (_) => <String>[]),
      );
    }
    final previousGroups = Groups(
      groups: _groups.groups.map((g) => List<String>.from(g)).toList(),
    );
    for (final group in _groups.groups) {
      group.remove(teamId);
    }
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

  /// Remove a team from whichever group it is in (if any) and persist.
  Future<bool> removeTeamFromGroup(String teamId) async {
    if (_groups.groups.isEmpty) return true;
    bool found = false;
    for (final group in _groups.groups) {
      if (group.remove(teamId)) found = true;
    }
    if (!found) return true; // nothing to do
    notifyListeners();
    try {
      await _firestoreService.saveGroups(_groups,
          tournamentId: _currentTournamentId);
      Logger.debug('Team $teamId removed from group', tag: 'AdminPanel');
      return true;
    } catch (e) {
      Logger.error('Error removing team from group',
          tag: 'AdminPanel', error: e);
      return false;
    }
  }

  int getTeamGroupIndex(String teamId) {
    for (int i = 0; i < _groups.groups.length; i++) {
      if (_groups.groups[i].contains(teamId)) {
        return i;
      }
    }
    return -1;
  }

  void setNumberOfTables(int count) {
    if (!isTournamentStarted && count >= 1) {
      _numberOfTables = count;
      notifyListeners();
      _saveNumberOfTables(count);
    }
  }

  void setNumberOfGroups(int count) {
    if (count >= 2 && count <= 10) {
      _numberOfGroups = count;
      if (_tournamentStyle == TournamentStyle.groupsAndKnockouts) {
        _targetTeamCount = count * 4;
      }
      // Clear stale group assignments since they don't match the new count
      if (_groupsAssigned && _groups.groups.length != count) {
        _groups = Groups();
        _groupsAssigned = false;
      }
      notifyListeners();
    }
  }

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

  bool _validateGroupAssignment() {
    if (_groups.groups.isEmpty) return false;
    if (_groups.groups.length != _numberOfGroups) return false;
    // Each group must have exactly 4 teams
    for (final group in _groups.groups) {
      if (group.length != 4) return false;
    }
    // All assigned teams must be registered
    final teamIds = _teams.map((t) => t.id).toSet();
    for (final group in _groups.groups) {
      for (final id in group) {
        if (!teamIds.contains(id)) return false;
      }
    }
    return true;
  }

  void setPhase(TournamentPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void setTournamentStyle(TournamentStyle style) {
    if (!isTournamentStarted) {
      // Save current KO count before switching away from KO-only
      if (_tournamentStyle == TournamentStyle.knockoutsOnly) {
        _koTargetTeamCount = _targetTeamCount;
      }
      _tournamentStyle = style;
      if (style != TournamentStyle.groupsAndKnockouts) {
        _groupsAssigned = false;
      }
      // Restore appropriate target count
      if (style == TournamentStyle.groupsAndKnockouts) {
        _targetTeamCount = _numberOfGroups * 4;
      } else if (style == TournamentStyle.knockoutsOnly) {
        if (_teams.isNotEmpty) {
          // Snap to the closest valid KO bracket size that fits the
          // current number of registered teams.
          const validKo = [64, 32, 16, 8];
          _targetTeamCount = validKo.firstWhere(
            (v) => v <= _teams.length,
            orElse: () => 8,
          );
          _koTargetTeamCount = _targetTeamCount;
        } else {
          _targetTeamCount = _koTargetTeamCount;
        }
      }
      // Persist style to Firebase
      _saveTournamentStyle(style);
      notifyListeners();
    }
  }

  /// Update the target team count for KO-only and round-robin modes
  void setTargetTeamCount(int count) {
    if (_targetTeamCount != count) {
      _targetTeamCount = count;
      if (_tournamentStyle == TournamentStyle.knockoutsOnly) {
        _koTargetTeamCount = count;
      }
      notifyListeners();
    }
  }

  /// Toggle rules visibility
  Future<void> setRulesEnabled(bool enabled) async {
    _selectedRuleset = enabled ? 'bmt-cup' : null;
    notifyListeners();

    try {
      await _firestoreService.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(_currentTournamentId)
          .set({
        'selectedRuleset': _selectedRuleset,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Logger.info('Ruleset updated to $_selectedRuleset', tag: 'AdminPanel');
    } catch (e) {
      Logger.error('Error updating rules setting', tag: 'AdminPanel', error: e);
      _setError('Fehler beim Speichern: $e');
    }
  }

  /// Set selected ruleset
  Future<void> setSelectedRuleset(String? ruleset) async {
    _selectedRuleset = ruleset;
    notifyListeners();

    try {
      await _firestoreService.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(_currentTournamentId)
          .set({
        'selectedRuleset': ruleset,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Logger.info('Ruleset updated to $ruleset', tag: 'AdminPanel');
    } catch (e) {
      Logger.error('Error updating ruleset', tag: 'AdminPanel', error: e);
      _setError('Fehler beim Speichern: $e');
    }
  }

  Future<void> _saveTournamentStyle(TournamentStyle style) async {
    try {
      final styleStr = style == TournamentStyle.groupsAndKnockouts
          ? 'groupsAndKnockouts'
          : style == TournamentStyle.knockoutsOnly
              ? 'knockoutsOnly'
              : 'everyoneVsEveryone';
      await _firestoreService.updateTournamentStyle(
        tournamentId: _currentTournamentId,
        style: styleStr,
      );
    } catch (e) {
      Logger.error('Error saving tournament style',
          tag: 'AdminPanel', error: e);
    }
  }

  Future<void> _saveNumberOfTables(int count) async {
    try {
      await _firestoreService.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(_currentTournamentId)
          .set({
        'numberOfTables': count,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.info('Number of tables updated to $count', tag: 'AdminPanel');
    } catch (e) {
      Logger.error('Error saving number of tables',
          tag: 'AdminPanel', error: e);
    }
  }

  Future<void> saveTargetTeamCount(int count) async {
    try {
      await _firestoreService.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(_currentTournamentId)
          .set({
        'targetTeamCount': count,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.debug('Target team count saved: $count', tag: 'AdminPanel');
    } catch (e) {
      Logger.error('Error saving target team count',
          tag: 'AdminPanel', error: e);
    }
  }

  /// Persist the set of reserve (bench) team IDs to tournament metadata.
  Future<void> saveReserveTeamIds(Set<String> reserveIds) async {
    _reserveTeamIds = reserveIds;
    notifyListeners();
    try {
      await _firestoreService.firestore
          .collection(FirestoreBase.tournamentsCollection)
          .doc(_currentTournamentId)
          .set({
        'reserveTeamIds': reserveIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Logger.debug(
          'Reserve team IDs saved (${reserveIds.length} teams on bench)',
          tag: 'AdminPanel');
    } catch (e) {
      Logger.error('Error saving reserve team IDs',
          tag: 'AdminPanel', error: e);
    }
  }

  void updateMatchStats({int? total, int? completed}) {
    if (total != null) _totalMatches = total;
    if (completed != null) _completedMatches = completed;
    _remainingMatches = _totalMatches - _completedMatches;
    notifyListeners();
  }

  String _generateTeamId() {
    return 'team_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

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

  void clearError() {
    _clearError();
    notifyListeners();
  }

  Future<bool> startTournament() async {
    if (!canStartTournament) {
      _setError(
          startValidationMessage ?? 'Turnier kann nicht gestartet werden.');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      switch (_tournamentStyle) {
        case TournamentStyle.groupsAndKnockouts:
          await _firestoreService.initializeTournament(
            _teams,
            _groups,
            tournamentId: _currentTournamentId,
            tableCount: _numberOfTables,
          );
          // Compute total group matches dynamically: C(n,2) per group
          _totalMatches = 0;
          for (final group in _groups.groups) {
            final n = group.length;
            _totalMatches += (n * (n - 1)) ~/ 2;
          }
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.groupPhase;
          Logger.info(
              'Tournament started (Group+KO) with ${_teams.length} teams in $_numberOfGroups groups',
              tag: 'AdminPanel');

        case TournamentStyle.knockoutsOnly:
          final selectedTeams = _teams.take(_targetTeamCount).toList();
          await _firestoreService.initializeKOOnlyTournament(
            selectedTeams,
            tournamentId: _currentTournamentId,
            tableCount: _numberOfTables,
          );
          // Calculate total matches for single-elimination: n-1 matches
          _totalMatches = selectedTeams.length - 1;
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.knockoutPhase;
          Logger.info(
              'Tournament started (KO only) with ${selectedTeams.length} teams',
              tag: 'AdminPanel');

        case TournamentStyle.everyoneVsEveryone:
          await _firestoreService.initializeRoundRobinTournament(
            _teams,
            tournamentId: _currentTournamentId,
            tableCount: _numberOfTables,
          );
          // Round robin: n*(n-1)/2 matches
          _totalMatches = (_teams.length * (_teams.length - 1)) ~/ 2;
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.groupPhase;
          Logger.info(
              'Tournament started (Round Robin) with ${_teams.length} teams, $_totalMatches matches',
              tag: 'AdminPanel');
      }
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
      await _firestoreService.transitionToKnockouts(
        tournamentId: _currentTournamentId,
        numberOfGroups: _numberOfGroups,
        tableCount: _numberOfTables,
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

  Future<bool> revertToGroupPhase() async {
    if (_currentPhase != TournamentPhase.knockoutPhase) {
      _setError('Zurücksetzen ist nur in der K.O.-Phase möglich.');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.revertToGroupPhase(
          tournamentId: _currentTournamentId);
      _currentPhase = TournamentPhase.groupPhase;
      await loadMatchStats();
      Logger.info('Reverted to group phase', tag: 'AdminPanel');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Fehler beim Zurücksetzen zur Gruppenphase: $e');
      Logger.error('Error reverting to group phase',
          tag: 'AdminPanel', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetTournament() async {
    _setLoading(true);
    _clearError();
    try {
      await _firestoreService.resetTournament(
          tournamentId: _currentTournamentId);
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

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
