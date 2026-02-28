import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// A node widget representing a single match in the knockout bracket tree.
class BracketMatchNode extends StatelessWidget {
  final Match match;
  final Color borderColor;
  final bool showTableNumbers;

  /// Called when an admin taps an editable match; provides both resolved team names.
  final void Function(String team1Name, String team2Name)? onEdit;

  const BracketMatchNode({
    super.key,
    required this.match,
    required this.borderColor,
    required this.showTableNumbers,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tournamentData =
        Provider.of<TournamentDataState>(context, listen: false);
    final isAdmin = Provider.of<AuthState>(context, listen: false).isAdmin;

    String teamName(String id) {
      if (id.isEmpty) return '';
      return tournamentData.getTeam(id)?.name ?? id;
    }

    final team1Name = teamName(match.teamId1);
    final team2Name = teamName(match.teamId2);

    final bool isReady = match.teamId1.isNotEmpty && match.teamId2.isNotEmpty;
    final bool canEdit = isAdmin && match.done;

    return InkWell(
      onTap: canEdit ? () => onEdit?.call(team1Name, team2Name) : null,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isReady ? borderColor : borderColor.withAlpha(76),
            width: isReady ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTableNumbers && match.tableNumber > 0)
              _TableBadge(tableNumber: match.tableNumber),
            _TeamRow(
              name: team1Name,
              score: match.score1,
              teamId: match.teamId1,
              match: match,
            ),
            const Divider(height: 8),
            _TeamRow(
              name: team2Name,
              score: match.score2,
              teamId: match.teamId2,
              match: match,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableBadge extends StatelessWidget {
  final int tableNumber;

  const _TableBadge({required this.tableNumber});

  @override
  Widget build(BuildContext context) {
    final color = TableColors.forIndex(tableNumber - 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(38),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: Text(
              'Tisch $tableNumber',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final int score;
  final String teamId;
  final Match match;

  const _TeamRow({
    required this.name,
    required this.score,
    required this.teamId,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            textAlign: match.done ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              fontWeight: match.done && match.getWinnerId() == teamId
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: teamId.isEmpty ? AppColors.textDisabled : AppColors.shadow,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (match.done) Text(displayScore(score)),
      ],
    );
  }
}
