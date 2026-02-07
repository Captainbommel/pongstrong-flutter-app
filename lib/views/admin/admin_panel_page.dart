import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/views/admin/admin_panel_dialogs.dart';
import 'package:pongstrong/views/admin/widgets/admin_widgets.dart';
import 'package:pongstrong/views/admin/teams_management_page.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/widgets/error_banner.dart';

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
      final tournamentData =
          Provider.of<TournamentDataState>(context, listen: false);
      _adminState.setTournamentId(tournamentData.currentTournamentId);
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await _adminState.loadTournamentMetadata();
    await _adminState.loadTeams();
    await _adminState.loadGroups();
  }

  @override
  void dispose() {
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
            backgroundColor: Colors.grey[100],
            appBar: isCompact ? _buildMobileAppBar(state) : null,
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
      backgroundColor: Colors.grey[100],
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
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nur der Ersteller des Turniers kann die Turnierverwaltung nutzen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(AdminPanelState state) {
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
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Aktualisieren',
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AdminPanelState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings,
              size: 24, color: GroupPhaseColors.cupred),
          const SizedBox(width: 8),
          const Text(
            'Turnierverwaltung',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Daten neu laden',
          ),
          const SizedBox(width: 8),
          _buildPhaseIndicator(state),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(AdminPanelState state) {
    Color phaseColor;
    String phaseText;

    switch (state.currentPhase) {
      case TournamentPhase.notStarted:
        phaseColor = Colors.grey;
        phaseText = 'Nicht gestartet';
        break;
      case TournamentPhase.groupPhase:
        phaseColor = GroupPhaseColors.steelblue;
        phaseText = 'Gruppenphase';
        break;
      case TournamentPhase.knockoutPhase:
        phaseColor = TreeColors.rebeccapurple;
        phaseText = 'K.O.-Phase';
        break;
      case TournamentPhase.finished:
        phaseColor = FieldColors.springgreen;
        phaseText = 'Beendet';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: phaseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: phaseColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: phaseColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            phaseText,
            style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold),
          ),
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
      isCompact: isCompact,
    );

    final statusCard = TournamentStatusCard(
      currentPhase: state.currentPhase,
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
      isCompact: isCompact,
    );

    final importExportCard = ImportExportCard(
      onImportJson: () async {
        await AdminPanelDialogs.handleImportTeams(context);
        await _loadData();
      },
      onExportJson: () => AdminPanelDialogs.showExportDialog(context),
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
                statusCard,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: teamsCard),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                styleCard,
                const SizedBox(height: 16),
                importExportCard,
              ],
            ),
          ),
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
              const SizedBox(height: 16),
              importExportCard,
            ],
          ),
        ),
      ],
    );
  }
}
