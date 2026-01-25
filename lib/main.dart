import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/desktop_app/desktop_app_state.dart';
import 'package:pongstrong/firebase/auth.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/desktop_app/desktop_app.dart';
import 'package:pongstrong/mobile_app/mobile_app.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:pongstrong/shared/tournament_selection_dialog.dart';
import 'package:pongstrong/services/firestore_service.dart';
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
class AppSelector extends StatefulWidget {
  const AppSelector({super.key});

  @override
  State<AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<AppSelector> {
  @override
  void initState() {
    super.initState();
    _checkAndShowTournamentDialog();
  }

  void _checkAndShowTournamentDialog() {
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        final selectionState =
            Provider.of<TournamentSelectionState>(context, listen: false);
        if (!selectionState.hasSelectedTournament) {
          // Check if there's only one tournament
          final firestoreService = FirestoreService();
          try {
            final tournaments = await firestoreService.listTournaments();
            if (mounted) {
              if (tournaments.length == 1) {
                // Automatically load the single tournament
                await Provider.of<TournamentDataState>(context, listen: false)
                    .loadTournamentData(tournaments[0]);
                selectionState.setSelectedTournament(tournaments[0]);
              } else {
                // Show dialog if multiple tournaments or none
                _showTournamentSelectionDialog();
              }
            }
          } catch (e) {
            // Show dialog if error fetching tournaments
            if (mounted) {
              _showTournamentSelectionDialog();
            }
          }
        }
      }
    });
  }

  void _showTournamentSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const TournamentSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    return isLargeScreen ? const DesktopApp() : const MobileApp();
  }
}
