import 'package:flutter/material.dart';

/// Manages the tournament selection state and persistence
class TournamentSelectionState extends ChangeNotifier {
  String? _selectedTournamentId;

  /// The currently selected tournament ID, or `null`.
  String? get selectedTournamentId => _selectedTournamentId;

  /// Whether a tournament has been selected.
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
