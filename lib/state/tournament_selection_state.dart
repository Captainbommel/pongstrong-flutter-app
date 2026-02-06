import 'package:flutter/material.dart';

/// Manages the tournament selection state and persistence
class TournamentSelectionState extends ChangeNotifier {
  String? _selectedTournamentId;

  String? get selectedTournamentId => _selectedTournamentId;
  bool get hasSelectedTournament => _selectedTournamentId != null;

  /// Set the selected tournament ID
  void setSelectedTournament(String tournamentId) {
    _selectedTournamentId = tournamentId;
    notifyListeners();
  }

  /// Clear the selected tournament
  void clearSelectedTournament() {
    _selectedTournamentId = null;
    notifyListeners();
  }
}
