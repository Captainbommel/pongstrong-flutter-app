import 'package:flutter/material.dart';

enum DesktopAppView {
  playingfield,
  groupphase,
  tournamentTree,
  rules,
  teams,
}

class DesktopAppState extends ChangeNotifier {
  /// controls the main contetnt of the app
  DesktopAppView _state = DesktopAppView.playingfield;
  DesktopAppView get state => _state;

  /// controls the drawer
  final scaffoldKey = GlobalKey<ScaffoldState>();

  void Function()? setAppState(DesktopAppView state) {
    switch (state) {
      case DesktopAppView.playingfield:
        return () {
          _state = DesktopAppView.playingfield;
          notifyListeners();
        };
      case DesktopAppView.groupphase:
        return () {
          _state = DesktopAppView.groupphase;
          notifyListeners();
        };
      case DesktopAppView.tournamentTree:
        return () {
          _state = DesktopAppView.tournamentTree;
          notifyListeners();
        };
      case DesktopAppView.rules:
        return () {
          _state = DesktopAppView.rules;
          notifyListeners();
        };
      case DesktopAppView.teams:
        return () {
          _state = DesktopAppView.teams;
          notifyListeners();
        };
    }
  }
}
