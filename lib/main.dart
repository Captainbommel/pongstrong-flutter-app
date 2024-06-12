import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pongstrong/appstate.dart';
import 'package:pongstrong/desktop_app.dart';
import 'package:pongstrong/mobile_app.dart';
import 'package:provider/provider.dart';

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
    return MediaQuery.of(context).size.width > 600
        ? desktopApp(context)
        : ChangeNotifierProvider<AppState>.value(
            value: AppState(),
            child: const MobileApp(),
          );
  }
}
