import 'package:flutter/material.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_dialogs.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/views/admin/teams_management_page.dart';
import 'package:pongstrong/views/admin/widgets/admin_widgets.dart';
import 'package:pongstrong/widgets/error_banner.dart';
import 'package:provider/provider.dart';

/// Unified responsive admin panel that replaces the separate desktop and mobile
/// admin panels (DesktopAdminPanel / MobileAdminPanel).
///
/// Adapts layout based on screen width:
/// - Wide (>1200): three-column grid
/// - Medium (>600): two-column grid
/// - Narrow: single-column stack
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  late AdminPanelState _adminState;
  bool _initialized = false;
  TournamentDataState? _tournamentData;

  @override
  void initState() {
    super.initState();
    _adminState = AdminPanelState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _tournamentData =
          Provider.of<TournamentDataState>(context, listen: false);
      _adminState.setTournamentId(_tournamentData!.currentTournamentId);
      _tournamentData!.addListener(_onTournamentDataChanged);
      _loadData();
    }
  }

  void _onTournamentDataChanged() {
    // Refresh match stats whenever tournament data changes (e.g. match finished)
    _adminState.loadMatchStats();
  }

  Future<void> _loadData() async {
    // Load metadata first so _currentPhase is set before loadMatchStats runs
    await _adminState.loadTournamentMetadata();
    await Future.wait([
      _adminState.loadTeams(),
      _adminState.loadGroups(),
      _adminState.loadMatchStats(),
    ]);
  }

  @override
  void dispose() {
    _tournamentData?.removeListener(_onTournamentDataChanged);
    _adminState.dispose();
    super.dispose();
  }

  void _navigateToTeamsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamsManagementPage(adminState: _adminState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auth guard: only admin (tournament creator) can access this panel
    final authState = Provider.of<AuthState>(context);
    if (!authState.isAdmin) {
      return _buildAccessDenied(context);
    }

    final isCompact = MediaQuery.of(context).size.width < 600;

    return ChangeNotifierProvider.value(
      value: _adminState,
      child: Consumer<AdminPanelState>(
        builder: (context, state, _) {
          return Scaffold(
            backgroundColor: AppColors.grey100,
            appBar: isCompact ? _buildMobileAppBar() : null,
            body: Column(
              children: [
                // Desktop header (hidden on mobile where AppBar is used)
                if (!isCompact) _buildDesktopHeader(context, state),

                // Main content
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: TreeColors.rebeccapurple))
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(isCompact ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (state.errorMessage != null) ...[
                                ErrorBanner(
                                  message: state.errorMessage!,
                                  onDismiss: () => state.clearError(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              _buildResponsiveLayout(context, state, isCompact),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shows a locked/access denied screen for non-admin users
  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.cupred.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: GroupPhaseColors.cupred,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kein Zugriff',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nur der Ersteller des Turniers kann die Turnierverwaltung nutzen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.admin_panel_settings, size: 24),
          SizedBox(width: 8),
          Text('Turnierverwaltung'),
        ],
      ),
      backgroundColor: GroupPhaseColors.cupred,
      foregroundColor: AppColors.textOnColored,
      elevation: 2,
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AdminPanelState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings,
              size: 24, color: GroupPhaseColors.cupred),
          const SizedBox(width: 8),
          Text(
            state.tournamentName.isEmpty
                ? 'Turnierverwaltung'
                : 'Turnierverwaltung – ${state.tournamentName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// Builds the responsive card layout depending on screen width
  Widget _buildResponsiveLayout(
    BuildContext context,
    AdminPanelState state,
    bool isCompact,
  ) {
    final width = MediaQuery.of(context).size.width;

    final controlCard = TournamentControlCard(
      currentPhase: state.currentPhase,
      tournamentStyle: state.tournamentStyle,
      onStartTournament: () =>
          AdminPanelDialogs.showStartConfirmation(context, state),
      onAdvancePhase: () =>
          AdminPanelDialogs.showPhaseAdvanceConfirmation(context, state),
      onResetTournament: () => AdminPanelDialogs.showResetConfirmation(
        context,
        state,
        onResetComplete: _loadData,
      ),
      onRevertToGroupPhase: () =>
          AdminPanelDialogs.showRevertToGroupPhaseConfirmation(
        context,
        state,
        onRevertComplete: _loadData,
      ),
      isCompact: isCompact,
    );

    final statusCard = TournamentStatusCard(
      currentPhase: state.currentPhase,
      tournamentStyle: state.tournamentStyle,
      totalTeams: state.totalTeams,
      totalMatches: state.totalMatches,
      completedMatches: state.completedMatches,
      remainingMatches: state.remainingMatches,
      isCompact: isCompact,
    );

    final teamsCard = TeamsAndGroupsNavigationCard(
      totalTeams: state.totalTeams,
      teamsInGroups: state.teamsInGroupsCount,
      numberOfGroups: state.numberOfGroups,
      targetTeamCount: state.targetTeamCount,
      groupsAssigned: state.groupsAssigned,
      tournamentStyle: state.tournamentStyle,
      isLocked: state.isTournamentStarted,
      onNavigateToTeams: () => _navigateToTeamsPage(context),
      isCompact: isCompact,
    );

    final styleCard = TournamentStyleCard(
      selectedStyle: state.tournamentStyle,
      isTournamentStarted: state.isTournamentStarted,
      onStyleChanged: (style) => state.setTournamentStyle(style),
      selectedRuleset: state.selectedRuleset,
      onRulesetChanged: (ruleset) {
        state.setSelectedRuleset(ruleset);
        // Also update TournamentDataState so navbar/drawer reacts immediately
        Provider.of<TournamentDataState>(context, listen: false)
            .updateSelectedRuleset(ruleset);
      },
      numberOfTables: state.numberOfTables,
      onTablesChanged: (count) => state.setNumberOfTables(count),
      splitTables: state.splitTables,
      onSplitTablesChanged: (val) => state.setSplitTables(val),
      isKnockoutStarted: state.currentPhase == TournamentPhase.knockoutPhase ||
          state.currentPhase == TournamentPhase.finished,
      totalTeams: state.activeTeamCount,
      isCompact: isCompact,
    );

    final importExportCard = ImportExportCard(
      onImportTeams: () async {
        await AdminPanelDialogs.handleImportTeams(context);
        await _loadData();
      },
      onImportTeamsJson: () async {
        await AdminPanelDialogs.handleImportTeamsJson(context);
        await _loadData();
      },
      onImportSnapshot: () async {
        await AdminPanelDialogs.handleImportSnapshot(context);
        await _loadData();
      },
      isCompact: isCompact,
    );

    // Single column for narrow screens
    if (width < 600) {
      return Column(
        children: [
          controlCard,
          const SizedBox(height: 16),
          statusCard,
          const SizedBox(height: 16),
          teamsCard,
          const SizedBox(height: 16),
          styleCard,
          const SizedBox(height: 16),
          importExportCard,
          const SizedBox(height: 32),
        ],
      );
    }

    // Three columns for wide screens
    if (width > 1200) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                controlCard,
                const SizedBox(height: 16),
                importExportCard,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                teamsCard,
                const SizedBox(height: 16),
                statusCard,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: styleCard),
        ],
      );
    }

    // Two columns for medium screens
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              controlCard,
              const SizedBox(height: 16),
              statusCard,
              const SizedBox(height: 16),
              importExportCard,
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              teamsCard,
              const SizedBox(height: 16),
              styleCard,
            ],
          ),
        ),
      ],
    );
  }
}
