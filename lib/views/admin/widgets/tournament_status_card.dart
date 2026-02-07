import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

/// Card widget for tournament status display
class TournamentStatusCard extends StatelessWidget {
  final TournamentPhase currentPhase;
  final TournamentStyle tournamentStyle;
  final int totalTeams;
  final int totalMatches;
  final int completedMatches;
  final int remainingMatches;
  final bool isCompact;

  const TournamentStatusCard({
    super.key,
    required this.currentPhase,
    this.tournamentStyle = TournamentStyle.groupsAndKnockouts,
    required this.totalTeams,
    required this.totalMatches,
    required this.completedMatches,
    required this.remainingMatches,
    this.isCompact = false,
  });

  String get phaseDisplayName {
    // For single-mode tournaments, show the mode name
    if (tournamentStyle == TournamentStyle.everyoneVsEveryone) {
      if (currentPhase == TournamentPhase.finished) return 'Beendet';
      return 'Jeder gegen Jeden';
    }
    if (tournamentStyle == TournamentStyle.knockoutsOnly) {
      if (currentPhase == TournamentPhase.finished) return 'Beendet';
      return 'Nur K.O.-Phase';
    }
    // For Group+KO mode, show the phase
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
    // For single-mode tournaments, use consistent colors
    if (tournamentStyle == TournamentStyle.everyoneVsEveryone) {
      return currentPhase == TournamentPhase.finished
          ? FieldColors.springgreen
          : GroupPhaseColors.steelblue;
    }
    if (tournamentStyle == TournamentStyle.knockoutsOnly) {
      return currentPhase == TournamentPhase.finished
          ? FieldColors.springgreen
          : TreeColors.rebeccapurple;
    }
    // For Group+KO mode, color by phase
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
