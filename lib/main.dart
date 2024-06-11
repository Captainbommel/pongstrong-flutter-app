import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/colors.dart';
import 'package:pongstrong/field_view.dart';
import 'package:pongstrong/match_view.dart';

Future<void> main() async {
  // initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyBL6N6HwgspjRLukoVpsK6axdwU0GITKqc',
          appId: '1:21303267607:web:d0cb107c989a02f8712752',
          messagingSenderId: '21303267607',
          projectId: 'pong-strong'));

  runApp(const MyApp());
}

final runningMatches = [
  for (var i = 0; i < 10; i++)
    Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView(
        'Kotstulle',
        'Testikuläre Torsion',
        (i + 1).toString(),
        TableColors.get(i),
        true,
        onTap: () => debugPrint('Match ${i + 1} pressed'),
      ),
    )
];

final upcomingMatches = [
  for (var i = 0; i < 10; i++)
    Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView('WookieMookie', 'Penispumpe3000', (i + 1).toString(),
          TableColors.get(i), i > 4 ? false : true,
          onTap: i > 4 ? null : () => debugPrint('Match ${i + 1} pressed')),
    )
];

final tables = [
  for (var i = 0; i < 4; i++)
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: table,
    )
];

TableRow pongTableRow(
  String group,
  String points,
  String diff,
  String cups,
) {
  return TableRow(
    decoration: const BoxDecoration(color: Colors.white),
    children: [
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(group),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(points),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(diff),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(cups),
        ),
      ),
    ],
  );
}

final table = Table(
  columnWidths: const {
    0: FlexColumnWidth(3),
    1: FlexColumnWidth(1),
    2: FlexColumnWidth(1),
    3: FlexColumnWidth(1),
  },
  border: const TableBorder(
    top: BorderSide(width: 2),
    bottom: BorderSide(width: 2),
    left: BorderSide(width: 2),
    right: BorderSide(width: 2),
    horizontalInside: BorderSide(width: 1.2),
    verticalInside: BorderSide(width: 1.2),
  ),
  children: [
    pongTableRow('Gruppe A', 'Punkte', 'Diff.', 'Becher'),
    pongTableRow('Kotstulle', '6', '3', '3'),
    pongTableRow('Testikuläre Torsion', '3', '0', '3'),
    pongTableRow('WookieMookie', '0', '-3', '0'),
    pongTableRow('Penispumpe3000', '0', '0', '0')
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
        body: () {
          if (MediaQuery.of(context).size.width > 600) {
            return SizedBox(
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
            );
          } else {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  children: [
                    FieldView(
                      'Laufende Spiele',
                      FieldColors.tomato,
                      FieldColors.tomato.withOpacity(0.5),
                      true,
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: runningMatches,
                      ),
                    ),
                    FieldView(
                      'Die Nächsten Spiele',
                      FieldColors.springgreen,
                      FieldColors.springgreen.withOpacity(0.5),
                      true,
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: upcomingMatches,
                      ),
                    ),
                    FieldView(
                      'Aktuelle Tabelle',
                      FieldColors.skyblue,
                      FieldColors.skyblue.withOpacity(0.6),
                      true,
                      Wrap(
                        children: tables,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }(),
      ),
    );
  }
}
