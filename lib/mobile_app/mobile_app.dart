import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/mobile_app/mobile_drawer.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:pongstrong/shared/test_objects.dart';
import 'package:provider/provider.dart';

const String turnamentName = 'BMT-Cup';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: GoogleFonts.notoSansMono().fontFamily,
      ),
      home: Scaffold(
        key: Provider.of<MobileAppState>(context).scaffoldKey,
        drawer: const MobileDrawer(),
        backgroundColor: Colors.white,
        appBar: AppBar(
          shadowColor: Colors.black,
          elevation: 10,
          title: const Text(turnamentName),
          centerTitle: true,
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: () {
            switch (Provider.of<MobileAppState>(context).state) {
              case MobileAppView.runningMatches:
                return runningGames();
              case MobileAppView.upcomingMatches:
                return nextGames();
              case MobileAppView.tables:
                return currentTable();
              case MobileAppView.rules:
                return const RulesView();
              default:
                return const Placeholder();
            }
          }(),
        ),
      ),
    );
  }
}

FieldView currentTable() {
  return FieldView(
    'Aktuelle Tabelle',
    FieldColors.skyblue,
    FieldColors.skyblue.withOpacity(0.6),
    true,
    Column(
      children: tables,
    ),
  );
}

FieldView nextGames() {
  return FieldView(
    'Nächste Spiele',
    FieldColors.springgreen,
    FieldColors.springgreen.withOpacity(0.5),
    true,
    Column(
      //alignment: WrapAlignment.center,
      children: upcomingMatches,
    ),
  );
}

FieldView runningGames() {
  return FieldView(
    'Laufende Spiele',
    FieldColors.tomato,
    FieldColors.tomato.withOpacity(0.5),
    true,
    Column(
      //alignment: WrapAlignment.center,
      children: runningMatches,
    ),
  );
}
