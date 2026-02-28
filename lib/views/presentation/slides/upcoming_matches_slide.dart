import 'package:flutter/material.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';

/// Slide showing the next upcoming matches (those waiting to be assigned to a
/// table).
///
/// Only shows [MatchQueue.nextMatches] – the immediate next batch – so players
/// know to get ready.
class UpcomingMatchesSlide extends StatelessWidget {
  final TournamentDataState data;

  const UpcomingMatchesSlide({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final upcoming = data.matchQueue.nextMatches();

    return Column(
      children: [
        const SizedBox(height: 24),
        const Text(
          'Nächste Spiele',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: GroupPhaseColors.steelblue,
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
            color: GroupPhaseColors.steelblue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: upcoming.isEmpty
              ? _emptyState('Keine weiteren Spiele')
              : Center(
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: upcoming.map((match) {
                      final team1 =
                          data.getTeam(match.teamId1)?.name ?? match.teamId1;
                      final team2 =
                          data.getTeam(match.teamId2)?.name ?? match.teamId2;

                      return _UpcomingCard(
                        team1: team1,
                        team2: team2,
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
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

class _UpcomingCard extends StatelessWidget {
  final String team1;
  final String team2;

  const _UpcomingCard({
    required this.team1,
    required this.team2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: const BorderSide(width: 3, color: GroupPhaseColors.steelblue),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: GroupPhaseColors.steelblue,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Center(
                child: Text(
                  'Vorbereiten!',
                  style: TextStyle(
                    fontSize: 18,
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
                        color: GroupPhaseColors.steelblue.withAlpha(150),
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
