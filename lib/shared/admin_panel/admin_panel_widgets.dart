import 'package:flutter/material.dart';
import 'package:pongstrong/shared/colors.dart';
import 'admin_panel_state.dart';

/// Card widget for tournament status display
class TournamentStatusCard extends StatelessWidget {
  final TournamentPhase currentPhase;
  final int totalTeams;
  final int totalMatches;
  final int completedMatches;
  final int remainingMatches;
  final bool isCompact;

  const TournamentStatusCard({
    super.key,
    required this.currentPhase,
    required this.totalTeams,
    required this.totalMatches,
    required this.completedMatches,
    required this.remainingMatches,
    this.isCompact = false,
  });

  String get phaseDisplayName {
    switch (currentPhase) {
      case TournamentPhase.notStarted:
        return 'Nicht gestartet';
      case TournamentPhase.groupPhase:
        return 'Gruppenphase';
      case TournamentPhase.knockoutPhase:
        return 'K.O.-Phase';
      case TournamentPhase.finished:
        return 'Beendet';
    }
  }

  Color get phaseColor {
    switch (currentPhase) {
      case TournamentPhase.notStarted:
        return Colors.grey;
      case TournamentPhase.groupPhase:
        return GroupPhaseColors.steelblue;
      case TournamentPhase.knockoutPhase:
        return TreeColors.rebeccapurple;
      case TournamentPhase.finished:
        return FieldColors.springgreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: phaseColor),
                const SizedBox(width: 8),
                Text(
                  'Turnierstatus',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildStatusRow('Phase:', phaseDisplayName, phaseColor),
            _buildStatusRow('Teams:', '$totalTeams', null),
            _buildStatusRow('Spiele gesamt:', '$totalMatches', null),
            _buildStatusRow(
                'Gespielt:', '$completedMatches', FieldColors.springgreen),
            _buildStatusRow(
                'Ausstehend:',
                '$remainingMatches',
                remainingMatches > 0
                    ? GroupPhaseColors.cupred
                    : FieldColors.springgreen),
            if (totalMatches > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: totalMatches > 0 ? completedMatches / totalMatches : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
              ),
              const SizedBox(height: 4),
              Text(
                '${((completedMatches / totalMatches) * 100).toStringAsFixed(0)}% abgeschlossen',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for tournament style selection
class TournamentStyleCard extends StatelessWidget {
  final TournamentStyle selectedStyle;
  final bool isTournamentStarted;
  final ValueChanged<TournamentStyle>? onStyleChanged;
  final bool isCompact;

  const TournamentStyleCard({
    super.key,
    required this.selectedStyle,
    required this.isTournamentStarted,
    this.onStyleChanged,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: GroupPhaseColors.steelblue),
                const SizedBox(width: 8),
                Text(
                  'Turniermodus',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildStyleOption(
              context,
              TournamentStyle.groupsAndKnockouts,
              'Gruppenphase + K.O.',
              'Teams spielen in Gruppen, dann K.O.-Runden',
              Icons.grid_view,
            ),
            _buildStyleOption(
              context,
              TournamentStyle.knockoutsOnly,
              'Nur K.O.-Phase',
              'Direktes Ausscheiden nach Niederlage',
              Icons.account_tree,
            ),
            _buildStyleOption(
              context,
              TournamentStyle.everyoneVsEveryone,
              'Jeder gegen Jeden',
              'Alle Teams spielen gegeneinander',
              Icons.sync_alt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleOption(
    BuildContext context,
    TournamentStyle style,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = selectedStyle == style;
    final isDisabled = isTournamentStarted;

    return InkWell(
      onTap: isDisabled ? null : () => onStyleChanged?.call(style),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? GroupPhaseColors.steelblue.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? GroupPhaseColors.steelblue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? Colors.grey
                  : (isSelected
                      ? GroupPhaseColors.steelblue
                      : Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isDisabled ? Colors.grey : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                isDisabled ? Icons.lock : Icons.check_circle,
                color: isDisabled ? Colors.grey : GroupPhaseColors.steelblue,
              ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for team management
class TeamManagementCard extends StatelessWidget {
  final int teamCount;
  final VoidCallback? onAddTeam;
  final VoidCallback? onViewTeams;
  final VoidCallback? onImportTeams;
  final bool isCompact;

  const TeamManagementCard({
    super.key,
    required this.teamCount,
    this.onAddTeam,
    this.onViewTeams,
    this.onImportTeams,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: TreeColors.rebeccapurple),
                const SizedBox(width: 8),
                Text(
                  'Teams verwalten',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.people, size: 40, color: Colors.grey),
                  const SizedBox(width: 16),
                  Text(
                    '$teamCount Teams',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddTeam,
                icon: const Icon(Icons.add),
                label: const Text('Team hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TreeColors.rebeccapurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewTeams,
                icon: const Icon(Icons.list),
                label: const Text('Teams anzeigen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TreeColors.rebeccapurple,
                  side: const BorderSide(color: TreeColors.rebeccapurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onImportTeams,
                icon: const Icon(Icons.upload_file),
                label: const Text('Teams importieren'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TreeColors.rebeccapurple,
                  side: const BorderSide(color: TreeColors.rebeccapurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for tournament control actions
class TournamentControlCard extends StatelessWidget {
  final TournamentPhase currentPhase;
  final VoidCallback? onStartTournament;
  final VoidCallback? onAdvancePhase;
  final VoidCallback? onShuffleMatches;
  final VoidCallback? onResetTournament;
  final bool isCompact;

  const TournamentControlCard({
    super.key,
    required this.currentPhase,
    this.onStartTournament,
    this.onAdvancePhase,
    this.onShuffleMatches,
    this.onResetTournament,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNotStarted = currentPhase == TournamentPhase.notStarted;
    final isFinished = currentPhase == TournamentPhase.finished;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline,
                    color: GroupPhaseColors.cupred),
                const SizedBox(width: 8),
                Text(
                  'Turniersteuerung',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (isNotStarted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStartTournament,
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'Turnier starten',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GroupPhaseColors.cupred,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else if (!isFinished) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAdvancePhase,
                  icon: const Icon(Icons.skip_next, size: 28),
                  label: const Text(
                    'Nächste Phase',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TreeColors.rebeccapurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FieldColors.springgreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FieldColors.springgreen),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events,
                        color: FieldColors.springgreen, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Turnier beendet!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: FieldColors.springgreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isNotStarted ? null : onShuffleMatches,
                icon: const Icon(Icons.casino),
                label: const Text('Spiele würfeln'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // Reset button - only show when tournament has started
            if (!isNotStarted) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onResetTournament,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Turnier zurücksetzen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GroupPhaseColors.cupred,
                    side: const BorderSide(color: GroupPhaseColors.cupred),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card widget for match result editing
class MatchEditingCard extends StatelessWidget {
  final VoidCallback? onEditGroupMatches;
  final VoidCallback? onEditKnockoutMatches;
  final bool isCompact;

  const MatchEditingCard({
    super.key,
    this.onEditGroupMatches,
    this.onEditKnockoutMatches,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: TableColors.orange),
                const SizedBox(width: 8),
                Text(
                  'Ergebnisse bearbeiten',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nachträgliche Änderung von eingetragenen Spielergebnissen',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditGroupMatches,
                    icon: const Icon(Icons.grid_view),
                    label: const Text('Gruppenphase'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GroupPhaseColors.steelblue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditKnockoutMatches,
                    icon: const Icon(Icons.account_tree),
                    label: const Text('Turnierbaum'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TreeColors.rebeccapurple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for import/export functionality
class ImportExportCard extends StatelessWidget {
  final VoidCallback? onImportJson;
  final VoidCallback? onExportJson;
  final bool isCompact;

  const ImportExportCard({
    super.key,
    this.onImportJson,
    this.onExportJson,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: TableColors.turquoise),
                const SizedBox(width: 8),
                Text(
                  'Import / Export',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Turnierfortschritt speichern oder wiederherstellen',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImportJson,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('JSON Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TableColors.turquoise,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onExportJson,
                    icon: const Icon(Icons.download),
                    label: const Text('JSON Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GroupPhaseColors.steelblue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding a new team
class AddTeamDialog extends StatefulWidget {
  const AddTeamDialog({super.key});

  @override
  State<AddTeamDialog> createState() => _AddTeamDialogState();
}

class _AddTeamDialogState extends State<AddTeamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _member1Controller = TextEditingController();
  final _member2Controller = TextEditingController();
  int _selectedGroup = 0;

  @override
  void dispose() {
    _teamNameController.dispose();
    _member1Controller.dispose();
    _member2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.group_add, color: FieldColors.springgreen),
          SizedBox(width: 8),
          Text('Team hinzufügen'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(
                  labelText: 'Teamname',
                  hintText: 'z.B. Die Bierpong Könige',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bitte Teamnamen eingeben';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _member1Controller,
                decoration: const InputDecoration(
                  labelText: 'Spieler 1',
                  hintText: 'Name des ersten Spielers',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _member2Controller,
                decoration: const InputDecoration(
                  labelText: 'Spieler 2',
                  hintText: 'Name des zweiten Spielers',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedGroup,
                decoration: const InputDecoration(
                  labelText: 'Gruppe',
                  prefixIcon: Icon(Icons.grid_view),
                  border: OutlineInputBorder(),
                ),
                items: List.generate(8, (index) {
                  return DropdownMenuItem(
                    value: index,
                    child: Text('Gruppe ${String.fromCharCode(65 + index)}'),
                  );
                }),
                onChanged: (value) {
                  setState(() {
                    _selectedGroup = value ?? 0;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // TODO: Implement actual team addition
              Navigator.of(context).pop({
                'name': _teamNameController.text,
                'member1': _member1Controller.text,
                'member2': _member2Controller.text,
                'group': _selectedGroup,
              });
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Hinzufügen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: GroupPhaseColors.cupred,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Mock team data for preview
class MockTeam {
  final String name;
  final String member1;
  final String member2;
  final int groupIndex;

  const MockTeam({
    required this.name,
    required this.member1,
    required this.member2,
    required this.groupIndex,
  });
}

/// Widget displaying the list of all teams in the admin panel
class TeamsListCard extends StatelessWidget {
  final List<MockTeam> teams;
  final VoidCallback? onAddTeam;
  final Function(MockTeam)? onEditTeam;
  final Function(MockTeam)? onDeleteTeam;
  final bool isCompact;

  const TeamsListCard({
    super.key,
    required this.teams,
    this.onAddTeam,
    this.onEditTeam,
    this.onDeleteTeam,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: TreeColors.rebeccapurple),
                const SizedBox(width: 8),
                Text(
                  'Alle Teams (${teams.length})',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onAddTeam,
                  icon: const Icon(Icons.add_circle),
                  color: TreeColors.rebeccapurple,
                  tooltip: 'Team hinzufügen',
                ),
              ],
            ),
            const Divider(),
            if (teams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.group_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Noch keine Teams vorhanden',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: teams.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final team = teams[index];
                  return _TeamListTile(
                    team: team,
                    onEdit: onEditTeam != null ? () => onEditTeam!(team) : null,
                    onDelete:
                        onDeleteTeam != null ? () => onDeleteTeam!(team) : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamListTile extends StatelessWidget {
  final MockTeam team;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TeamListTile({
    required this.team,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
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
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 20),
            color: GroupPhaseColors.steelblue,
            tooltip: 'Bearbeiten',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 20),
            color: GroupPhaseColors.cupred,
            tooltip: 'Löschen',
          ),
        ],
      ),
    );
  }
}
