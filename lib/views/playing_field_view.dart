import 'package:flutter/material.dart';
import 'package:pongstrong/models/match/match.dart';
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

  /// Resolves the display color for a match card.
  static Color _colorForMatch(Match match, bool showLeagueColors) {
    if (showLeagueColors) {
      return LeagueColors.forMatchId(match.id, match.tableNumber);
    }
    return TableColors.forIndex(match.tableNumber - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.sizeOf(context).width > 940;

    return Consumer<TournamentDataState>(
      builder: (context, data, child) {
        final showLeague = data.showLeagueColors;
        Color colorFor(Match m) => _colorForMatch(m, showLeague);

        if (isLargeScreen) {
          return _DesktopLayout(
            data: data,
            onToggleLeagueColors: data.toggleLeagueColors,
            colorForMatch: colorFor,
          );
        } else {
          return _MobileLayout(
            data: data,
            onToggleLeagueColors: data.toggleLeagueColors,
            colorForMatch: colorFor,
          );
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
  Color Function(Match) colorForMatch,
) {
  final team1 = data.getTeam(match.teamId1);
  final team2 = data.getTeam(match.teamId2);

  return Padding(
    padding: const EdgeInsets.all(4.0),
    child: MatchView(
      team1: team1?.name ?? 'Team 1',
      team2: team2?.name ?? 'Team 2',
      table: match.tableNumber.toString(),
      tableColor: colorForMatch(match),
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
  Match match,
  Color Function(Match) colorForMatch, {
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
      tableColor: colorForMatch(match),
      clickable: isReady,
      onTap: isReady
          ? () {
              startMatchDialog(
                context,
                team1: team1?.name ?? 'Team 1',
                team2: team2?.name ?? 'Team 2',
                members1: team1?.members ?? [],
                members2: team2?.members ?? [],
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
  final VoidCallback onToggleLeagueColors;
  final Color Function(Match) colorForMatch;
  const _DesktopLayout({
    required this.data,
    required this.onToggleLeagueColors,
    required this.colorForMatch,
  });

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
                      titleTrailing: _buildStealthyToggle(
                          FieldColors.tomato, onToggleLeagueColors),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: playing
                            .map((m) => _buildPlayingMatchCard(
                                context, data, m, colorForMatch))
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
                      titleTrailing: _buildStealthyToggle(
                          FieldColors.springgreen, onToggleLeagueColors),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        children: [
                          ...next.map((m) => _buildUpcomingMatchCard(
                              context, data, m, colorForMatch,
                              isReady: true)),
                          ...nextNext.map((m) => _buildUpcomingMatchCard(
                              context, data, m, colorForMatch,
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
  final VoidCallback onToggleLeagueColors;
  final Color Function(Match) colorForMatch;
  const _MobileLayout({
    required this.data,
    required this.onToggleLeagueColors,
    required this.colorForMatch,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _RunningMatchesSection(
            data: data,
            colorForMatch: colorForMatch,
            onToggleLeagueColors: onToggleLeagueColors,
          ),
          _UpcomingMatchesSection(
            data: data,
            colorForMatch: colorForMatch,
            onToggleLeagueColors: onToggleLeagueColors,
          ),
          _StandingsSection(data: data),
        ],
      ),
    );
  }
}

class _RunningMatchesSection extends StatelessWidget {
  final TournamentDataState data;
  final Color Function(Match) colorForMatch;
  final VoidCallback onToggleLeagueColors;
  const _RunningMatchesSection({
    required this.data,
    required this.colorForMatch,
    required this.onToggleLeagueColors,
  });

  @override
  Widget build(BuildContext context) {
    return FieldView(
      title: 'Laufende Spiele',
      primaryColor: FieldColors.tomato,
      secondaryColor: FieldColors.tomato.withAlpha(128),
      smallScreen: true,
      titleTrailing:
          _buildStealthyToggle(FieldColors.tomato, onToggleLeagueColors),
      child: Builder(
        builder: (context) {
          if (!data.hasData) {
            return const Center(child: Text('Keine Daten geladen'));
          }

          final playing = data.getPlayingMatches();
          if (playing.isEmpty) {
            return const Center(child: Text('Keine laufenden Spiele'));
          }

          return Wrap(
            alignment: WrapAlignment.center,
            children: playing
                .map((m) =>
                    _buildPlayingMatchCard(context, data, m, colorForMatch))
                .toList(),
          );
        },
      ),
    );
  }
}

class _UpcomingMatchesSection extends StatelessWidget {
  final TournamentDataState data;
  final Color Function(Match) colorForMatch;
  final VoidCallback onToggleLeagueColors;
  const _UpcomingMatchesSection({
    required this.data,
    required this.colorForMatch,
    required this.onToggleLeagueColors,
  });

  @override
  Widget build(BuildContext context) {
    return FieldView(
      title: 'Nächste Spiele',
      primaryColor: FieldColors.springgreen,
      secondaryColor: FieldColors.springgreen.withAlpha(128),
      smallScreen: true,
      titleTrailing:
          _buildStealthyToggle(FieldColors.springgreen, onToggleLeagueColors),
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

          return Wrap(
            alignment: WrapAlignment.center,
            children: allNextMatches.map((match) {
              final isReady = nextMatches.contains(match);
              return _buildUpcomingMatchCard(
                  context, data, match, colorForMatch,
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

// ---------------------------------------------------------------------------
// Stealthy color-mode toggle icon (blends with section background)
// ---------------------------------------------------------------------------

/// Builds a subtle palette icon that blends with the [backgroundColor].
/// Only shown in KO mode next to section headings.
Widget _buildStealthyToggle(Color backgroundColor, VoidCallback onToggle) {
  // Darken the background color slightly for a subtle but tappable icon
  final iconColor = Color.fromARGB(
    100,
    (backgroundColor.r * 255 * 0.6).round(),
    (backgroundColor.g * 255 * 0.6).round(),
    (backgroundColor.b * 255 * 0.6).round(),
  );

  return GestureDetector(
    onTap: onToggle,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        Icons.palette_outlined,
        size: 20,
        color: iconColor,
      ),
    ),
  );
}
