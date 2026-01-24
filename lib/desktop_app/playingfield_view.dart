import 'package:flutter/material.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/shared/match_view.dart';
import 'package:pongstrong/shared/match_dialog.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:provider/provider.dart';

class PlayingField extends StatelessWidget {
  const PlayingField({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TournamentDataState>(
      builder: (context, tournamentData, child) {
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
                            children:
                                _buildRunningMatches(context, tournamentData),
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
                            children:
                                _buildUpcomingMatches(context, tournamentData),
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
                    Wrap(
                      children: _buildTables(tournamentData),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

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

    return combined.asMap().entries.map((entry) {
      final match = entry.value;
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
                  );
                }
              : null,
          key: Key('upcoming_${match.id}'),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTables(TournamentDataState data) {
    if (!data.hasData || data.tabellen.tables.isEmpty) return [];

    return data.tabellen.tables.asMap().entries.map((entry) {
      final groupIndex = entry.key;
      final table = entry.value;

      return Padding(
        padding: const EdgeInsets.all(8.0),
        key: Key('table_$groupIndex'),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          border: const TableBorder(
            top: BorderSide(width: 2),
            bottom: BorderSide(width: 2),
            left: BorderSide(width: 2),
            right: BorderSide(width: 2),
            horizontalInside: BorderSide(width: 1.2),
            verticalInside: BorderSide(width: 1.2),
          ),
          children: [
            _pongTableRow(
              'Gruppe ${String.fromCharCode(65 + groupIndex)}',
              'Punkte',
              'Diff.',
              'Becher',
              isHeader: true,
            ),
            ...table.map((row) {
              final team = data.getTeam(row.teamId);
              return _pongTableRow(
                team?.name ?? 'Team',
                row.punkte.toString(),
                row.differenz.toString(),
                row.becher.toString(),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  TableRow _pongTableRow(String col1, String col2, String col3, String col4,
      {bool isHeader = false}) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              col1,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              col2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              col3,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              col4,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
