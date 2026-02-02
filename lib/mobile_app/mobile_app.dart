import 'package:flutter/material.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/mobile_app/mobile_drawer.dart';
import 'package:pongstrong/shared/match_dialog.dart';
import 'package:pongstrong/shared/match_view.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:pongstrong/shared/teams_view.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

const String turnamentName = 'BMT-Cup';

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  late PageController _pageController;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Hide hint after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getPageIndex(MobileAppView view) {
    switch (view) {
      case MobileAppView.runningMatches:
        return 0;
      case MobileAppView.upcomingMatches:
        return 1;
      case MobileAppView.teams:
        return 2;
      case MobileAppView.tournamentTree:
        return 3;
      case MobileAppView.rules:
        return 4;
      default:
        return 0;
    }
  }

  MobileAppView _getViewFromIndex(int index) {
    switch (index) {
      case 0:
        return MobileAppView.runningMatches;
      case 1:
        return MobileAppView.upcomingMatches;
      case 2:
        return MobileAppView.teams;
      case 3:
        return MobileAppView.tournamentTree;
      case 4:
        return MobileAppView.rules;
      default:
        return MobileAppView.runningMatches;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTournament =
        Provider.of<TournamentSelectionState>(context).selectedTournamentId;
    final mobileAppState = Provider.of<MobileAppState>(context);

    // Sync PageView with state changes from drawer
    final currentPage = _getPageIndex(mobileAppState.state);
    if (_pageController.hasClients &&
        _pageController.page?.round() != currentPage) {
      _pageController.jumpToPage(currentPage);
    }

    return Scaffold(
      key: mobileAppState.scaffoldKey,
      drawer: const MobileDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        title: Text(selectedTournament ?? turnamentName),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          mobileAppState.setAppStateDirectly(_getViewFromIndex(index));
        },
        children: [
          _buildPageWithHint(runningGames(context), showHint: true),
          _buildPageWithHint(nextGames(context), showHint: false),
          const SingleChildScrollView(child: TeamsView()),
          const SingleChildScrollView(
              child: Placeholder()), // Tournament Tree placeholder
          const SingleChildScrollView(child: RulesView()),
        ],
      ),
    );
  }

  Widget _buildPageWithHint(Widget content, {bool showHint = false}) {
    if (!showHint || !_showHint) {
      return SingleChildScrollView(child: content);
    }

    return Stack(
      children: [
        SingleChildScrollView(child: content),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _showHint ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(153),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Wischen zum Navigieren',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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

FieldView runningGames(BuildContext context) {
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
