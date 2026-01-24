import 'package:flutter/material.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/mobile_app/mobile_drawer.dart';
import 'package:pongstrong/shared/match_dialog.dart';
import 'package:pongstrong/shared/match_view.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:provider/provider.dart';

const String turnamentName = 'BMT-Cup';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Provider.of<MobileAppState>(context).scaffoldKey,
      drawer: const MobileDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        title: const Text(turnamentName),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: () {
          switch (Provider.of<MobileAppState>(context).state) {
            case MobileAppView.runningMatches:
              return runningGames(context);
            case MobileAppView.upcomingMatches:
              return nextGames(context);
            case MobileAppView.tables:
              return currentTable();
            case MobileAppView.rules:
              return const RulesView();
            default:
              return const Placeholder();
          }
        }(),
      ),
    );
  }
}

Widget currentTable() {
  return Consumer<TournamentDataState>(
    builder: (context, data, child) {
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
          children: data.tabellen.tables.map((table) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Table(
                border: TableBorder.all(),
                children: [
                  _pongTableRow(
                    'Team',
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
          }).toList(),
        ),
      );
    },
  );
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

FieldView nextGames(BuildContext context) {
  return FieldView(
    'Nächste Spiele',
    FieldColors.springgreen,
    FieldColors.springgreen.withAlpha(128),
    true,
    Consumer<TournamentDataState>(
      builder: (context, data, child) {
        if (!data.hasData) {
          return FieldView(
            'Laufende Spiele',
            FieldColors.tomato,
            FieldColors.tomato.withAlpha(128),
            true,
            const Center(child: Text('Keine Daten geladen')),
          );
        }

        final playing = data.getPlayingMatches();

        if (playing.isEmpty) {
          return FieldView(
            'Laufende Spiele',
            FieldColors.tomato,
            FieldColors.tomato.withAlpha(128),
            true,
            const Center(child: Text('Keine laufenden Spiele')),
          );
        }

        return FieldView(
          'Laufende Spiele',
          FieldColors.tomato,
          FieldColors.tomato.withAlpha(128),
          true,
          Column(
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
                    );
                  },
                  key: Key('playing_${match.id}'),
                ),
              );
            }).toList(),
          ),
        );
      },
    ),
  );
}

FieldView runningGames(BuildContext context) {
  return FieldView(
    'Laufende Spiele',
    FieldColors.tomato,
    FieldColors.tomato.withAlpha(128),
    true,
    Column(
      //alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: MatchView(
              'Kotstulle',
              'Testikuläre Torsion',
              (i + 1).toString(),
              TableColors.get(i),
              true,
              onTap: () {
                finnishMatchDialog(context, 'Kotstulle', 'Testikuläre Torsion',
                    TextEditingController(), TextEditingController());
                debugPrint('Match ${i + 1} pressed');
              },
              key: Key('cumatch_$i'), // is this needed?
            ),
          )
      ],
    ),
  );
}
