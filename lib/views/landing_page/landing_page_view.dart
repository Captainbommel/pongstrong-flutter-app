import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/views/landing_page/dialogs/auth_dialog.dart';
import 'package:pongstrong/views/landing_page/dialogs/create_tournament_dialog.dart';
import 'package:pongstrong/views/landing_page/dialogs/impressum_dialog.dart';
import 'package:pongstrong/views/landing_page/dialogs/tournament_password_dialog.dart';
import 'package:pongstrong/views/landing_page/landing_hero_panel.dart';
import 'package:pongstrong/views/landing_page/logged_in_user_info.dart';
import 'package:pongstrong/views/landing_page/lookup_code_input.dart';
import 'package:pongstrong/views/landing_page/tournament_list_item.dart';
import 'package:provider/provider.dart';

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
  Future<List<String>>? _myTournamentsFuture;
  String? _myTournamentsUserId;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
      builder: (context) => AuthDialog(
        onLoginSuccess: () {
          _refreshTournaments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 940;
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: GroupPhaseColors.cupred,
          selectionColor: GroupPhaseColors.cupred.withAlpha(80),
          selectionHandleColor: GroupPhaseColors.cupred,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
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
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: LandingHeroPanel(isLarge: true),
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
                  const LandingHeroPanel(isLarge: false),
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

  Widget _buildUserInfo({required bool isLarge}) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (authState.isEmailUser) {
          return LoggedInUserInfo(authState: authState, isLarge: isLarge);
        } else {
          return _buildLoginButton(isLarge: isLarge);
        }
      },
    );
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
                _buildCreatorTournamentList(),
                const SizedBox(height: 24),
                const Divider(color: AppColors.grey300),
                const SizedBox(height: 24),
              ],
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
              LookupCodeInput(onTournamentSelected: _onTournamentSelected),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreatorTournamentList() {
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
