import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/state/app_state.dart';

void main() {
  group('AppState', () {
    test('initial view is playingField', () {
      final state = AppState();
      expect(state.currentView, AppView.playingField);
    });

    test('setView updates current view', () {
      final state = AppState();
      state.setView(AppView.groupPhase);
      expect(state.currentView, AppView.groupPhase);
    });

    test('setView notifies listeners', () {
      final state = AppState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.setView(AppView.tournamentTree);
      expect(notifyCount, 1);
    });

    test('setViewFromPageIndex with default views (AppView.values)', () {
      final state = AppState();

      state.setViewFromPageIndex(0);
      expect(state.currentView, AppView.playingField);

      state.setViewFromPageIndex(1);
      expect(state.currentView, AppView.groupPhase);

      state.setViewFromPageIndex(2);
      expect(state.currentView, AppView.tournamentTree);

      state.setViewFromPageIndex(3);
      expect(state.currentView, AppView.rules);

      state.setViewFromPageIndex(4);
      expect(state.currentView, AppView.adminPanel);
    });

    test('setViewFromPageIndex with custom availableViews', () {
      final state = AppState();
      final available = [
        AppView.playingField,
        AppView.rules,
        AppView.adminPanel
      ];

      state.setViewFromPageIndex(0, availableViews: available);
      expect(state.currentView, AppView.playingField);

      state.setViewFromPageIndex(1, availableViews: available);
      expect(state.currentView, AppView.rules);

      state.setViewFromPageIndex(2, availableViews: available);
      expect(state.currentView, AppView.adminPanel);
    });

    test('setViewFromPageIndex defaults to playingField for invalid index', () {
      final state = AppState();
      state.setViewFromPageIndex(99);
      expect(state.currentView, AppView.playingField);
    });
  });

  group('pageIndexFromView', () {
    test('returns correct index for each view (default)', () {
      expect(AppState.pageIndexFromView(AppView.playingField), 0);
      expect(AppState.pageIndexFromView(AppView.groupPhase), 1);
      expect(AppState.pageIndexFromView(AppView.tournamentTree), 2);
      expect(AppState.pageIndexFromView(AppView.rules), 3);
      expect(AppState.pageIndexFromView(AppView.adminPanel), 4);
    });

    test('returns correct index with custom availableViews', () {
      final available = [
        AppView.playingField,
        AppView.tournamentTree,
        AppView.adminPanel
      ];
      expect(
          AppState.pageIndexFromView(AppView.playingField,
              availableViews: available),
          0);
      expect(
          AppState.pageIndexFromView(AppView.tournamentTree,
              availableViews: available),
          1);
      expect(
          AppState.pageIndexFromView(AppView.adminPanel,
              availableViews: available),
          2);
    });

    test('returns 0 for view not in availableViews', () {
      final available = [AppView.playingField, AppView.rules];
      expect(
          AppState.pageIndexFromView(AppView.groupPhase,
              availableViews: available),
          0);
    });
  });

  group('viewFromPageIndex', () {
    test('returns correct view for each index (default)', () {
      expect(AppState.viewFromPageIndex(0), AppView.playingField);
      expect(AppState.viewFromPageIndex(1), AppView.groupPhase);
      expect(AppState.viewFromPageIndex(2), AppView.tournamentTree);
      expect(AppState.viewFromPageIndex(3), AppView.rules);
      expect(AppState.viewFromPageIndex(4), AppView.adminPanel);
    });

    test('returns playingField for out-of-range index', () {
      expect(AppState.viewFromPageIndex(-1), AppView.playingField);
      expect(AppState.viewFromPageIndex(5), AppView.playingField);
      expect(AppState.viewFromPageIndex(100), AppView.playingField);
    });

    test('works with custom availableViews', () {
      final available = [AppView.playingField, AppView.rules];
      expect(AppState.viewFromPageIndex(0, availableViews: available),
          AppView.playingField);
      expect(AppState.viewFromPageIndex(1, availableViews: available),
          AppView.rules);
      expect(AppState.viewFromPageIndex(2, availableViews: available),
          AppView.playingField);
    });
  });

  group('round trip', () {
    test('pageIndexFromView and viewFromPageIndex are inverses', () {
      for (final view in AppView.values) {
        final index = AppState.pageIndexFromView(view);
        final roundTripped = AppState.viewFromPageIndex(index);
        expect(roundTripped, view);
      }
    });

    test('round trip with custom availableViews', () {
      final available = [
        AppView.playingField,
        AppView.tournamentTree,
        AppView.adminPanel
      ];
      for (final view in available) {
        final index =
            AppState.pageIndexFromView(view, availableViews: available);
        final roundTripped =
            AppState.viewFromPageIndex(index, availableViews: available);
        expect(roundTripped, view);
      }
    });
  });
}
