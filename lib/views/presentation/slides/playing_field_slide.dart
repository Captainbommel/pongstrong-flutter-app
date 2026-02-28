import 'package:flutter/material.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';

/// Slide showing currently running matches on the playing field.
///
/// Designed for beamer / full-screen presentation: large text, no controls.
/// Styled after the FieldView card pattern used in the main app.
///
/// Uses [AnimatedSwitcher] so that when the set of running matches changes
/// (new match starts / match finishes) the content fades smoothly instead of
/// popping in abruptly.
class PlayingFieldSlide extends StatelessWidget {
  final TournamentDataState data;

  const PlayingFieldSlide({super.key, required this.data});

  /// Stable key derived from the sorted list of currently-playing match IDs.
  /// Every time this key changes the [AnimatedSwitcher] triggers a crossfade.
  String _contentKey(List<Match> playing) {
    final ids = playing.map((m) => m.id).toList()..sort();
    return ids.join(',');
  }

  @override
  Widget build(BuildContext context) {
    final playing = data.matchQueue.playing;

    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'Laufende Spiele',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: GroupPhaseColors.cupred,
            shadows: [
              Shadow(
                color: AppColors.shadowLight,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 120,
          height: 3,
          decoration: BoxDecoration(
            color: GroupPhaseColors.cupred,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: playing.isEmpty
                ? _emptyState('Keine laufenden Spiele')
                : Center(
                    key: ValueKey(_contentKey(playing)),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: playing.map((match) {
                        final team1 =
                            data.getTeam(match.teamId1)?.name ?? match.teamId1;
                        final team2 =
                            data.getTeam(match.teamId2)?.name ?? match.teamId2;
                        final color =
                            TableColors.forIndex(match.tableNumber - 1);

                        return _MatchCard(
                          team1: team1,
                          team2: team2,
                          tableNumber: match.tableNumber,
                          tableColor: color,
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
      key: const ValueKey('empty'),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 28,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final String team1;
  final String team2;
  final int tableNumber;
  final Color tableColor;

  const _MatchCard({
    required this.team1,
    required this.team2,
    required this.tableNumber,
    required this.tableColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(width: 3, color: tableColor),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header with table number – mirrors FieldView header
            Container(
              color: tableColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Tisch $tableNumber',
                  style: const TextStyle(
                    fontSize: 22,
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
            // Body with team names
            Container(
              color: FieldColors.fieldbackground,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    team1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        color: tableColor.withAlpha(150),
                      ),
                    ),
                  ),
                  Text(
                    team2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
