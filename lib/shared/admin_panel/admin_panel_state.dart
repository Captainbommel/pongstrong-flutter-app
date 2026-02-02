import 'package:flutter/material.dart';

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

/// Admin panel state management
class AdminPanelState extends ChangeNotifier {
  // Tournament status
  TournamentPhase _currentPhase = TournamentPhase.notStarted;
  TournamentStyle _tournamentStyle = TournamentStyle.groupsAndKnockouts;
  int _totalTeams = 0;
  int _totalMatches = 0;
  int _completedMatches = 0;
  int _remainingMatches = 0;

  // Getters
  TournamentPhase get currentPhase => _currentPhase;
  TournamentStyle get tournamentStyle => _tournamentStyle;
  int get totalTeams => _totalTeams;
  int get totalMatches => _totalMatches;
  int get completedMatches => _completedMatches;
  int get remainingMatches => _remainingMatches;
  bool get isTournamentStarted => _currentPhase != TournamentPhase.notStarted;
  bool get isTournamentFinished => _currentPhase == TournamentPhase.finished;

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

  // Setters (to be connected with functionality later)
  void setPhase(TournamentPhase phase) {
    _currentPhase = phase;
    notifyListeners();
  }

  void setTournamentStyle(TournamentStyle style) {
    _tournamentStyle = style;
    notifyListeners();
  }

  void setTeamCount(int count) {
    _totalTeams = count;
    notifyListeners();
  }

  void updateMatchStats({
    int? total,
    int? completed,
  }) {
    if (total != null) _totalMatches = total;
    if (completed != null) _completedMatches = completed;
    _remainingMatches = _totalMatches - _completedMatches;
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
