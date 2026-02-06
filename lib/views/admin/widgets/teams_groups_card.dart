import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

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
