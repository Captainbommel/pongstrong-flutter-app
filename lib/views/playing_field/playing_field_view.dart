import 'package:flutter/material.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/playing_field/field_view.dart';
import 'package:pongstrong/views/playing_field/match_dialogs.dart';
import 'package:pongstrong/views/playing_field/match_view.dart';
import 'package:pongstrong/views/playing_field/standings_table.dart';
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

/// Builds a single [MatchView] for a match card.
///
/// When [isPlaying] is true, tapping opens [finishMatchDialog].
/// Otherwise, tapping opens [startMatchDialog] (only when [isReady]).
Widget _buildMatchCard(
  BuildContext context,
  TournamentDataState data,
  Match match,
  Color Function(Match) colorForMatch, {
  required bool isPlaying,
  bool isReady = true,
}) {
  final team1 = data.getTeam(match.teamId1);
  final team2 = data.getTeam(match.teamId2);
  final team1Name = team1?.name ?? 'Team 1';
  final team2Name = team2?.name ?? 'Team 2';
  final clickable = isPlaying || isReady;

  return Padding(
    padding: const EdgeInsets.all(4.0),
    child: MatchView(
      team1: team1Name,
      team2: team2Name,
      table: match.tableNumber.toString(),
      tableColor: colorForMatch(match),
      clickable: clickable,
      onTap: clickable
          ? () {
              if (isPlaying) {
                finishMatchDialog(
                  context,
                  team1: team1Name,
                  team2: team2Name,
                  match: match,
                );
              } else {
                startMatchDialog(
                  context,
                  team1: team1Name,
                  team2: team2Name,
                  members1: team1?.members ?? [],
                  members2: team2?.members ?? [],
                  match: match,
                );
              }
            }
          : null,
      key: Key('${isPlaying ? 'playing' : 'next'}_${match.id}'),
    ),
  );
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
                    child: _MatchesSection(
                      turnamentData: data,
                      colorForMatch: colorForMatch,
                      onToggleLeagueColors: onToggleLeagueColors,
                      isPlaying: true,
                      smallScreen: false,
                    ),
                  ),
                  Expanded(
                    child: _MatchesSection(
                      turnamentData: data,
                      colorForMatch: colorForMatch,
                      onToggleLeagueColors: onToggleLeagueColors,
                      isPlaying: false,
                      smallScreen: false,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _StandingsSection(
                turnamentData: data,
                smallScreen: false,
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
          _MatchesSection(
            turnamentData: data,
            colorForMatch: colorForMatch,
            onToggleLeagueColors: onToggleLeagueColors,
            isPlaying: true,
          ),
          _MatchesSection(
            turnamentData: data,
            colorForMatch: colorForMatch,
            onToggleLeagueColors: onToggleLeagueColors,
            isPlaying: false,
          ),
          _StandingsSection(turnamentData: data),
        ],
      ),
    );
  }
}

/// Mobile section for either running or upcoming matches, driven by [isPlaying].
class _MatchesSection extends StatelessWidget {
  final TournamentDataState turnamentData;
  final Color Function(Match) colorForMatch;
  final VoidCallback onToggleLeagueColors;
  final bool isPlaying;
  final bool smallScreen;
  const _MatchesSection({
    required this.turnamentData,
    required this.colorForMatch,
    required this.onToggleLeagueColors,
    required this.isPlaying,
    this.smallScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPlaying ? FieldColors.tomato : FieldColors.springgreen;
    final title = isPlaying ? 'Laufende Spiele' : 'Nächste Spiele';

    return FieldView(
      title: title,
      primaryColor: color,
      secondaryColor: color.withAlpha(128),
      smallScreen: smallScreen,
      titleTrailing: _buildStealthyToggle(color, onToggleLeagueColors),
      child: Builder(
        builder: (context) {
          if (!turnamentData.hasData) {
            return const SizedBox.shrink();
          }

          if (isPlaying) {
            final playing = turnamentData.getPlayingMatches();
            if (playing.isEmpty) {
              return const SizedBox.shrink();
            }
            return Wrap(
              alignment: WrapAlignment.center,
              children: playing
                  .map((m) => _buildMatchCard(
                      context, turnamentData, m, colorForMatch,
                      isPlaying: true))
                  .toList(),
            );
          } else {
            final nextMatches = turnamentData.getNextMatches();
            final nextNextMatches = turnamentData.getNextNextMatches();
            final allNextMatches = [...nextMatches, ...nextNextMatches];
            if (allNextMatches.isEmpty) {
              return const SizedBox.shrink();
            }
            return Wrap(
              alignment: WrapAlignment.center,
              children: allNextMatches.map((match) {
                final isReady = nextMatches.contains(match);
                return _buildMatchCard(
                    context, turnamentData, match, colorForMatch,
                    isPlaying: false, isReady: isReady);
              }).toList(),
            );
          }
        },
      ),
    );
  }
}

class _StandingsSection extends StatelessWidget {
  final TournamentDataState turnamentData;
  final bool smallScreen;
  const _StandingsSection(
      {required this.turnamentData, this.smallScreen = true});

  @override
  Widget build(BuildContext context) {
    if (!turnamentData.hasData || turnamentData.tabellen.tables.isEmpty) {
      return FieldView(
        title: 'Aktuelle Tabelle',
        primaryColor: FieldColors.skyblue,
        secondaryColor: FieldColors.skyblue.withAlpha(153),
        smallScreen: smallScreen,
        child: const Center(child: Text('Keine Daten geladen')),
      );
    }

    return FieldView(
      title: 'Aktuelle Tabelle',
      primaryColor: FieldColors.skyblue,
      secondaryColor: FieldColors.skyblue.withAlpha(153),
      smallScreen: smallScreen,
      child: Column(
        children: _buildStandingsTables(turnamentData),
      ),
    );
  }
}

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
