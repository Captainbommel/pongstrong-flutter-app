import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';

/// Card widget for tournament style selection
class TournamentStyleCard extends StatelessWidget {
  final TournamentStyle selectedStyle;
  final bool isTournamentStarted;
  final ValueChanged<TournamentStyle>? onStyleChanged;
  final String? selectedRuleset;
  final ValueChanged<String?>? onRulesetChanged;
  final bool isCompact;

  const TournamentStyleCard({
    super.key,
    required this.selectedStyle,
    required this.isTournamentStarted,
    this.onStyleChanged,
    this.selectedRuleset,
    this.onRulesetChanged,
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
                    color: GroupPhaseColors.steelblue,
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
            const Divider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Regelwerk',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: GroupPhaseColors.steelblue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: selectedRuleset,
                    focusColor: Colors.transparent,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: GroupPhaseColors.steelblue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: GroupPhaseColors.steelblue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: GroupPhaseColors.steelblue, width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Keine Regeln anzeigen'),
                      ),
                      DropdownMenuItem(
                        value: 'bmt-cup',
                        child: Text('BMT-Cup Regeln'),
                      ),
                    ],
                    onChanged: onRulesetChanged,
                    hint: const Text('Regelwerk wählen'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wähle ein Regelwerk zur Anzeige im Navigationsmenü',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
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
