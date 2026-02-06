import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/widgets/field_view.dart';
import 'package:pongstrong/widgets/match_view.dart';
import 'package:pongstrong/widgets/match_dialogs.dart';
import 'package:pongstrong/widgets/standings_table.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
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
    final isLargeScreen = MediaQuery.of(context).size.width > 940;

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

/// Desktop: side-by-side layout with running, upcoming, and tables
class _DesktopLayout extends StatelessWidget {
  final TournamentDataState data;
  const _DesktopLayout({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
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
                      'Laufende Spiele',
                      FieldColors.tomato,
                      FieldColors.tomato.withAlpha(128),
                      false,
                      Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: _buildRunningMatches(context, data),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FieldView(
                      'Nächste Spiele',
                      FieldColors.springgreen,
                      FieldColors.springgreen.withAlpha(128),
                      false,
                      Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: _buildUpcomingMatches(context, data),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FieldView(
                'Aktuelle Tabelle',
                FieldColors.skyblue,
                FieldColors.skyblue.withAlpha(128),
                false,
                Padding(
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

/// Mobile: scrollable stacked layout
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
      'Laufende Spiele',
      FieldColors.tomato,
      FieldColors.tomato.withAlpha(128),
      true,
      Consumer<TournamentDataState>(
        builder: (context, data, child) {
          if (!data.hasData) {
            return const Center(child: Text('Keine Daten geladen'));
          }

          final playing = data.getPlayingMatches();
          if (playing.isEmpty) {
            return const Center(child: Text('Keine laufenden Spiele'));
          }

          return Column(
            children: playing.map((match) {
              final team1 = data.getTeam(match.teamId1);
              final team2 = data.getTeam(match.teamId2);

              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: MatchView(
                  team1?.name ?? 'Team 1',
                  team2?.name ?? 'Team 2',
                  match.tischNr.toString(),
                  TableColors.get(match.tischNr - 1),
                  true,
                  onTap: () {
                    finnishMatchDialog(
                      context,
                      team1?.name ?? 'Team 1',
                      team2?.name ?? 'Team 2',
                      TextEditingController(),
                      TextEditingController(),
                      match,
                    );
                  },
                  key: Key('playing_${match.id}'),
                ),
              );
            }).toList(),
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
      'Nächste Spiele',
      FieldColors.springgreen,
      FieldColors.springgreen.withAlpha(128),
      true,
      Consumer<TournamentDataState>(
        builder: (context, data, child) {
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
              final team1 = data.getTeam(match.teamId1);
              final team2 = data.getTeam(match.teamId2);
              final isReady = nextMatches.contains(match);

              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: MatchView(
                  team1?.name ?? 'Team 1',
                  team2?.name ?? 'Team 2',
                  match.tischNr.toString(),
                  TableColors.get(match.tischNr - 1),
                  isReady,
                  onTap: isReady
                      ? () {
                          startMatchDialog(
                            context,
                            team1?.name ?? 'Team 1',
                            team2?.name ?? 'Team 2',
                            [team1?.mem1 ?? '', team1?.mem2 ?? ''],
                            [team2?.mem1 ?? '', team2?.mem2 ?? ''],
                            match,
                          );
                        }
                      : null,
                  key: Key('next_${match.id}'),
                ),
              );
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
        'Aktuelle Tabelle',
        FieldColors.skyblue,
        FieldColors.skyblue.withAlpha(153),
        true,
        const Center(child: Text('Keine Daten geladen')),
      );
    }

    return FieldView(
      'Aktuelle Tabelle',
      FieldColors.skyblue,
      FieldColors.skyblue.withAlpha(153),
      true,
      Column(
        children: data.tabellen.tables.asMap().entries.map((entry) {
          final groupIndex = entry.key;
          final table = entry.value;
          return StandingsTable(
            groupIndex: groupIndex,
            rows: table.map((row) {
              final team = data.getTeam(row.teamId);
              return StandingsRow(
                teamName: team?.name ?? 'Team',
                points: row.punkte,
                difference: row.differenz,
                cups: row.becher,
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// --- Helper methods used by desktop layout ---

List<Widget> _buildRunningMatches(
    BuildContext context, TournamentDataState data) {
  if (!data.hasData) return [];

  final playing = data.getPlayingMatches();
  if (playing.isEmpty) return [];

  return playing.map((match) {
    final team1 = data.getTeam(match.teamId1);
    final team2 = data.getTeam(match.teamId2);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView(
        team1?.name ?? 'Team 1',
        team2?.name ?? 'Team 2',
        match.tischNr.toString(),
        TableColors.get(match.tischNr - 1),
        true,
        onTap: () {
          finnishMatchDialog(
            context,
            team1?.name ?? 'Team 1',
            team2?.name ?? 'Team 2',
            TextEditingController(),
            TextEditingController(),
            match,
          );
        },
        key: Key('playing_${match.id}'),
      ),
    );
  }).toList();
}

List<Widget> _buildUpcomingMatches(
    BuildContext context, TournamentDataState data) {
  if (!data.hasData) return [];

  final next = data.getNextMatches();
  final nextNext = data.getNextNextMatches();
  final combined = [...next, ...nextNext];

  if (combined.isEmpty) return [];

  return combined.map((match) {
    final isReady = next.contains(match);
    final team1 = data.getTeam(match.teamId1);
    final team2 = data.getTeam(match.teamId2);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView(
        team1?.name ?? 'Team 1',
        team2?.name ?? 'Team 2',
        match.tischNr.toString(),
        TableColors.get(match.tischNr - 1),
        isReady,
        onTap: isReady
            ? () {
                startMatchDialog(
                  context,
                  team1?.name ?? 'Team 1',
                  team2?.name ?? 'Team 2',
                  [team1?.mem1 ?? '', team1?.mem2 ?? ''],
                  [team2?.mem1 ?? '', team2?.mem2 ?? ''],
                  match,
                );
              }
            : null,
        key: Key('upcoming_${match.id}'),
      ),
    );
  }).toList();
}

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
          points: row.punkte,
          difference: row.differenz,
          cups: row.becher,
        );
      }).toList(),
    );
  }).toList();
}
