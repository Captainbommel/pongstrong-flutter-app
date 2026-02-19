import 'package:flutter/material.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/widgets/field_view.dart';
import 'package:pongstrong/widgets/match_dialogs.dart';
import 'package:pongstrong/widgets/match_view.dart';
import 'package:pongstrong/widgets/standings_table.dart';
import 'package:provider/provider.dart';

/// Unified responsive playing field view.
///
/// On large screens (desktop): side-by-side layout with running matches,
/// upcoming matches, and standings tables.
/// On smaller screens (mobile): stacked scrollable layout.
class PlayingFieldView extends StatelessWidget {
  const PlayingFieldView({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.sizeOf(context).width > 940;

    return Consumer<TournamentDataState>(
      builder: (context, data, child) {
        if (isLargeScreen) {
          return _DesktopLayout(data: data);
        } else {
          return _MobileLayout(data: data);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared match-card builders (used by both desktop and mobile layouts)
// ---------------------------------------------------------------------------

/// Builds a single [MatchView] for a running (playing) match.
Widget _buildPlayingMatchCard(
  BuildContext context,
  TournamentDataState data,
  Match match,
) {
  final team1 = data.getTeam(match.teamId1);
  final team2 = data.getTeam(match.teamId2);

  return Padding(
    padding: const EdgeInsets.all(4.0),
    child: MatchView(
      team1: team1?.name ?? 'Team 1',
      team2: team2?.name ?? 'Team 2',
      table: match.tableNumber.toString(),
      tableColor: TableColors.forIndex(match.tableNumber - 1),
      clickable: true,
      onTap: () {
        finishMatchDialog(
          context,
          team1: team1?.name ?? 'Team 1',
          team2: team2?.name ?? 'Team 2',
          match: match,
        );
      },
      key: Key('playing_${match.id}'),
    ),
  );
}

/// Builds a single [MatchView] for an upcoming (queued) match.
Widget _buildUpcomingMatchCard(
  BuildContext context,
  TournamentDataState data,
  Match match, {
  required bool isReady,
}) {
  final team1 = data.getTeam(match.teamId1);
  final team2 = data.getTeam(match.teamId2);

  return Padding(
    padding: const EdgeInsets.all(4.0),
    child: MatchView(
      team1: team1?.name ?? 'Team 1',
      team2: team2?.name ?? 'Team 2',
      table: match.tableNumber.toString(),
      tableColor: TableColors.forIndex(match.tableNumber - 1),
      clickable: isReady,
      onTap: isReady
          ? () {
              startMatchDialog(
                context,
                team1: team1?.name ?? 'Team 1',
                team2: team2?.name ?? 'Team 2',
                members1: [team1?.member1 ?? '', team1?.member2 ?? ''],
                members2: [team2?.member1 ?? '', team2?.member2 ?? ''],
                match: match,
              );
            }
          : null,
      key: Key('next_${match.id}'),
    ),
  );
}

/// Builds the list of [StandingsTable] widgets from current standings data.
List<Widget> _buildStandingsTables(TournamentDataState data) {
  if (!data.hasData || data.tabellen.tables.isEmpty) return [];

  return data.tabellen.tables.asMap().entries.map((entry) {
    final groupIndex = entry.key;
    final table = entry.value;

    return StandingsTable(
      key: Key('table_$groupIndex'),
      groupIndex: groupIndex,
      rows: table.map((row) {
        final team = data.getTeam(row.teamId);
        return StandingsRow(
          teamName: team?.name ?? 'Team',
          points: row.points,
          difference: row.difference,
          cups: row.cups,
        );
      }).toList(),
    );
  }).toList();
}

// ---------------------------------------------------------------------------
// Desktop layout
// ---------------------------------------------------------------------------

/// Desktop: side-by-side layout with running, upcoming, and tables.
class _DesktopLayout extends StatelessWidget {
  final TournamentDataState data;
  const _DesktopLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    final playing = data.hasData ? data.getPlayingMatches() : <Match>[];
    final next = data.hasData ? data.getNextMatches() : <Match>[];
    final nextNext = data.hasData ? data.getNextNextMatches() : <Match>[];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: FieldView(
                      title: 'Laufende Spiele',
                      primaryColor: FieldColors.tomato,
                      secondaryColor: FieldColors.tomato.withAlpha(128),
                      smallScreen: false,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: playing
                            .map(
                                (m) => _buildPlayingMatchCard(context, data, m))
                            .toList(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FieldView(
                      title: 'Nächste Spiele',
                      primaryColor: FieldColors.springgreen,
                      secondaryColor: FieldColors.springgreen.withAlpha(128),
                      smallScreen: false,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: [
                          ...next.map((m) => _buildUpcomingMatchCard(
                              context, data, m,
                              isReady: true)),
                          ...nextNext.map((m) => _buildUpcomingMatchCard(
                              context, data, m,
                              isReady: false)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FieldView(
                title: 'Aktuelle Tabelle',
                primaryColor: FieldColors.skyblue,
                secondaryColor: FieldColors.skyblue.withAlpha(128),
                smallScreen: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: Wrap(
                    children: _buildStandingsTables(data),
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

// ---------------------------------------------------------------------------
// Mobile layout
// ---------------------------------------------------------------------------

/// Mobile: scrollable stacked layout.
class _MobileLayout extends StatelessWidget {
  final TournamentDataState data;
  const _MobileLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _RunningMatchesSection(data: data),
          _UpcomingMatchesSection(data: data),
          _StandingsSection(data: data),
        ],
      ),
    );
  }
}

class _RunningMatchesSection extends StatelessWidget {
  final TournamentDataState data;
  const _RunningMatchesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return FieldView(
      title: 'Laufende Spiele',
      primaryColor: FieldColors.tomato,
      secondaryColor: FieldColors.tomato.withAlpha(128),
      smallScreen: true,
      child: Builder(
        builder: (context) {
          if (!data.hasData) {
            return const Center(child: Text('Keine Daten geladen'));
          }

          final playing = data.getPlayingMatches();
          if (playing.isEmpty) {
            return const Center(child: Text('Keine laufenden Spiele'));
          }

          return Column(
            children: playing
                .map((m) => _buildPlayingMatchCard(context, data, m))
                .toList(),
          );
        },
      ),
    );
  }
}

class _UpcomingMatchesSection extends StatelessWidget {
  final TournamentDataState data;
  const _UpcomingMatchesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return FieldView(
      title: 'Nächste Spiele',
      primaryColor: FieldColors.springgreen,
      secondaryColor: FieldColors.springgreen.withAlpha(128),
      smallScreen: true,
      child: Builder(
        builder: (context) {
          if (!data.hasData) {
            return const Center(child: Text('Keine Daten geladen'));
          }

          final nextMatches = data.getNextMatches();
          final nextNextMatches = data.getNextNextMatches();
          final allNextMatches = [...nextMatches, ...nextNextMatches];

          if (allNextMatches.isEmpty) {
            return const Center(child: Text('Keine nächsten Spiele'));
          }

          return Column(
            children: allNextMatches.map((match) {
              final isReady = nextMatches.contains(match);
              return _buildUpcomingMatchCard(context, data, match,
                  isReady: isReady);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StandingsSection extends StatelessWidget {
  final TournamentDataState data;
  const _StandingsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.hasData || data.tabellen.tables.isEmpty) {
      return FieldView(
        title: 'Aktuelle Tabelle',
        primaryColor: FieldColors.skyblue,
        secondaryColor: FieldColors.skyblue.withAlpha(153),
        smallScreen: true,
        child: const Center(child: Text('Keine Daten geladen')),
      );
    }

    return FieldView(
      title: 'Aktuelle Tabelle',
      primaryColor: FieldColors.skyblue,
      secondaryColor: FieldColors.skyblue.withAlpha(153),
      smallScreen: true,
      child: Column(
        children: _buildStandingsTables(data),
      ),
    );
  }
}
