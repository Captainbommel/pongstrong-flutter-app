import 'package:flutter/material.dart';

/// Unified navigation views for both desktop and mobile layouts
enum AppView {
  playingField,
  groupPhase,
  tournamentTree,
  rules,
  adminPanel,
}

/// Unified app navigation state that replaces DesktopAppState and MobileAppState.
///
/// On desktop, the view is switched via navbar buttons.
/// On mobile, the view is used to sync the PageView and drawer.
class AppState extends ChangeNotifier {
  AppView _currentView = AppView.playingField;
  AppView get currentView => _currentView;

  /// Scaffold key for controlling the mobile drawer
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Set the current view (used by desktop navbar buttons)
  void setView(AppView view) {
    _currentView = view;
    notifyListeners();
  }

  /// Set view and close the mobile drawer
  void setViewAndCloseDrawer(AppView view) {
    _currentView = view;
    scaffoldKey.currentState?.closeDrawer();
    notifyListeners();
  }

  /// Set view from a PageView index (mobile swipe navigation)
  void setViewFromPageIndex(int index) {
    _currentView = viewFromPageIndex(index);
    notifyListeners();
  }

  /// Convert an AppView to a PageView index
  static int pageIndexFromView(AppView view) {
    switch (view) {
      case AppView.playingField:
        return 0;
      case AppView.groupPhase:
        return 1;
      case AppView.tournamentTree:
        return 2;
      case AppView.rules:
        return 3;
      case AppView.adminPanel:
        return 4;
    }
  }

  /// Convert a PageView index to an AppView
  static AppView viewFromPageIndex(int index) {
    switch (index) {
      case 0:
        return AppView.playingField;
      case 1:
        return AppView.groupPhase;
      case 2:
        return AppView.tournamentTree;
      case 3:
        return AppView.rules;
      case 4:
        return AppView.adminPanel;
      default:
        return AppView.playingField;
    }
  }
}
