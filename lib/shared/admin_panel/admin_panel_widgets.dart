import 'package:flutter/material.dart';
import 'package:pongstrong/shared/colors.dart';
import 'admin_panel_state.dart';

/// Combined card widget for Teams & Groups navigation
/// Shows summary and provides navigation to the teams management page
class TeamsAndGroupsNavigationCard extends StatelessWidget {
  final int totalTeams;
  final int teamsInGroups;
  final int numberOfGroups;
  final bool groupsAssigned;
  final TournamentStyle tournamentStyle;
  final bool isLocked;
  final VoidCallback? onNavigateToTeams;
  final bool isCompact;

  const TeamsAndGroupsNavigationCard({
    super.key,
    required this.totalTeams,
    required this.teamsInGroups,
    required this.numberOfGroups,
    required this.groupsAssigned,
    required this.tournamentStyle,
    this.isLocked = false,
    this.onNavigateToTeams,
    this.isCompact = false,
  });

  bool get _isGroupPhase =>
      tournamentStyle == TournamentStyle.groupsAndKnockouts;

  String get _groupStatus {
    if (!_isGroupPhase) return 'Nur K.O.-Phase';
    if (totalTeams == 0) return 'Keine Teams vorhanden';
    if (!groupsAssigned || teamsInGroups == 0) {
      return 'Gruppen nicht zugewiesen';
    }
    if (teamsInGroups < totalTeams) {
      return '$teamsInGroups/$totalTeams Teams zugewiesen';
    }
    return 'Alle Teams zugewiesen';
  }

  Color get _statusColor {
    if (!_isGroupPhase) return Colors.grey;
    if (totalTeams == 0) return Colors.grey;
    if (!groupsAssigned || teamsInGroups == 0) return GroupPhaseColors.cupred;
    if (teamsInGroups < totalTeams) return Colors.orange;
    return FieldColors.springgreen;
  }

  IconData get _statusIcon {
    if (!_isGroupPhase) return Icons.remove_circle_outline;
    if (totalTeams == 0) return Icons.group_off;
    if (!groupsAssigned || teamsInGroups == 0) return Icons.warning_amber;
    if (teamsInGroups < totalTeams) return Icons.pending;
    return Icons.check_circle;
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
                const Icon(Icons.groups, color: TreeColors.rebeccapurple),
                const SizedBox(width: 8),
                Text(
                  'Teams & Gruppen',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLocked)
                  const Tooltip(
                    message: 'Turnier gestartet',
                    child: Icon(Icons.lock, color: Colors.grey, size: 20),
                  ),
              ],
            ),
            const Divider(),

            // Teams count
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.people, color: TreeColors.rebeccapurple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalTeams Teams',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        totalTeams == 0
                            ? 'Tippe um Teams hinzuzufügen'
                            : 'registriert',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Group status (only if group phase)
            if (_isGroupPhase) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _groupStatus,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (groupsAssigned && numberOfGroups > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              TreeColors.rebeccapurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$numberOfGroups Gruppen',
                          style: const TextStyle(
                            color: TreeColors.rebeccapurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Navigate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNavigateToTeams,
                icon: const Icon(Icons.edit_note),
                label: Text(isLocked ? 'Teams anzeigen' : 'Teams verwalten'),
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
          ],
        ),
      ),
    );
  }
}

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

/// Card widget for group assignment management
class GroupAssignmentCard extends StatelessWidget {
  final TournamentStyle tournamentStyle;
  final bool groupsAssigned;
  final int numberOfGroups;
  final int totalTeams;
  final List<List<String>> groups;
  final VoidCallback? onAssignRandomly;
  final VoidCallback? onManualAssign;
  final VoidCallback? onClearGroups;
  final Function(int)? onNumberOfGroupsChanged;
  final bool isCompact;
  final bool isLocked;

  const GroupAssignmentCard({
    super.key,
    required this.tournamentStyle,
    required this.groupsAssigned,
    required this.numberOfGroups,
    required this.totalTeams,
    required this.groups,
    this.onAssignRandomly,
    this.onManualAssign,
    this.onClearGroups,
    this.onNumberOfGroupsChanged,
    this.isCompact = false,
    this.isLocked = false,
  });

  bool get _isGroupPhaseSelected =>
      tournamentStyle == TournamentStyle.groupsAndKnockouts;

  String get _statusText {
    if (!_isGroupPhaseSelected) {
      return 'Keine Gruppenphase ausgewählt';
    }
    if (!groupsAssigned) {
      return 'Gruppen müssen noch zugewiesen werden';
    }
    // Count teams in groups
    int teamsInGroups = 0;
    for (var group in groups) {
      teamsInGroups += group.length;
    }
    if (teamsInGroups < totalTeams) {
      return 'Nicht alle Teams zugewiesen ($teamsInGroups/$totalTeams)';
    }
    return 'Alle Teams zugewiesen';
  }

