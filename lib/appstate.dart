import 'package:flutter/material.dart';

enum MobileAppState {
  runningMatches,
  upcomingMatches,
  tables,
  groupphase,
  tournamentTree,
  rules,
  teams,
}

class AppState extends ChangeNotifier {
  MobileAppState _state = MobileAppState.runningMatches;
  MobileAppState get state => _state;

  void setRunningMatches() {
    _state = MobileAppState.runningMatches;
    notifyListeners();
  }

  void setUpcomingMatches() {
    _state = MobileAppState.upcomingMatches;
    notifyListeners();
  }

  void setTables() {
    _state = MobileAppState.tables;
    notifyListeners();
  }
}
