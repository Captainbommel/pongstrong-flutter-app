import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _disposed = false;

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
  int _numberOfGroups = 6;

  // Selected team count for KO-only and round-robin modes
  // (controls how many of the saved teams are used when starting)
  int _targetTeamCount = 8;

  // Rules configuration
  String? _selectedRuleset = 'bmt-cup';

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
  int get targetTeamCount => _targetTeamCount;
  int get totalMatches => _totalMatches;
  int get completedMatches => _completedMatches;
  int get remainingMatches => _remainingMatches;
  bool get rulesEnabled => _selectedRuleset != null;
  String? get selectedRuleset => _selectedRuleset;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTournamentStarted => _currentPhase != TournamentPhase.notStarted;
  bool get isTournamentFinished => _currentPhase == TournamentPhase.finished;

  int get teamsInGroupsCount {
    int count = 0;
    for (var group in _groups.groups) {
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
        return 'Nicht alle Teams sind einer Gruppe zugewiesen.';
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
        // Load tournament style from metadata
        final styleStr = metadata['tournamentStyle'] as String?;
        if (styleStr != null) {
          switch (styleStr) {
            case 'knockoutsOnly':
              _tournamentStyle = TournamentStyle.knockoutsOnly;
              break;
            case 'everyoneVsEveryone':
              _tournamentStyle = TournamentStyle.everyoneVsEveryone;
              break;
            default:
              _tournamentStyle = TournamentStyle.groupsAndKnockouts;
          }
        }
        // Load rules setting from metadata
        // Only default to 'bmt-cup' if the field doesn't exist (backwards compatibility)
        // If it exists and is null, keep it as null (user explicitly disabled rules)
        if (metadata.containsKey('selectedRuleset')) {
          _selectedRuleset = metadata['selectedRuleset'] as String?;
        } else {
          _selectedRuleset = 'bmt-cup'; // Default for old tournaments
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
          for (var round in knockouts.champions.rounds) {
            for (var match in round) {
              if (match.teamId1.isNotEmpty || match.teamId2.isNotEmpty) {
                totalMatches++;
                if (match.done) completedMatches++;
              }
            }
          }
          for (var round in knockouts.europa.rounds) {
            for (var match in round) {
              if (match.teamId1.isNotEmpty || match.teamId2.isNotEmpty) {
                totalMatches++;
                if (match.done) completedMatches++;
              }
            }
          }
          for (var round in knockouts.conference.rounds) {
            for (var match in round) {
              if (match.teamId1.isNotEmpty || match.teamId2.isNotEmpty) {
                totalMatches++;
                if (match.done) completedMatches++;
              }
            }
          }
          for (var match in knockouts.superCup.matches) {
            if (match.teamId1.isNotEmpty || match.teamId2.isNotEmpty) {
              totalMatches++;
              if (match.done) completedMatches++;
            }
          }
        }
      } else {
        // In group phase (or other phases): only count group matches
        final gruppenphase = await _firestoreService.loadGruppenphase(
            tournamentId: _currentTournamentId);
        if (gruppenphase != null) {
          for (var group in gruppenphase.groups) {
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
      mem1: member1,
      mem2: member2,
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
      mem1: _teams[index].mem1,
      mem2: _teams[index].mem2,
    );
    _teams[index] = Team(id: teamId, name: name, mem1: member1, mem2: member2);
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
    for (var group in _groups.groups) {
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
    final shuffledTeamIds = _teams.map((t) => t.id).toList()..shuffle(Random());
    final newGroups = List.generate(groupCount, (_) => <String>[]);
    for (int i = 0; i < shuffledTeamIds.length; i++) {
      newGroups[i % groupCount].add(shuffledTeamIds[i]);
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
    for (var group in _groups.groups) {
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

  int getTeamGroupIndex(String teamId) {
    for (int i = 0; i < _groups.groups.length; i++) {
      if (_groups.groups[i].contains(teamId)) {
        return i;
      }
    }
    return -1;
  }

  void setNumberOfGroups(int count) {
    if (count > 0 && count <= 8) {
      _numberOfGroups = count;
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
    final assignedTeamIds = <String>{};
    for (var group in _groups.groups) {
      assignedTeamIds.addAll(group);
    }
    return _teams.every((team) => assignedTeamIds.contains(team.id));
  }

  void setPhase(TournamentPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void setTournamentStyle(TournamentStyle style) {
    if (!isTournamentStarted) {
      _tournamentStyle = style;
      if (style != TournamentStyle.groupsAndKnockouts) {
        _groupsAssigned = false;
      }
      // Set sensible default target counts
      if (style == TournamentStyle.groupsAndKnockouts) {
        _targetTeamCount = 24;
      } else if (style == TournamentStyle.knockoutsOnly) {
        _targetTeamCount = 8;
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
          );
          _totalMatches = _numberOfGroups * 6;
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.groupPhase;
          Logger.info(
              'Tournament started (Group+KO) with ${_teams.length} teams in $_numberOfGroups groups',
              tag: 'AdminPanel');
          break;

        case TournamentStyle.knockoutsOnly:
          final selectedTeams = _teams.take(_targetTeamCount).toList();
          await _firestoreService.initializeKOOnlyTournament(
            selectedTeams,
            tournamentId: _currentTournamentId,
          );
          // Calculate total matches for single-elimination: n-1 matches
          _totalMatches = selectedTeams.length - 1;
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.knockoutPhase;
          Logger.info(
              'Tournament started (KO only) with ${selectedTeams.length} teams',
              tag: 'AdminPanel');
          break;

        case TournamentStyle.everyoneVsEveryone:
          await _firestoreService.initializeRoundRobinTournament(
            _teams,
            tournamentId: _currentTournamentId,
          );
          // Round robin: n*(n-1)/2 matches
          _totalMatches = (_teams.length * (_teams.length - 1)) ~/ 2;
          _completedMatches = 0;
          _remainingMatches = _totalMatches;
          _currentPhase = TournamentPhase.groupPhase;
          Logger.info(
              'Tournament started (Round Robin) with ${_teams.length} teams, $_totalMatches matches',
              tag: 'AdminPanel');
          break;
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

  void shuffleMatches() {
    Logger.debug('Shuffling matches...', tag: 'AdminPanel');
  }

  void importFromJson() {
    Logger.debug('Importing from JSON...', tag: 'AdminPanel');
  }

  void exportToJson() {
    Logger.debug('Exporting to JSON...', tag: 'AdminPanel');
  }
}