  Color get _statusColor {
    if (!_isGroupPhaseSelected) {
      return Colors.grey;
    }
    if (!groupsAssigned) {
      return GroupPhaseColors.cupred;
    }
    int teamsInGroups = 0;
    for (var group in groups) {
      teamsInGroups += group.length;
    }
    if (teamsInGroups < totalTeams) {
      return Colors.orange;
    }
    return FieldColors.springgreen;
  }

  IconData get _statusIcon {
    if (!_isGroupPhaseSelected) {
      return Icons.remove_circle_outline;
    }
    if (!groupsAssigned) {
      return Icons.warning_amber;
    }
    int teamsInGroups = 0;
    for (var group in groups) {
      teamsInGroups += group.length;
    }
    if (teamsInGroups < totalTeams) {
      return Icons.pending;
    }
    return Icons.check_circle;
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
                const Icon(Icons.grid_view, color: GroupPhaseColors.steelblue),
                const SizedBox(width: 8),
                Text(
                  'Gruppeneinteilung',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLocked)
                  const Tooltip(
                    message: 'Turnier gestartet - Gruppen gesperrt',
                    child: Icon(Icons.lock, color: Colors.grey, size: 20),
                  ),
              ],
            ),
            const Divider(),
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon, color: _statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isGroupPhaseSelected && !isLocked) ...[
              const SizedBox(height: 16),
              // Number of groups selector
              Row(
                children: [
                  const Text('Anzahl Gruppen:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: numberOfGroups,
                      isDense: true,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(8, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        );
                      }),
                      onChanged: isLocked
                          ? null
                          : (value) {
                              if (value != null &&
                                  onNumberOfGroupsChanged != null) {
                                onNumberOfGroupsChanged!(value);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          isLocked || totalTeams == 0 ? null : onAssignRandomly,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Zufällig'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GroupPhaseColors.steelblue,
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
                      onPressed:
                          isLocked || totalTeams == 0 ? null : onManualAssign,
                      icon: const Icon(Icons.edit),
                      label: const Text('Manuell'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TreeColors.rebeccapurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (groupsAssigned) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: isLocked ? null : onClearGroups,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Gruppen zurücksetzen'),
                    style: TextButton.styleFrom(
                      foregroundColor: GroupPhaseColors.cupred,
                    ),
                  ),
                ),
              ],
            ],
            if (!_isGroupPhaseSelected) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Wählen Sie "Gruppenphase + K.O." als Turniermodus, um Gruppen zuzuweisen.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog for manual group assignment
class ManualGroupAssignmentDialog extends StatefulWidget {
  final List<TeamInfo> teams;
  final List<List<String>> currentGroups;
  final int numberOfGroups;
  final Function(String teamId, int groupIndex) onAssignTeam;

  const ManualGroupAssignmentDialog({
    super.key,
    required this.teams,
    required this.currentGroups,
    required this.numberOfGroups,
    required this.onAssignTeam,
  });

  @override
  State<ManualGroupAssignmentDialog> createState() =>
      _ManualGroupAssignmentDialogState();
}

/// Simple team info class for the dialog
class TeamInfo {
  final String id;
  final String name;
  final String member1;
  final String member2;

  const TeamInfo({
    required this.id,
    required this.name,
    required this.member1,
    required this.member2,
  });
}

class _ManualGroupAssignmentDialogState
    extends State<ManualGroupAssignmentDialog> {
  late Map<String, int?> _teamGroupAssignments;

  @override
  void initState() {
    super.initState();
    _initializeAssignments();
  }

  void _initializeAssignments() {
    _teamGroupAssignments = {};
    for (var team in widget.teams) {
      _teamGroupAssignments[team.id] = _findGroupForTeam(team.id);
    }
  }

  int? _findGroupForTeam(String teamId) {
    for (int i = 0; i < widget.currentGroups.length; i++) {
      if (widget.currentGroups[i].contains(teamId)) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final unassignedTeams =
        widget.teams.where((t) => _teamGroupAssignments[t.id] == null).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: TreeColors.rebeccapurple),
          SizedBox(width: 8),
          Text('Manuelle Gruppeneinteilung'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unassignedTeams.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${unassignedTeams.length} Team(s) nicht zugewiesen',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...widget.teams.map((team) => _buildTeamRow(team)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Widget _buildTeamRow(TeamInfo team) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${team.member1}, ${team.member2}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _teamGroupAssignments[team.id],
              isDense: true,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('---', style: TextStyle(color: Colors.grey)),
                ),
                ...List.generate(widget.numberOfGroups, (index) {
                  return DropdownMenuItem(
                    value: index,
                    child: Text('Gruppe ${String.fromCharCode(65 + index)}'),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _teamGroupAssignments[team.id] = value;
                });
                if (value != null) {
                  widget.onAssignTeam(team.id, value);
                }
              },
            ),
          ),
        ],
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
              Navigator.of(context).pop({
                'name': _teamNameController.text,
                'member1': _member1Controller.text,
                'member2': _member2Controller.text,
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
