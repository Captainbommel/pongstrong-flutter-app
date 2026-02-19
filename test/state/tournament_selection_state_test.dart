import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';

void main() {
  group('TournamentSelectionState', () {
    test('initial state has no selected tournament', () {
      final state = TournamentSelectionState();
      expect(state.selectedTournamentId, isNull);
      expect(state.hasSelectedTournament, isFalse);
    });

    test('setSelectedTournament updates the ID', () {
      final state = TournamentSelectionState();
      state.setSelectedTournament('tourney_42');

      expect(state.selectedTournamentId, 'tourney_42');
      expect(state.hasSelectedTournament, isTrue);
    });

    test('setSelectedTournament notifies listeners', () {
      final state = TournamentSelectionState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.setSelectedTournament('t1');
      expect(notifyCount, 1);
    });

    test('clearSelectedTournament resets to null', () {
      final state = TournamentSelectionState();
      state.setSelectedTournament('tourney_1');
      state.clearSelectedTournament();

      expect(state.selectedTournamentId, isNull);
      expect(state.hasSelectedTournament, isFalse);
    });

    test('clearSelectedTournament notifies listeners', () {
      final state = TournamentSelectionState();
      state.setSelectedTournament('t1');

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.clearSelectedTournament();
      expect(notifyCount, 1);
    });

    test('can change selected tournament', () {
      final state = TournamentSelectionState();
      state.setSelectedTournament('first');
      state.setSelectedTournament('second');

      expect(state.selectedTournamentId, 'second');
      expect(state.hasSelectedTournament, isTrue);
    });
  });
}
