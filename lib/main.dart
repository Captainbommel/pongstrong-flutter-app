import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

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
          if (MediaQuery.of(context).size.width > 700) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Expanded(
                          child: FieldView(
                            'Laufende Spiele',
                            tomato,
                            tomato2,
                            false,
                            Text('Test Team Hinzufügen'),
                          ),
                        ),
                        Expanded(
                          child: FieldView(
                            'Die Nächsten Spiele',
                            springgreen,
                            springgreen2,
                            false,
                            Text(
                                '${MediaQuery.of(context).size.width.round()}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: FieldView(
                      'Aktuelle Tabelle',
                      skyblue,
                      skyblue2,
                      false,
                      Text('hallo'),
                    ),
                  )
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                children: [
                  const FieldView(
                    'Aktuelle Tabelle',
                    skyblue,
                    skyblue2,
                    true,
                    Text('hallo'),
                  ),
                  const FieldView(
                    'Laufende Spiele',
                    tomato,
                    tomato2,
                    true,
                    Text('Test Team Hinzufügen'),
                  ),
                  FieldView(
                    'Die Nächsten Spiele',
                    springgreen,
                    springgreen2,
                    true,
                    Text('${MediaQuery.of(context).size.width.round()}'),
                  ),
                ],
              ),
            );
          }
        }(),
      ),
    );
  }
}

class FieldView extends StatelessWidget {
  final String title;
  final Color color1;
  final Color color2;
  final Widget child;
  final bool smallScreen;

  const FieldView(
    this.title,
    this.color1,
    this.color2,
    this.smallScreen,
    this.child, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: const BorderSide(color: Colors.black, width: 4),
      ),
      color: color1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          () {
            if (smallScreen) {
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Card(
                  color: color2,
                  child: child,
                ),
              );
            } else {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Card(
                    color: color2,
                    child: child,
                  ),
                ),
              );
            }
          }(),
        ],
      ),
    );
  }
}

void addTestTeam() {
  //final db = FirebaseFirestore.instance.collection('turnament-state');

  //db.doc('Pumpe2000').set({
  //  'member1': 'Rolf',
  //  'member2': 'Rudi',
  //});
}

// Spielfeld
const tomato = Color.fromARGB(255, 255, 99, 71);
const tomato2 = Color.fromARGB(255, 223, 106, 85);
const springgreen = Color.fromARGB(255, 0, 255, 127);
const springgreen2 = Color.fromARGB(255, 32, 223, 127);
const skyblue = Color.fromARGB(255, 135, 206, 235);
const skyblue2 = Color.fromARGB(255, 133, 186, 208);
const backgroundblue = Color.fromARGB(240, 169, 216, 255);
const fieldbackground = Color.fromARGB(50, 128, 128, 128);

// Baumphase
const cornsilk = Color.fromARGB(255, 255, 248, 220);
const rebeccapurple = Color.fromARGB(255, 102, 51, 153);
const royalblue = Color.fromARGB(255, 65, 105, 225);
const yellowgreen = Color.fromARGB(255, 154, 205, 50);
const hotpink = Color.fromARGB(255, 255, 105, 180);

// Gruppenphase Übersicht und Login
const steelblue = Color.fromARGB(255, 70, 130, 180);
const grouppurple = Color.fromARGB(240, 180, 70, 130);
const cupred = Color.fromARGB(255, 213, 35, 70);
