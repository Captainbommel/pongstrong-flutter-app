import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/shared/auth_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

//TODO: resposiveness needs to be improved

/// Landing page content that adapts to mobile and desktop layouts
class LandingPage extends StatefulWidget {
  final bool isDesktop;

  const LandingPage({super.key, required this.isDesktop});

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: widget.isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
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
          // User is logged in with email
          return _buildLoggedInUserInfo(authState, isLarge: isLarge);
        } else {
          // Anonymous user - show login button
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
                  CircularProgressIndicator(),
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
        // Use FutureBuilder to check both creator status and password status
        return FutureBuilder<List<bool>>(
          future: Future.wait([
            authState.isEmailUser && authState.userId != null
                ? _firestoreService.isCreator(tournamentId, authState.userId!)
                : Future.value(false),
            _firestoreService.tournamentHasPassword(tournamentId),
          ]),
          builder: (context, snapshot) {
            final isCreator = snapshot.data?[0] ?? false;
            final hasPassword =
                snapshot.data?[1] ?? true; // Default to true for safety

            // Determine the subtitle text based on access level
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

/// Dialog for entering tournament password
class TournamentPasswordDialog extends StatefulWidget {
  final String tournamentId;
  final VoidCallback onSuccess;

  const TournamentPasswordDialog({
    super.key,
    required this.tournamentId,
    required this.onSuccess,
  });

  @override
  State<TournamentPasswordDialog> createState() =>
      _TournamentPasswordDialogState();
}

class _TournamentPasswordDialogState extends State<TournamentPasswordDialog> {
  final _passwordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Bitte Passwort eingeben');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isValid = await _firestoreService.verifyTournamentPassword(
      widget.tournamentId,
      _passwordController.text,
    );

    if (mounted) {
      if (isValid) {
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Falsches Passwort';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;

    return Dialog(
      child: Container(
        width: isWide ? 400 : double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GroupPhaseColors.steelblue.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: GroupPhaseColors.steelblue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Turnier beitreten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tournamentId,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Password field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: GroupPhaseColors.cupred,
              onSubmitted: (_) => _verifyPassword(),
              decoration: InputDecoration(
                labelText: 'Turnier-Passwort',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: GroupPhaseColors.cupred, width: 2),
                ),
                floatingLabelStyle:
                    const TextStyle(color: GroupPhaseColors.cupred),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupPhaseColors.cupred,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Beitreten',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a new tournament
class CreateTournamentDialog extends StatefulWidget {
  final Function(String tournamentId) onTournamentCreated;

  const CreateTournamentDialog({
    super.key,
    required this.onTournamentCreated,
  });

  @override
  State<CreateTournamentDialog> createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<CreateTournamentDialog> {
  int _currentStep = 0;
  final _tournamentNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _obscurePassword = true;
  bool _obscureAccountPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _error;
  bool _isLoginMode = false;

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _accountPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validate current step
    if (_currentStep == 0) {
      if (_tournamentNameController.text.trim().isEmpty) {
        setState(() => _error = 'Bitte gib einen Turniernamen ein');
        return;
      }
      if (_passwordController.text.isEmpty) {
        setState(() => _error = 'Bitte gib ein Turnier-Passwort ein');
        return;
      }
    }

    setState(() {
      _error = null;
      _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _error = null;
        _currentStep--;
      });
    }
  }

  Future<void> _createTournament() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    // Validate account fields
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib eine E-Mail ein');
      return;
    }
    if (_accountPasswordController.text.isEmpty) {
      setState(() => _error = 'Bitte gib ein Passwort ein');
      return;
    }

    if (!_isLoginMode) {
      if (_accountPasswordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Passwörter stimmen nicht überein');
        return;
      }
      if (_accountPasswordController.text.length < 6) {
        setState(() => _error = 'Passwort muss mindestens 6 Zeichen lang sein');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    bool authSuccess;
    if (_isLoginMode) {
      authSuccess = await authState.signInWithEmail(
        _emailController.text.trim(),
        _accountPasswordController.text,
      );
    } else {
      authSuccess = await authState.createAccount(
        _emailController.text.trim(),
        _accountPasswordController.text,
      );
    }

    if (!authSuccess) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = authState.error ?? 'Authentifizierung fehlgeschlagen';
        });
      }
      return;
    }

    // Now create the tournament
    final tournamentId = await _firestoreService.createTournament(
      tournamentName: _tournamentNameController.text.trim(),
      creatorId: authState.userId!,
      creatorEmail: authState.userEmail!,
      password: _passwordController.text,
    );

    if (mounted) {
      if (tournamentId != null) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnier "$tournamentId" wurde erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Ein Turnier mit diesem Namen existiert bereits';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;
    final authState = Provider.of<AuthState>(context);

    // If user is already logged in, we can skip the account step
    final isAlreadyLoggedIn = authState.isEmailUser;

    return Dialog(
      child: Container(
        width: isWide ? 500 : double.infinity,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: GroupPhaseColors.cupred,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Neues Turnier erstellen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Details'),
                  _buildStepConnector(0),
                  _buildStepIndicator(
                      1, isAlreadyLoggedIn ? 'Bestätigen' : 'Konto'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _currentStep == 0
                    ? _buildDetailsStep()
                    : isAlreadyLoggedIn
                        ? _buildConfirmStep(authState)
                        : _buildAccountStep(),
              ),
            ),
            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Zurück'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GroupPhaseColors.cupred,
                        side: const BorderSide(color: GroupPhaseColors.cupred),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    )
                  else
                    const SizedBox(),
                  if (_currentStep == 0)
                    ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Weiter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GroupPhaseColors.cupred,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : isAlreadyLoggedIn
                              ? () => _createTournamentAsLoggedInUser(authState)
                              : _createTournament,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Turnier erstellen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTournamentAsLoggedInUser(AuthState authState) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final tournamentId = await _firestoreService.createTournament(
      tournamentName: _tournamentNameController.text.trim(),
      creatorId: authState.userId!,
      creatorEmail: authState.userEmail!,
      password: _passwordController.text,
    );

    if (mounted) {
      if (tournamentId != null) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnier "$tournamentId" wurde erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Ein Turnier mit diesem Namen existiert bereits';
        });
      }
    }
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? GroupPhaseColors.cupred : Colors.grey.shade300,
              border: isCurrent
                  ? Border.all(color: GroupPhaseColors.cupred, width: 2)
                  : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.black87 : Colors.grey,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? GroupPhaseColors.cupred : Colors.grey.shade300,
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tournamentNameController,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Turniername',
            hintText: 'z.B. BMT-Cup 2026',
            prefixIcon: const Icon(Icons.emoji_events),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Turnier-Passwort',
            hintText: 'Passwort für andere Spieler',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dieses Passwort teilst du mit allen Spielern, damit sie dem Turnier beitreten können.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier erstellen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Bereit zum Erstellen!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryItem(
                  'Turniername', _tournamentNameController.text.trim()),
              _buildSummaryItem('Ersteller', authState.userEmail ?? ''),
              _buildSummaryItem('Passwort', '••••••'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nach dem Erstellen wirst du automatisch dem Turnier beitreten.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isLoginMode ? 'Anmelden' : 'Konto erstellen',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isLoginMode = !_isLoginMode;
                _error = null;
              }),
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.steelblue,
              ),
              child: Text(_isLoginMode
                  ? 'Neues Konto erstellen'
                  : 'Ich habe bereits ein Konto'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginMode
              ? 'Melde dich mit deinem bestehenden Konto an'
              : 'Erstelle ein Konto um dein Turnier zu verwalten',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          cursorColor: GroupPhaseColors.cupred,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-Mail',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _accountPasswordController,
          obscureText: _obscureAccountPassword,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Passwort',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(
                  () => _obscureAccountPassword = !_obscureAccountPassword),
              icon: Icon(
                _obscureAccountPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        if (!_isLoginMode) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            cursorColor: GroupPhaseColors.cupred,
            decoration: InputDecoration(
              labelText: 'Passwort bestätigen',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: GroupPhaseColors.cupred, width: 2),
              ),
              floatingLabelStyle:
                  const TextStyle(color: GroupPhaseColors.cupred),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Zusammenfassung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSummaryItem(
                  'Turniername', _tournamentNameController.text.trim()),
              _buildSummaryItem('Turnier-Passwort', '••••••'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Login dialog for returning tournament creators
class LoginDialog extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginDialog({super.key, this.onLoginSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  final _confirmPasswordController = TextEditingController();
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib eine E-Mail ein'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib ein Passwort ein'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isRegisterMode) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwörter stimmen nicht überein'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await authState.createAccount(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konto erfolgreich erstellt!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.error ?? 'Registrierung fehlgeschlagen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      final success = await authState.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erfolgreich angemeldet!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.error ?? 'Anmeldung fehlgeschlagen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib deine E-Mail ein'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    final success =
        await authState.sendPasswordReset(_emailController.text.trim());

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwort-Reset E-Mail wurde gesendet'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error ?? 'Fehler beim Senden der E-Mail'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;
    final authState = Provider.of<AuthState>(context);

    return Dialog(
      child: Container(
        width: isWide ? 400 : double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GroupPhaseColors.cupred.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isRegisterMode ? Icons.person_add : Icons.login,
                    color: GroupPhaseColors.cupred,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRegisterMode
                            ? 'Konto erstellen'
                            : 'Veranstalter Login',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegisterMode
                            ? 'Erstelle ein neues Konto'
                            : 'Zugang zu deinen Turnieren',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Form
            TextField(
              controller: _emailController,
              cursorColor: GroupPhaseColors.cupred,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-Mail',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: GroupPhaseColors.cupred, width: 2),
                ),
                floatingLabelStyle:
                    const TextStyle(color: GroupPhaseColors.cupred),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: GroupPhaseColors.cupred,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Passwort',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: GroupPhaseColors.cupred, width: 2),
                ),
                floatingLabelStyle:
                    const TextStyle(color: GroupPhaseColors.cupred),
              ),
            ),
            if (_isRegisterMode) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                cursorColor: GroupPhaseColors.cupred,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Passwort bestätigen',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: GroupPhaseColors.cupred, width: 2),
                  ),
                  floatingLabelStyle:
                      const TextStyle(color: GroupPhaseColors.cupred),
                ),
              ),
            ],
            if (!_isRegisterMode) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: GroupPhaseColors.steelblue,
                  ),
                  child: const Text('Passwort vergessen?'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupPhaseColors.cupred,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRegisterMode ? 'Registrieren' : 'Anmelden',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRegisterMode = !_isRegisterMode;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.steelblue,
              ),
              child: Text(_isRegisterMode
                  ? 'Bereits ein Konto? Anmelden'
                  : 'Noch kein Konto? Registrieren'),
            ),
          ],
        ),
      ),
    );
  }
}
