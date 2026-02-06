import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

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
