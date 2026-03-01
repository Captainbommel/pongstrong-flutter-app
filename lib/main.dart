import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pongstrong/app.dart';
import 'package:pongstrong/services/auth_service.dart';
import 'package:pongstrong/state/app_state.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/views/landing_page/landing_page_view.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  Logger.info('App starting...', tag: 'Main');

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await dotenv.load();
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: dotenv.env['API_KEY']!,
        appId: dotenv.env['APP_ID']!,
        messagingSenderId: dotenv.env['MESSAGING_SENDER_ID']!,
        projectId: dotenv.env['PROJECT_ID']!),
  );
  dotenv.clean();
  Logger.info('Firebase initialized', tag: 'Main');

  // Get or create anonymous user
  final auth = AuthService();
  if (auth.user == null) {
    Logger.info('No user logged in, signing in anonymously...', tag: 'Main');
    await auth.signInAnon();
    final userId = auth.user?.uid ?? 'unknown';
    Logger.info('Anonymous sign-in complete, uid: $userId', tag: 'Main');
  } else {
    Logger.info('User already logged in, uid: ${auth.user?.uid ?? 'unknown'}',
        tag: 'Main');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _fontFamily = GoogleFonts.notoSansMono().fontFamily;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => TournamentSelectionState()),
        ChangeNotifierProvider(create: (_) => TournamentDataState()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        home: const AppSelector(),
        theme: ThemeData(
          fontFamily: _fontFamily,
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
    // Check if a tournament is selected
    final hasSelectedTournament =
        Provider.of<TournamentSelectionState>(context).hasSelectedTournament;

    if (!hasSelectedTournament) {
      // Show landing page if no tournament is selected
      return const LandingPage();
    }

    // Prevent the root route from being popped (e.g. by a double-pop race).
    return const PopScope(
      canPop: false,
      child: AppShell(),
    );
  }
}
