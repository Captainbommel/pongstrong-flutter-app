// Barrel export for landing page components
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/join_code.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/utils/text_formatters.dart';
import 'package:pongstrong/views/landing/create_tournament_dialog.dart';
import 'package:pongstrong/views/landing/impressum_dialog.dart';
import 'package:pongstrong/views/landing/login_dialog.dart';
import 'package:pongstrong/views/landing/tournament_list_item.dart';
import 'package:pongstrong/views/landing/tournament_password_dialog.dart';
import 'package:provider/provider.dart';

export 'create_tournament_dialog.dart';
export 'login_dialog.dart';
export 'tournament_password_dialog.dart';

/// Landing page content that adapts to mobile and desktop layouts
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingTournament = false;
  final Map<String, Future<List<bool>>> _tournamentMetaCache = {};
  final TextEditingController _codeController = TextEditingController();
  String? _codeError;
  bool _isLookingUpCode = false;
  Future<List<String>>? _myTournamentsFuture;
  String? _myTournamentsUserId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _refreshTournaments() {
    setState(() {
      _tournamentMetaCache.clear();
      _myTournamentsFuture = null;
      _myTournamentsUserId = null;
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
        SnackBarHelper.showError(
            context, 'Turnier konnte nicht geladen werden');
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
      backgroundColor: AppColors.surface,
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
          child: ColoredBox(
            color: AppColors.surface,
            child: Column(
              children: [
                Expanded(
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
                _buildFooter(isLarge: true),
              ],
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
                // _buildFeaturesList(),
                const SizedBox(height: 24),
                _buildFooter(isLarge: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({required bool isLarge}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isLarge ? 12 : 16,
        horizontal: 16,
      ),
      child: Center(
        child: TextButton(
          onPressed: () {
            ImpressumDialog.show(context);
          },
          child: Text(
            'Impressum & Datenschutz',
            style: TextStyle(
              fontSize: isLarge ? 10 : 12,
              color: AppColors.textSubtle,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
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
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PONGSTRONG',
                  style: TextStyle(
                    fontSize: isLarge ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Turnier Manager',
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            color: AppColors.textSecondary,
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
        color: AppColors.textPrimary,
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.cupred.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon']! as IconData,
                  color: GroupPhaseColors.cupred,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  feature['text']! as String,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              child: const Icon(Icons.person, color: AppColors.textOnColored),
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
                      color: AppColors.textDisabled,
                    ),
                  ),
                  Text(
                    authState.userEmail ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
              color: AppColors.surface.withAlpha(200),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => authState.signOut(),
                  child: const Icon(Icons.logout,
                      size: 18, color: AppColors.textDisabled),
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
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        final isLoggedIn = authState.isEmailUser;

        // Cache the future for logged-in users
        if (isLoggedIn && _myTournamentsUserId != authState.userId) {
          _myTournamentsUserId = authState.userId;
          _myTournamentsFuture = authState.userId != null
              ? _firestoreService.listUserTournaments(authState.userId!)
              : Future.value([]);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Deine Turniere" sub-section for logged-in creators
              if (isLoggedIn) ...[
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: GroupPhaseColors.cupred,
                      size: isLarge ? 28 : 24,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Deine Turniere',
                        style: TextStyle(
                          fontSize: isLarge ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMyTournamentList(),
                const SizedBox(height: 24),
                const Divider(color: AppColors.grey300),
                const SizedBox(height: 24),
              ],
              // Search sub-section
              Row(
                children: [
                  Icon(
                    Icons.search,
                    color: GroupPhaseColors.steelblue,
                    size: isLarge ? 28 : 24,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Mit Code beitreten',
                      style: TextStyle(
                        fontSize: isLarge ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              _buildCodeInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyTournamentList() {
    return FutureBuilder<List<String>>(
      future: _myTournamentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(GroupPhaseColors.cupred),
              ),
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cautionLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.caution),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Du hast noch keine Turniere erstellt.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }

        if (_isLoadingTournament) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(GroupPhaseColors.cupred),
                  ),
                  SizedBox(height: 16),
                  Text('Turnier wird geladen...'),
                ],
              ),
            ),
          );
        }

        return Column(
          children: tournaments
              .map((id) => TournamentListItem(
                    tournamentId: id,
                    getMeta: _getTournamentMeta,
                    onTap: _onTournamentSelected,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildCodeInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: JoinCode.codeLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            cursorColor: GroupPhaseColors.steelblue,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppColors.textDisabled.withAlpha(100),
              ),
              counterText: '',
              errorText: _codeError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: GroupPhaseColors.steelblue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 2),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            onSubmitted: (_) => _lookupCode(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _isLookingUpCode ? null : _lookupCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.steelblue,
              foregroundColor: AppColors.textOnColored,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _isLookingUpCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textOnColored),
                    ),
                  )
                : const Text(
                    'Beitreten',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _lookupCode() async {
    final code = JoinCode.normalise(_codeController.text);
    if (!JoinCode.isValid(code)) {
      setState(
          () => _codeError = 'Bitte gib einen gültigen 4-stelligen Code ein');
      return;
    }

    setState(() {
      _codeError = null;
      _isLookingUpCode = true;
    });

    final tournamentId = await _firestoreService.findTournamentByCode(code);

    if (!mounted) return;

    if (tournamentId == null) {
      setState(() {
        _isLookingUpCode = false;
        _codeError = 'Kein Turnier mit diesem Code gefunden';
      });
      return;
    }

    setState(() => _isLookingUpCode = false);
    _onTournamentSelected(tournamentId);
  }

  Future<List<bool>> _getTournamentMeta(
      String tournamentId, AuthState authState) {
    final key = '${tournamentId}_${authState.userId ?? "anon"}';
    return _tournamentMetaCache.putIfAbsent(
        key,
        () => Future.wait([
              if (authState.isEmailUser && authState.userId != null)
                _firestoreService.isCreator(tournamentId, authState.userId!)
              else
                Future.value(false),
              _firestoreService.tournamentHasPassword(tournamentId),
            ]));
  }

  Widget _buildCreateTournamentButton({required bool isLarge}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCreateTournamentDialog,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Neues Turnier erstellen',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: GroupPhaseColors.cupred,
          foregroundColor: AppColors.textOnColored,
          padding: EdgeInsets.symmetric(
            horizontal: 32,
            vertical: isLarge ? 20 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
