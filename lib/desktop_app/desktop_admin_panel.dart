import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_state.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_widgets.dart';
import 'package:pongstrong/shared/admin_panel/teams_management_page.dart';
import 'package:pongstrong/shared/colors.dart';

/// Desktop version of the Admin Panel with wider layout
class DesktopAdminPanel extends StatefulWidget {
  const DesktopAdminPanel({super.key});

  @override
  State<DesktopAdminPanel> createState() => _DesktopAdminPanelState();
}

class _DesktopAdminPanelState extends State<DesktopAdminPanel> {
  late AdminPanelState _adminState;

  @override
  void initState() {
    super.initState();
    _adminState = AdminPanelState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _adminState.loadTeams();
    await _adminState.loadGroups();
  }

  @override
  void dispose() {
    _adminState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _adminState,
      child: Consumer<AdminPanelState>(
        builder: (context, state, _) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: Column(
              children: [
                // Header
                _buildHeader(context, state),

                // Main content
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: TreeColors.rebeccapurple))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error message if any
                              if (state.errorMessage != null) ...[
                                _buildErrorBanner(state),
                                const SizedBox(height: 16),
                              ],

                              // Title row
                              const Row(
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      size: 32, color: GroupPhaseColors.cupred),
                                  SizedBox(width: 12),
                                  Text(
                                    'Turnierverwaltung',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Verwalte dein Turnier: Teams, Spielplan, Ergebnisse und mehr',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Main grid layout
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth > 1200) {
                                    return _buildThreeColumnLayout(state);
                                  } else {
                                    return _buildTwoColumnLayout(state);
                                  }
                                },
                              ),
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

