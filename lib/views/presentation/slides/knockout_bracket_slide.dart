import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';

/// Slide showing a knockout bracket overview for a specific league.
///
/// Displays rounds from left to right with match results,
/// styled after the FieldView card pattern used in the main app.
class KnockoutBracketSlide extends StatelessWidget {
  final TournamentDataState data;
  final BracketKey bracketKey;

  const KnockoutBracketSlide({
    super.key,
    required this.data,
    required this.bracketKey,
  });

  static Color _colorForBracket(BracketKey key) {
    switch (key) {
      case BracketKey.gold:
        return TreeColors.rebeccapurple;
      case BracketKey.silver:
        return TreeColors.royalblue;
      case BracketKey.bronze:
        return TreeColors.bronze;
      case BracketKey.extra:
        return TreeColors.hotpink;
    }
  }

  KnockoutBracket? _getBracket() {
    final ko = data.knockouts;
    switch (bracketKey) {
      case BracketKey.gold:
        return ko.champions;
      case BracketKey.silver:
        return ko.europa;
      case BracketKey.bronze:
        return ko.conference;
      case BracketKey.extra:
        return null; // Super cup handled separately
    }
  }

  @override
  Widget build(BuildContext context) {
    final bracketName = data.knockouts.getBracketName(bracketKey);
    final color = _colorForBracket(bracketKey);

    // Super cup: special layout
    if (bracketKey == BracketKey.extra) {
      return _buildSuperCupSlide(bracketName, color);
    }

    final bracket = _getBracket();
    if (bracket == null || bracket.rounds.isEmpty) {
      return Center(
        child: Text(
          '$bracketName - Keine Daten',
          style: const TextStyle(fontSize: 28, color: AppColors.textSecondary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(width: 3, color: color),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FieldView-style header
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bracketName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.textSecondary,
                          offset: Offset(1, 1),
                          blurRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bracket body
            Expanded(
              child: Container(
                color: FieldColors.fieldbackground,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildBracketView(bracket, color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketView(KnockoutBracket bracket, Color color) {
    final roundNames = _roundNames(bracket.rounds.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int r = 0; r < bracket.rounds.length; r++)
                  _buildRound(
                    bracket.rounds[r],
                    roundNames[r],
                    color,
                    constraints.maxHeight,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRound(
      List<Match> matches, String roundName, Color color, double maxHeight) {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          // Fixed-height round name area so all rounds align evenly
          SizedBox(
            height: 36,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  roundName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Match cards – centered vertically in remaining space
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: matches
                  .map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _BracketMatchCard(
                          match: m,
                          data: data,
                          color: color,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _roundNames(int roundCount) {
    if (roundCount <= 0) return [];
    final names = <String>[];
    for (int i = 0; i < roundCount; i++) {
      final remaining = roundCount - i;
      if (remaining == 1) {
        names.add('Finale');
      } else if (remaining == 2) {
        names.add('Halbfinale');
      } else if (remaining == 3) {
        names.add('Viertelfinale');
      } else {
        names.add('Runde ${i + 1}');
      }
    }
    return names;
  }

  Widget _buildSuperCupSlide(String bracketName, Color color) {
    final matches = data.knockouts.superCup.matches;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(width: 3, color: color),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  bracketName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppColors.textSecondary,
                        offset: Offset(1, 1),
                        blurRadius: 1.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Body
            Expanded(
              child: ColoredBox(
                color: FieldColors.fieldbackground,
                child: Center(
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: matches.map((m) {
                      return _BracketMatchCard(
                        match: m,
                        data: data,
                        color: color,
                        large: true,
                      );
                    }).toList(),
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

class _BracketMatchCard extends StatelessWidget {
  final Match match;
  final TournamentDataState data;
  final Color color;
  final bool large;

  const _BracketMatchCard({
    required this.match,
    required this.data,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final team1 = data.getTeam(match.teamId1)?.name ??
        (match.teamId1.isNotEmpty ? match.teamId1 : '—');
    final team2 = data.getTeam(match.teamId2)?.name ??
        (match.teamId2.isNotEmpty ? match.teamId2 : '—');

    final fontSize = large ? 18.0 : 14.0;
    final scoreFontSize = large ? 22.0 : 16.0;
    final width = large ? 300.0 : 200.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(large ? 16 : 10),
      decoration: BoxDecoration(
        color: match.done ? color.withAlpha(15) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.done ? color.withAlpha(100) : AppColors.grey300,
          width: match.done ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            team1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: match.done && match.getWinnerId() == match.teamId1
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (match.done)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${match.score1} : ${match.score2}',
                style: TextStyle(
                  fontSize: scoreFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'vs',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          Text(
            team2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: match.done && match.getWinnerId() == match.teamId2
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
