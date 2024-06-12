import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/colors.dart';
import 'package:pongstrong/field_view.dart';
import 'package:pongstrong/test_objects.dart';

MaterialApp desktopApp(BuildContext context) {
  return MaterialApp(
    theme: ThemeData(
      fontFamily: GoogleFonts.notoSansMono().fontFamily,
    ),
    home: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        title: const Text('Pong Strong'),
        backgroundColor: Colors.white,
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height - 60,
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: FieldView(
                        'Laufende Spiele',
                        FieldColors.tomato,
                        FieldColors.tomato.withOpacity(0.5),
                        false,
                        Wrap(
                            alignment: WrapAlignment.center,
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            children: runningMatches),
                      ),
                    ),
                    Expanded(
                      child: FieldView(
                        'Die Nächsten Spiele',
                        FieldColors.springgreen,
                        FieldColors.springgreen.withOpacity(0.5),
                        false,
                        Wrap(
                            alignment: WrapAlignment.center,
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            children: upcomingMatches),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FieldView(
                  'Aktuelle Tabelle',
                  FieldColors.skyblue,
                  FieldColors.skyblue.withOpacity(0.5),
                  false,
                  Wrap(
                    children: tables,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    ),
  );
}
