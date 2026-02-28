import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// A node widget showing the winner of a bracket, placed at the root of the tree.
class BracketWinnerNode extends StatelessWidget {
  final Match finalMatch;
  final Color bracketColor;

  const BracketWinnerNode({
    super.key,
    required this.finalMatch,
    required this.bracketColor,
  });

  @override
  Widget build(BuildContext context) {
    final tournamentData =
        Provider.of<TournamentDataState>(context, listen: false);

    final winnerId = finalMatch.done ? finalMatch.getWinnerId() : null;
    final winnerName = winnerId != null && winnerId.isNotEmpty
        ? (tournamentData.getTeam(winnerId)?.name ?? winnerId)
        : null;

    final bool hasWinner = winnerName != null;
    final bgColor = hasWinner
        ? Color.alphaBlend(bracketColor.withAlpha(25), AppColors.surface)
        : AppColors.surface;

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWinner ? bracketColor : bracketColor.withAlpha(76),
          width: hasWinner ? 3 : 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasWinner ? Icons.emoji_events : Icons.emoji_events_outlined,
            color: hasWinner ? bracketColor : bracketColor.withAlpha(100),
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            hasWinner ? winnerName : '???',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hasWinner ? 15 : 13,
              fontWeight: hasWinner ? FontWeight.bold : FontWeight.normal,
              color: hasWinner ? bracketColor : AppColors.textDisabled,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (hasWinner)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Sieger',
                style: TextStyle(
                  fontSize: 11,
                  color: bracketColor.withAlpha(180),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
