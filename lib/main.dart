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

/// Dialog for selecting a tournament
class _TournamentSelectionDialog extends StatefulWidget {
  const _TournamentSelectionDialog();

  @override
  State<_TournamentSelectionDialog> createState() =>
      _TournamentSelectionDialogState();
}

class _TournamentSelectionDialogState
    extends State<_TournamentSelectionDialog> {
  late Future<List<String>> _tournamentsFuture;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _firestoreService.listTournaments();
  }

  Future<void> _onTournamentSelected(String tournamentId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    // Load tournament data
    final success =
        await Provider.of<TournamentDataState>(context, listen: false)
            .loadTournamentData(tournamentId);

    if (mounted) {
      if (success) {
        // Mark tournament as selected and close the selection dialog
        Provider.of<TournamentSelectionState>(context, listen: false)
            .setSelectedTournament(tournamentId);
        Navigator.pop(context); // Close tournament selection dialog
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load tournament data'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _tournamentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tournaments...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Error loading tournaments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(snapshot.error.toString()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No tournaments available',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text('Please create a tournament first.'),
                ],
              ),
            ),
          );
        }

        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Tournament',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading tournament data...'),
                    ],
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tournaments.length,
                      itemBuilder: (context, index) {
                        final tournamentId = tournaments[index];
                        return ListTile(
                          title: Text(tournamentId),
                          onTap: () => _onTournamentSelected(tournamentId),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        final selectionState =
            Provider.of<TournamentSelectionState>(context, listen: false);
        if (!selectionState.hasSelectedTournament) {
          _showTournamentSelectionDialog();
        }
      }
    });
  }

  void _showTournamentSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _TournamentSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    return isLargeScreen ? const DesktopApp() : const MobileApp();
  }
}
