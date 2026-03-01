import 'package:flutter/material.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/models/match/scoring.dart';
import 'package:pongstrong/utils/colors.dart';

class MatchCard extends StatelessWidget {
  final int matchIndex;
  final Match match;
  final String team1Name;
  final String team2Name;
  final VoidCallback? onEditTap;

  const MatchCard({
    super.key,
    required this.matchIndex,
    required this.match,
    required this.team1Name,
    required this.team2Name,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = match.done;

    return GestureDetector(
      onTap: onEditTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.surface
              : GroupPhaseColors.grouppurple.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone
                ? GroupPhaseColors.steelblue
                : GroupPhaseColors.grouppurple,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Checkmark or match index
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check_circle,
                  color: GroupPhaseColors.steelblue,
                  size: 24,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '$matchIndex.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: GroupPhaseColors.grouppurple,
                  ),
                ),
              ),
            // Teams and scores
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamRow(team1Name, match.score1, isDone),
                  const SizedBox(height: 4),
                  _buildTeamRow(team2Name, match.score2, isDone),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Table number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? GroupPhaseColors.steelblue
                    : GroupPhaseColors.grouppurple.withAlpha(150),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  match.tableNumber.toString(),
                  style: const TextStyle(
                    color: AppColors.textOnColored,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(String teamName, int score, bool isDone) {
    return Row(
      children: [
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isDone) ...[
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 20,
            decoration: BoxDecoration(
              color: GroupPhaseColors.cupred.withAlpha(100),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              displayScore(score),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
