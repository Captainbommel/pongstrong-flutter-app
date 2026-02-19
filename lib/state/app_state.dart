import 'package:flutter/material.dart';

/// Unified navigation views for both desktop and mobile layouts
enum AppView {
  /// Live match playing field.
  playingField,

  /// Group phase standings.
  groupPhase,

  /// Knockout bracket tree.
  tournamentTree,

  /// Tournament rules page.
  rules,

  /// Admin settings panel.
  adminPanel,
}

/// Unified app navigation state that replaces DesktopAppState and MobileAppState.
///
/// On desktop, the view is switched via navbar buttons.
/// On mobile, the view is used to sync the PageView and drawer.
class AppState extends ChangeNotifier {
  AppView _currentView = AppView.playingField;

  /// The currently active navigation view.
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

  /// Set view from a PageView index using the given available views list.
  void setViewFromPageIndex(int index, {List<AppView>? availableViews}) {
    final views = availableViews ?? AppView.values;
    if (index >= 0 && index < views.length) {
      _currentView = views[index];
    } else {
      _currentView = AppView.playingField;
    }
    notifyListeners();
  }

  /// Convert an [AppView] to a page index within the given [availableViews].
  /// Returns 0 if the view is not in the list.
  static int pageIndexFromView(AppView view, {List<AppView>? availableViews}) {
    final views = availableViews ?? AppView.values;
    final index = views.indexOf(view);
    return index >= 0 ? index : 0;
  }

  /// Convert a page index to an [AppView] within the given [availableViews].
  /// Returns [AppView.playingField] if the index is out of range.
  static AppView viewFromPageIndex(int index, {List<AppView>? availableViews}) {
    final views = availableViews ?? AppView.values;
    if (index >= 0 && index < views.length) {
      return views[index];
    }
    return AppView.playingField;
  }
}
