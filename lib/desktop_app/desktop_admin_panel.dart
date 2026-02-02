import 'package:flutter/material.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_state.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_widgets.dart';
import 'package:pongstrong/shared/colors.dart';

/// Desktop version of the Admin Panel with wider layout
class DesktopAdminPanel extends StatefulWidget {
  const DesktopAdminPanel({super.key});

  @override
  State<DesktopAdminPanel> createState() => _DesktopAdminPanelState();
}

class _DesktopAdminPanelState extends State<DesktopAdminPanel> {
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
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          _buildHeader(context),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      // Responsive layout based on available width
                      if (constraints.maxWidth > 1200) {
                        return _buildThreeColumnLayout();
                      } else {
                        return _buildTwoColumnLayout();
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
  }

  Widget _buildHeader(BuildContext context) {
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

          // Status indicator
          _buildPhaseIndicator(),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    Color phaseColor;
    String phaseText;

    switch (_currentPhase) {
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

  Widget _buildThreeColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: [
              TournamentStatusCard(
                currentPhase: _currentPhase,
                totalTeams: _teamCount,
                totalMatches: _totalMatches,
                completedMatches: _completedMatches,
                remainingMatches: _totalMatches - _completedMatches,
              ),
              const SizedBox(height: 16),
              TournamentControlCard(
                currentPhase: _currentPhase,
                onStartTournament: () => _showStartConfirmation(context),
                onAdvancePhase: () => _showPhaseAdvanceConfirmation(context),
                onShuffleMatches: () => _showShuffleConfirmation(context),
                onResetTournament: () => _showResetConfirmation(context),
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
                selectedStyle: _selectedStyle,
                isTournamentStarted:
                    _currentPhase != TournamentPhase.notStarted,
                onStyleChanged: (style) {
                  setState(() {
                    _selectedStyle = style;
                  });
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

        // Right column
        Expanded(
          child: Column(
            children: [
              TeamManagementCard(
                teamCount: _teamCount,
                onAddTeam: () => _showAddTeamDialog(context),
                onViewTeams: () {
                  // Show teams in a dialog
                  _showTeamsListDialog(context);
                },
                onImportTeams: () => _handleImportTeams(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: [
              TournamentStatusCard(
                currentPhase: _currentPhase,
                totalTeams: _teamCount,
                totalMatches: _totalMatches,
                completedMatches: _completedMatches,
                remainingMatches: _totalMatches - _completedMatches,
              ),
              const SizedBox(height: 16),
              TournamentStyleCard(
                selectedStyle: _selectedStyle,
                isTournamentStarted:
                    _currentPhase != TournamentPhase.notStarted,
                onStyleChanged: (style) {
                  setState(() {
                    _selectedStyle = style;
                  });
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

        // Right column
        Expanded(
          child: Column(
            children: [
              TeamManagementCard(
                teamCount: _teamCount,
                onAddTeam: () => _showAddTeamDialog(context),
                onViewTeams: () {
                  // Show teams in a dialog
                  _showTeamsListDialog(context);
                },
                onImportTeams: () => _handleImportTeams(context),
              ),
              const SizedBox(height: 16),
              TournamentControlCard(
                currentPhase: _currentPhase,
                onStartTournament: () => _showStartConfirmation(context),
                onAdvancePhase: () => _showPhaseAdvanceConfirmation(context),
                onShuffleMatches: () => _showShuffleConfirmation(context),
                onResetTournament: () => _showResetConfirmation(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddTeamDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddTeamDialog(),
    );

    if (result != null) {
      setState(() {
        _teamCount++;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team "${result['name']}" hinzugefügt')),
        );
      }
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
            Text('Alle Teams (${_teams.length})'),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: _teams.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Noch keine Teams vorhanden',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final team = _teams[index];
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              TreeColors.rebeccapurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + team.groupIndex),
                            style: const TextStyle(
                              color: TreeColors.rebeccapurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        team.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${team.member1} & ${team.member2}',
                        style: TextStyle(color: Colors.grey[600]),
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
                            icon: const Icon(Icons.edit, size: 20),
                            color: GroupPhaseColors.steelblue,
                            tooltip: 'Bearbeiten',
                          ),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Team "${team.name}" löschen...')),
                              );
                            },
                            icon: const Icon(Icons.delete, size: 20),
                            color: GroupPhaseColors.cupred,
                            tooltip: 'Löschen',
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
            icon: const Icon(Icons.add),
            label: const Text('Team hinzufügen'),
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registriert: $_teamCount Teams'),
              const SizedBox(height: 8),
              Text('Turniermodus: ${_getStyleDisplayName(_selectedStyle)}'),
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
      setState(() {
        _currentPhase = TournamentPhase.groupPhase;
      });
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

  String _getStyleDisplayName(TournamentStyle style) {
    switch (style) {
      case TournamentStyle.groupsAndKnockouts:
        return 'Gruppenphase + K.O.';
      case TournamentStyle.knockoutsOnly:
        return 'Nur K.O.-Phase';
      case TournamentStyle.everyoneVsEveryone:
        return 'Jeder gegen Jeden';
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
