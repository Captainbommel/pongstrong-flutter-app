// Barrel export for landing page components
export 'tournament_password_dialog.dart';
export 'create_tournament_dialog.dart';
export 'login_dialog.dart';

import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:provider/provider.dart';

import 'tournament_password_dialog.dart';
import 'create_tournament_dialog.dart';
import 'login_dialog.dart';

/// Landing page content that adapts to mobile and desktop layouts
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<String>> _tournamentsFuture;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingTournament = false;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _firestoreService.listTournaments();
  }

  void _refreshTournaments() {
    setState(() {
      _tournamentsFuture = _firestoreService.listTournaments();
    });
  }

  Future<void> _onTournamentSelected(String tournamentId) async {
    if (!mounted) return;

    final authState = Provider.of<AuthState>(context, listen: false);

    // Check if user is the creator of this tournament
    final isCreator = authState.isEmailUser &&
        authState.userId != null &&
        await _firestoreService.isCreator(tournamentId, authState.userId!);

    if (isCreator) {
      // Creator can join without password
      await _joinTournament(tournamentId);
    } else {
      // Check if tournament has a password
      final hasPassword =
          await _firestoreService.tournamentHasPassword(tournamentId);

      if (hasPassword) {
        // Show password dialog for other users
        if (mounted) {
          _showPasswordDialog(tournamentId);
        }
      } else {
        // No password set - allow direct access (legacy tournaments)
        await _joinTournament(tournamentId);
      }
    }
  }

  void _showPasswordDialog(String tournamentId) {
    showDialog(
      context: context,
      builder: (context) => TournamentPasswordDialog(
        tournamentId: tournamentId,
        onSuccess: () => _joinTournament(tournamentId),
      ),
    );
  }

  Future<void> _joinTournament(String tournamentId) async {
    if (!mounted) return;

    setState(() => _isLoadingTournament = true);

    final success =
        await Provider.of<TournamentDataState>(context, listen: false)
            .loadTournamentData(tournamentId);

    if (mounted) {
      if (success) {
        // Check the user's role for this tournament (admin/participant)
        final authState = Provider.of<AuthState>(context, listen: false);
        await authState.checkTournamentRole(tournamentId);

        if (!mounted) return;
        Provider.of<TournamentSelectionState>(context, listen: false)
            .setSelectedTournament(tournamentId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnier konnte nicht geladen werden'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingTournament = false);
      }
    }
  }

  void _showCreateTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateTournamentDialog(
        onTournamentCreated: (tournamentId) {
          _refreshTournaments();
          _joinTournament(tournamentId);
        },
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => LoginDialog(
        onLoginSuccess: () {
          _refreshTournaments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 940;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Hero section
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FieldColors.backgroundblue,
                  FieldColors.skyblue.withAlpha(180),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(isLarge: true),
                    const SizedBox(height: 32),
                    _buildDescription(isLarge: true),
                    const SizedBox(height: 48),
                    _buildFeaturesList(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right side - Actions
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildUserInfo(isLarge: true),
                    const SizedBox(height: 48),
                    _buildTournamentSelection(isLarge: true),
                    const SizedBox(height: 32),
                    _buildCreateTournamentButton(isLarge: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FieldColors.backgroundblue,
                  FieldColors.skyblue.withAlpha(180),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildUserInfo(isLarge: false),
                  const SizedBox(height: 24),
                  _buildLogo(isLarge: false),
                  const SizedBox(height: 24),
                  _buildDescription(isLarge: false),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Actions section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTournamentSelection(isLarge: false),
                const SizedBox(height: 24),
                _buildCreateTournamentButton(isLarge: false),
                const SizedBox(height: 32),
                _buildFeaturesList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo({required bool isLarge}) {
    return Column(
      crossAxisAlignment:
          isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_baseball,
              size: isLarge ? 64 : 48,
              color: GroupPhaseColors.cupred,
            ),
            const SizedBox(width: 16),
            Text(
              'PONGSTRONG',
              style: TextStyle(
                fontSize: isLarge ? 48 : 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Turnier Manager',
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            color: Colors.black54,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription({required bool isLarge}) {
    return Text(
      'Organisiere und verwalte deine Bierpong-Turniere mit Leichtigkeit. '
      'Verfolge Punkte, verwalte Spielpläne und halte den Wettbewerb am Laufen!',
      style: TextStyle(
        fontSize: isLarge ? 18 : 16,
        color: Colors.black87,
        height: 1.5,
      ),
      textAlign: isLarge ? TextAlign.start : TextAlign.center,
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.groups, 'text': 'Gruppenphase verwalten'},
      {'icon': Icons.account_tree, 'text': 'Turnierbaum Ansicht'},
      {'icon': Icons.leaderboard, 'text': 'Live Punkteverfolgung'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.cupred.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: GroupPhaseColors.cupred,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                feature['text'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserInfo({required bool isLarge}) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (authState.isEmailUser) {
          return _buildLoggedInUserInfo(authState, isLarge: isLarge);
        } else {
          return _buildLoginButton(isLarge: isLarge);
        }
      },
    );
  }

  Widget _buildLoggedInUserInfo(AuthState authState, {required bool isLarge}) {
    if (isLarge) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GroupPhaseColors.cupred.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GroupPhaseColors.cupred.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GroupPhaseColors.cupred,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eingeloggt als',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    authState.userEmail ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => authState.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Abmelden'),
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.cupred,
              ),
            ),
          ],
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person,
                    size: 18, color: GroupPhaseColors.cupred),
                const SizedBox(width: 8),
                Text(
                  authState.userEmail?.split('@')[0] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => authState.signOut(),
                  child: const Icon(Icons.logout, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildLoginButton({required bool isLarge}) {
    if (isLarge) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _showLoginDialog,
          icon: const Icon(Icons.login),
          label: const Text('Veranstalter Login'),
          style: OutlinedButton.styleFrom(
            foregroundColor: GroupPhaseColors.cupred,
            side: const BorderSide(color: GroupPhaseColors.cupred),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _showLoginDialog,
            icon: const Icon(Icons.login, size: 20),
            label: const Text('Login'),
            style: TextButton.styleFrom(
              foregroundColor: GroupPhaseColors.cupred,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTournamentSelection({required bool isLarge}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: GroupPhaseColors.steelblue,
                size: isLarge ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Turnier beitreten',
                style: TextStyle(
                  fontSize: isLarge ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Wähle ein bestehendes Turnier um Punkte und Spielpläne zu sehen:',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildTournamentList(),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    return FutureBuilder<List<String>>(
      future: _tournamentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading tournaments: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Keine Turniere verfügbar. Erstelle eines um loszulegen!',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }

        if (_isLoadingTournament) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      GroupPhaseColors.cupred,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Turnier wird geladen...'),
                ],
              ),
            ),
          );
        }

        return Column(
          children: tournaments.map((tournamentId) {
            return _buildTournamentListItem(tournamentId);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTournamentListItem(String tournamentId) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        return FutureBuilder<List<bool>>(
          future: Future.wait([
            authState.isEmailUser && authState.userId != null
                ? _firestoreService.isCreator(tournamentId, authState.userId!)
                : Future.value(false),
            _firestoreService.tournamentHasPassword(tournamentId),
          ]),
          builder: (context, snapshot) {
            final isCreator = snapshot.data?[0] ?? false;
            final hasPassword = snapshot.data?[1] ?? true;

            String subtitleText;
            IconData trailingIcon;

            if (isCreator) {
              subtitleText = 'Dein Turnier • Tippen zum Öffnen';
              trailingIcon = Icons.arrow_forward_ios;
            } else if (hasPassword) {
              subtitleText = 'Tippen für Passwort-Eingabe';
              trailingIcon = Icons.lock_outline;
            } else {
              subtitleText = 'Tippen zum Beitreten';
              trailingIcon = Icons.arrow_forward_ios;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _onTournamentSelected(tournamentId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCreator
                            ? GroupPhaseColors.cupred.withAlpha(100)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCreator
                                ? GroupPhaseColors.cupred.withAlpha(30)
                                : GroupPhaseColors.steelblue.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCreator ? Icons.star : Icons.sports_esports,
                            color: isCreator
                                ? GroupPhaseColors.cupred
                                : GroupPhaseColors.steelblue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tournamentId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCreator
                                      ? GroupPhaseColors.cupred
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          trailingIcon,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreateTournamentButton({required bool isLarge}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCreateTournamentDialog,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Neues Turnier erstellen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: GroupPhaseColors.cupred,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: 32,
            vertical: isLarge ? 20 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
