import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_state.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_widgets.dart';
import 'package:pongstrong/shared/admin_panel/teams_management_page.dart';
import 'package:pongstrong/shared/colors.dart';

/// Mobile version of the Admin Panel
class MobileAdminPanel extends StatefulWidget {
  const MobileAdminPanel({super.key});

  @override
  State<MobileAdminPanel> createState() => _MobileAdminPanelState();
}

class _MobileAdminPanelState extends State<MobileAdminPanel> {
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
            appBar: AppBar(
              title: const Text('Turnierverwaltung'),
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
            ),
            body: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error message if any
                        if (state.errorMessage != null) ...[
                          _buildErrorBanner(state),
                          const SizedBox(height: 16),
                        ],

                        // Tournament Status Card
                        TournamentStatusCard(
                          currentPhase: state.currentPhase,
                          totalTeams: state.totalTeams,
                          totalMatches: state.totalMatches,
                          completedMatches: state.completedMatches,
                          remainingMatches: state.remainingMatches,
                          isCompact: true,
                        ),
                        const SizedBox(height: 16),

                        // Tournament Style Selection
                        TournamentStyleCard(
                          selectedStyle: state.tournamentStyle,
                          isTournamentStarted: state.isTournamentStarted,
                          onStyleChanged: (style) {
                            state.setTournamentStyle(style);
                          },
                          isCompact: true,
                        ),
                        const SizedBox(height: 16),

                        // Teams & Groups Navigation Card (replaces both Group and Team cards)
                        TeamsAndGroupsNavigationCard(
                          totalTeams: state.totalTeams,
                          teamsInGroups: state.teamsInGroupsCount,
                          numberOfGroups: state.numberOfGroups,
                          groupsAssigned: state.groupsAssigned,
                          tournamentStyle: state.tournamentStyle,
                          isLocked: state.isTournamentStarted,
                          onNavigateToTeams: () =>
                              _navigateToTeamsPage(context),
                          isCompact: true,
                        ),
                        const SizedBox(height: 16),

                        // Tournament Control Card
                        TournamentControlCard(
                          currentPhase: state.currentPhase,
                          onStartTournament: () =>
                              _showStartConfirmation(context, state),
                          onAdvancePhase: () =>
                              _showPhaseAdvanceConfirmation(context, state),
                          onShuffleMatches: () =>
                              _showShuffleConfirmation(context),
                          onResetTournament: () =>
                              _showResetConfirmation(context, state),
                          isCompact: true,
                        ),
                        const SizedBox(height: 16),

                        // Import/Export Card
                        ImportExportCard(
                          onImportJson: () => _handleImportTeams(context),
                          onExportJson: () => _showExportDialog(context),
                          isCompact: true,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          );
        },
      ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registriert: ${state.totalTeams} Teams'),
            const SizedBox(height: 8),
            const Text(
              'Nach dem Start können keine neuen Teams mehr hinzugefügt werden und der Turniermodus kann nicht mehr geändert werden.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
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
            child: const Text('Starten'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      state.setPhase(TournamentPhase.groupPhase);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turnier gestartet!'),
          backgroundColor: FieldColors.springgreen,
        ),
      );
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
            Text('Phase wechseln?'),
          ],
        ),
        content: Text('Möchtest du zur $nextPhase wechseln?'),
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
            label: const Text('Weiter'),
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
            Text('Spiele würfeln?'),
          ],
        ),
        content: const Text(
          'Die Spielreihenfolge wird zufällig neu gemischt. Bereits eingetragene Ergebnisse bleiben erhalten.',
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du das Turnier wirklich zurücksetzen?'),
            SizedBox(height: 12),
            Text(
              'Alle Spielergebnisse und der Turnierfortschritt werden gelöscht. Teams bleiben erhalten.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Folgende Daten werden exportiert:'),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check, color: FieldColors.springgreen, size: 20),
                SizedBox(width: 8),
                Text('Teams und Gruppen'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check, color: FieldColors.springgreen, size: 20),
                SizedBox(width: 8),
                Text('Spielergebnisse'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check, color: FieldColors.springgreen, size: 20),
                SizedBox(width: 8),
                Text('Turnierstatus'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check, color: FieldColors.springgreen, size: 20),
                SizedBox(width: 8),
                Text('Turniermodus'),
              ],
            ),
          ],
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
}
