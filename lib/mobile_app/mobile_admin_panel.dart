import 'package:flutter/material.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_state.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_widgets.dart';
import 'package:pongstrong/shared/colors.dart';

/// Mobile version of the Admin Panel
class MobileAdminPanel extends StatefulWidget {
  const MobileAdminPanel({super.key});

  @override
  State<MobileAdminPanel> createState() => _MobileAdminPanelState();
}

class _MobileAdminPanelState extends State<MobileAdminPanel> {
  // Mock state for UI preview - will be connected to real state later
  TournamentPhase _currentPhase = TournamentPhase.notStarted;
  TournamentStyle _selectedStyle = TournamentStyle.groupsAndKnockouts;
  int _teamCount = 16;
  final int _totalMatches = 24;
  int _completedMatches = 8;

  // Mock teams data
  final List<MockTeam> _teams = [
    const MockTeam(
        name: 'Die Ballkünstler',
        member1: 'Max',
        member2: 'Felix',
        groupIndex: 0),
    const MockTeam(
        name: 'Ping Pong Kings',
        member1: 'Anna',
        member2: 'Lisa',
        groupIndex: 0),
    const MockTeam(
        name: 'Tischtennis Tigers',
        member1: 'Tom',
        member2: 'Jan',
        groupIndex: 1),
    const MockTeam(
        name: 'Smash Bros', member1: 'Paul', member2: 'David', groupIndex: 1),
    const MockTeam(
        name: 'Netzkönige', member1: 'Laura', member2: 'Sarah', groupIndex: 2),
    const MockTeam(
        name: 'Spin Masters',
        member1: 'Lukas',
        member2: 'Niklas',
        groupIndex: 2),
    const MockTeam(
        name: 'Die Schläger', member1: 'Julia', member2: 'Emma', groupIndex: 3),
    const MockTeam(
        name: 'Ball Wizards', member1: 'Tim', member2: 'Ben', groupIndex: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnierverwaltung'),
        backgroundColor: GroupPhaseColors.cupred,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Refresh data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Daten aktualisieren...')),
              );
            },
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tournament Status Card
            TournamentStatusCard(
              currentPhase: _currentPhase,
              totalTeams: _teamCount,
              totalMatches: _totalMatches,
              completedMatches: _completedMatches,
              remainingMatches: _totalMatches - _completedMatches,
              isCompact: true,
            ),
            const SizedBox(height: 16),

            // Tournament Style Selection
            TournamentStyleCard(
              selectedStyle: _selectedStyle,
              isTournamentStarted: _currentPhase != TournamentPhase.notStarted,
              onStyleChanged: (style) {
                setState(() {
                  _selectedStyle = style;
                });
              },
              isCompact: true,
            ),
            const SizedBox(height: 16),

            // Team Management Card
            TeamManagementCard(
              teamCount: _teamCount,
              onAddTeam: () => _showAddTeamDialog(context),
              onViewTeams: () => _showTeamsListDialog(context),
              onImportTeams: () => _handleImportTeams(context),
              isCompact: true,
            ),
            const SizedBox(height: 16),

            // Tournament Control Card
            TournamentControlCard(
              currentPhase: _currentPhase,
              onStartTournament: () => _showStartConfirmation(context),
              onAdvancePhase: () => _showPhaseAdvanceConfirmation(context),
              onShuffleMatches: () => _showShuffleConfirmation(context),
              onResetTournament: () => _showResetConfirmation(context),
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
  }

  Future<void> _showAddTeamDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddTeamDialog(),
    );

    if (result != null && context.mounted) {
      setState(() {
        _teamCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Team "${result['name']}" hinzugefügt')),
      );
    }
  }

  Future<void> _showTeamsListDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.groups, color: TreeColors.rebeccapurple),
            const SizedBox(width: 8),
            Text('Teams (${_teams.length})'),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _teams.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Noch keine Teams vorhanden',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final team = _teams[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              TreeColors.rebeccapurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + team.groupIndex),
                            style: const TextStyle(
                              color: TreeColors.rebeccapurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        team.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${team.member1} & ${team.member2}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Team "${team.name}" bearbeiten...')),
                              );
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            color: GroupPhaseColors.steelblue,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Team "${team.name}" löschen...')),
                              );
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            color: GroupPhaseColors.cupred,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddTeamDialog(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Hinzufügen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TreeColors.rebeccapurple,
              side: const BorderSide(color: TreeColors.rebeccapurple),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStartConfirmation(BuildContext context) async {
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
            Text('registriert: $_teamCount Teams'),
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
      setState(() {
        _currentPhase = TournamentPhase.groupPhase;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turnier gestartet!'),
          backgroundColor: FieldColors.springgreen,
        ),
      );
    }
  }

  Future<void> _showPhaseAdvanceConfirmation(BuildContext context) async {
    String nextPhase;
    if (_currentPhase == TournamentPhase.groupPhase) {
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
      setState(() {
        if (_currentPhase == TournamentPhase.groupPhase) {
          _currentPhase = TournamentPhase.knockoutPhase;
        } else {
          _currentPhase = TournamentPhase.finished;
        }
      });
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

  Future<void> _showResetConfirmation(BuildContext context) async {
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
      setState(() {
        _currentPhase = TournamentPhase.notStarted;
        _completedMatches = 0;
      });
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
              // TODO: Implement export
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
