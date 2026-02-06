import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

/// Card widget for tournament control actions
class TournamentControlCard extends StatelessWidget {
  final TournamentPhase currentPhase;
  final VoidCallback? onStartTournament;
  final VoidCallback? onAdvancePhase;
  final VoidCallback? onResetTournament;
  final bool isCompact;

  const TournamentControlCard({
    super.key,
    required this.currentPhase,
    this.onStartTournament,
    this.onAdvancePhase,
    this.onResetTournament,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNotStarted = currentPhase == TournamentPhase.notStarted;
    final isGroupPhase = currentPhase == TournamentPhase.groupPhase;
    final isKnockoutPhase = currentPhase == TournamentPhase.knockoutPhase;
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
            ] else if (isGroupPhase) ...[
              // Show "Zur K.O.-Phase" button only during group phase
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAdvancePhase,
                  icon: const Icon(Icons.skip_next, size: 28),
                  label: const Text(
                    'Zur K.O.-Phase',
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
            ] else if (isKnockoutPhase) ...[
              // K.O. phase in progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TreeColors.rebeccapurple),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_esports,
                        color: TreeColors.rebeccapurple, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'K.O.-Phase läuft',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TreeColors.rebeccapurple,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isFinished) ...[
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
            // Reset button - only show when tournament has started
            if (!isNotStarted) ...[
              const SizedBox(height: 12),
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
