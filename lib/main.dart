import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/desktop_app/desktop_app_state.dart';
import 'package:pongstrong/firebase/auth.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/desktop_app/desktop_app.dart';
import 'package:pongstrong/mobile_app/mobile_app.dart';
import 'package:pongstrong/shared/auth_state.dart';
import 'package:pongstrong/shared/landing_page/landing_page.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  // initialize Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: 'AIzaSyBL6N6HwgspjRLukoVpsK6axdwU0GITKqc',
        appId: '1:21303267607:web:d0cb107c989a02f8712752',
        messagingSenderId: '21303267607',
        projectId: 'pong-strong'),
  );

  // get a anonymous user
  final auth = AuthService();
  if (auth.user == null) {
    debugPrint('no user logged in -> signing in anonymously');
    await auth.signInAnon();
    debugPrint('user now logged in -> new uid: ${auth.user!.uid}');
  } else {
    debugPrint('user logged in -> uid: ${auth.user!.uid}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    //! App rebulds when screen size changes -> state should be determined before
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => TournamentSelectionState()),
        ChangeNotifierProvider(create: (_) => TournamentDataState()),
        ChangeNotifierProvider(create: (_) => DesktopAppState()),
        ChangeNotifierProvider(create: (_) => MobileAppState()),
      ],
      child: MaterialApp(
        home: const AppSelector(),
        theme: ThemeData(
          fontFamily: GoogleFonts.notoSansMono().fontFamily,
        ),
      ),
    );
  }
}

/// Widget that selects between Desktop and Mobile app based on screen size
class AppSelector extends StatelessWidget {
  const AppSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 940;

    // Check if a tournament is selected
    final hasSelectedTournament =
        Provider.of<TournamentSelectionState>(context).hasSelectedTournament;

    if (!hasSelectedTournament) {
      // Show landing page if no tournament is selected
      return LandingPage(isDesktop: isLargeScreen);
    }

    // Show the appropriate app based on screen size
    return isLargeScreen ? const DesktopApp() : const MobileApp();
  }
}
