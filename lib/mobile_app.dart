import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/appstate.dart';
import 'package:pongstrong/colors.dart';
import 'package:pongstrong/field_view.dart';
import 'package:pongstrong/mobile_drawer.dart';
import 'package:pongstrong/test_objects.dart';
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
            switch (Provider.of<AppState>(context).state) {
              case MobileAppState.runningMatches:
                return runningGames();
              case MobileAppState.upcomingMatches:
                return nextGames();
              case MobileAppState.tables:
                return currentTable();
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
    'Die Nächsten Spiele',
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
