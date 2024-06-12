import 'package:flutter/material.dart';

enum MobileAppView {
  //? change to current page
  runningMatches,
  upcomingMatches,
  tables,
  groupphase,
  tournamentTree,
  rules,
  teams,
}

class MobileAppState extends ChangeNotifier {
  /// controls the main contetnt of the app
  MobileAppView _state = MobileAppView.runningMatches;
  MobileAppView get state => _state;

  /// controls the drawer
  final scaffoldKey = GlobalKey<ScaffoldState>();

  void Function()? setAppState(MobileAppView state) {
    switch (state) {
      case MobileAppView.runningMatches:
        return () {
          _state = MobileAppView.runningMatches;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.upcomingMatches:
        return () {
          _state = MobileAppView.upcomingMatches;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.tables:
        return () {
          _state = MobileAppView.tables;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.groupphase:
        return () {
          _state = MobileAppView.groupphase;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.tournamentTree:
        return () {
          _state = MobileAppView.tournamentTree;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.rules:
        return () {
          _state = MobileAppView.rules;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      case MobileAppView.teams:
        return () {
          _state = MobileAppView.teams;
          scaffoldKey.currentState!.closeDrawer();
          notifyListeners();
        };
      default:
        return null;
    }
  }
}