  Widget _buildErrorBanner(AdminPanelState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GroupPhaseColors.cupred),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: GroupPhaseColors.cupred),
          const SizedBox(width: 12),
          Expanded(child: Text(state.errorMessage!)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => state.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminPanelState state) {
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
          // Title
          const Text(
            'Turnierverwaltung',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Daten neu laden',
          ),
          const SizedBox(width: 8),

          // Status indicator
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
            style: TextStyle(
              color: phaseColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeColumnLayout(AdminPanelState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: [
              TournamentStatusCard(
                currentPhase: state.currentPhase,
                totalTeams: state.totalTeams,
                totalMatches: state.totalMatches,
                completedMatches: state.completedMatches,
                remainingMatches: state.remainingMatches,
              ),
              const SizedBox(height: 16),
              TournamentControlCard(
                currentPhase: state.currentPhase,
                onStartTournament: () => _showStartConfirmation(context, state),
                onAdvancePhase: () =>
                    _showPhaseAdvanceConfirmation(context, state),
                onShuffleMatches: () => _showShuffleConfirmation(context),
                onResetTournament: () => _showResetConfirmation(context, state),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Middle column
        Expanded(
          child: Column(
            children: [
              TournamentStyleCard(
                selectedStyle: state.tournamentStyle,
                isTournamentStarted: state.isTournamentStarted,
                onStyleChanged: (style) {
                  state.setTournamentStyle(style);
                },
              ),
              const SizedBox(height: 16),
              ImportExportCard(
                onImportJson: () => _handleImportTeams(context),
                onExportJson: () => _showExportDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right column - Teams & Groups
        Expanded(
          child: Column(
            children: [
              TeamsAndGroupsNavigationCard(
                totalTeams: state.totalTeams,
                teamsInGroups: state.teamsInGroupsCount,
                numberOfGroups: state.numberOfGroups,
                groupsAssigned: state.groupsAssigned,
                tournamentStyle: state.tournamentStyle,
                isLocked: state.isTournamentStarted,
                onNavigateToTeams: () => _navigateToTeamsPage(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout(AdminPanelState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: [
              TournamentStatusCard(
                currentPhase: state.currentPhase,
                totalTeams: state.totalTeams,
                totalMatches: state.totalMatches,
                completedMatches: state.completedMatches,
                remainingMatches: state.remainingMatches,
              ),
              const SizedBox(height: 16),
              TournamentStyleCard(
                selectedStyle: state.tournamentStyle,
                isTournamentStarted: state.isTournamentStarted,
                onStyleChanged: (style) {
                  state.setTournamentStyle(style);
                },
              ),
              const SizedBox(height: 16),
              TeamsAndGroupsNavigationCard(
                totalTeams: state.totalTeams,
                teamsInGroups: state.teamsInGroupsCount,
                numberOfGroups: state.numberOfGroups,
                groupsAssigned: state.groupsAssigned,
                tournamentStyle: state.tournamentStyle,
                isLocked: state.isTournamentStarted,
                onNavigateToTeams: () => _navigateToTeamsPage(context),
              ),
              const SizedBox(height: 16),
              ImportExportCard(
                onImportJson: () => _handleImportTeams(context),
                onExportJson: () => _showExportDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right column
        Expanded(
          child: Column(
            children: [
              TournamentControlCard(
                currentPhase: state.currentPhase,
                onStartTournament: () => _showStartConfirmation(context, state),
                onAdvancePhase: () =>
                    _showPhaseAdvanceConfirmation(context, state),
                onShuffleMatches: () => _showShuffleConfirmation(context),
                onResetTournament: () => _showResetConfirmation(context, state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Navigation to Teams Management Page
  void _navigateToTeamsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamsManagementPage(adminState: _adminState),
      ),
    );
  }

  Future<void> _showStartConfirmation(
      BuildContext context, AdminPanelState state) async {
    // Check validation
    final validationMessage = state.startValidationMessage;
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: GroupPhaseColors.cupred,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text(
          'Turnier starten?',
          style: TextStyle(color: GroupPhaseColors.cupred),
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registriert: ${state.totalTeams} Teams'),
              const SizedBox(height: 8),
              Text('Turniermodus: ${state.styleDisplayName}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nach dem Start können keine neuen Teams mehr hinzugefügt werden und der Turniermodus kann nicht mehr geändert werden.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: GroupPhaseColors.cupred),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.cupred,
              foregroundColor: Colors.white,
            ),
            child: const Text('Turnier starten'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      state.setPhase(TournamentPhase.groupPhase);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnier gestartet!'),
            backgroundColor: FieldColors.springgreen,
          ),
        );
      }
    }
  }

  Future<void> _showPhaseAdvanceConfirmation(
      BuildContext context, AdminPanelState state) async {
    String nextPhase;
    if (state.currentPhase == TournamentPhase.groupPhase) {
      nextPhase = 'K.O.-Phase';
    } else {
      nextPhase = 'Turnierfinale';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.skip_next, color: TreeColors.rebeccapurple),
            SizedBox(width: 8),
            Text('Zur nächsten Phase wechseln?'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Du wechselst von der aktuellen Phase zur $nextPhase.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stelle sicher, dass alle Spiele der aktuellen Phase eingetragen sind.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: TreeColors.rebeccapurple),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.skip_next),
            label: Text('Zur $nextPhase'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (state.currentPhase == TournamentPhase.groupPhase) {
        state.setPhase(TournamentPhase.knockoutPhase);
      } else {
        state.setPhase(TournamentPhase.finished);
      }
    }
  }

  Future<void> _showShuffleConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shuffle, color: GroupPhaseColors.steelblue),
            SizedBox(width: 8),
            Text('Spielreihenfolge würfeln?'),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Die Spielreihenfolge wird zufällig neu gemischt.',
              ),
              SizedBox(height: 8),
              Text(
                'Bereits eingetragene Ergebnisse bleiben erhalten.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: GroupPhaseColors.steelblue),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.shuffle),
            label: const Text('Würfeln'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.steelblue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spielreihenfolge neu gewürfelt!')),
      );
    }
  }

  Future<void> _handleImportTeams(BuildContext context) async {
    await TestDataHelpers.uploadTeamsFromJson(context);
  }

  Future<void> _showResetConfirmation(
      BuildContext context, AdminPanelState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: GroupPhaseColors.cupred),
            SizedBox(width: 8),
            Text('Turnier zurücksetzen?'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Möchtest du das Turnier wirklich zurücksetzen?',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GroupPhaseColors.cupred),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: GroupPhaseColors.cupred),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Alle Spielergebnisse und der Turnierfortschritt werden gelöscht. Teams bleiben erhalten.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: GroupPhaseColors.cupred),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Zurücksetzen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.cupred,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      state.setPhase(TournamentPhase.notStarted);
      state.updateMatchStats(completed: 0);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnier wurde zurückgesetzt'),
            backgroundColor: GroupPhaseColors.cupred,
          ),
        );
      }
    }
  }

  Future<void> _showExportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: GroupPhaseColors.steelblue),
            SizedBox(width: 8),
            Text('JSON Export'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Folgende Daten werden exportiert:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildExportItem('Teams und Gruppen'),
              _buildExportItem('Spielergebnisse'),
              _buildExportItem('Turnierstatus'),
              _buildExportItem('Turniermodus'),
              _buildExportItem('Spielreihenfolge'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FieldColors.springgreen),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: FieldColors.springgreen),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Die exportierte Datei kann jederzeit importiert werden, um das Turnier wiederherzustellen.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: GroupPhaseColors.steelblue),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('JSON Export wird heruntergeladen...')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.steelblue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: FieldColors.springgreen, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
