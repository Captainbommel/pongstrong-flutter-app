import 'package:flutter/material.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/mobile_app/mobile_drawer.dart';
import 'package:pongstrong/shared/match_dialog.dart';
import 'package:pongstrong/shared/match_view.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:pongstrong/shared/test_objects.dart';
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

FieldView currentTable() {
  return FieldView(
    'Aktuelle Tabelle',
    FieldColors.skyblue,
    FieldColors.skyblue.withOpacity(0.6),
    true,
    Column(
      children: tables,
    ),
  );
}

FieldView nextGames(BuildContext context) {
  return FieldView(
    'Nächste Spiele',
    FieldColors.springgreen,
    FieldColors.springgreen.withOpacity(0.5),
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
                startMatchDialog(
                  context,
                  'Kotstulle',
                  'Testikuläre Torsion',
                  <String>['Hubert', 'Klaus'],
                  <String>['Giovanni', 'Karl'],
                );
                debugPrint('Match ${i + 1} pressed');
              },
              key: Key('cumatch_$i'), // is this needed?
            ),
          )
      ],
    ),
  );
}

FieldView runningGames(BuildContext context) {
  return FieldView(
    'Laufende Spiele',
    FieldColors.tomato,
    FieldColors.tomato.withOpacity(0.5),
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
