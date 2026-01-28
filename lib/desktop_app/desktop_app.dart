import 'package:flutter/material.dart';
import 'package:pongstrong/desktop_app/desktop_app_state.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:pongstrong/shared/tree_view.dart';
import 'package:pongstrong/desktop_app/playingfield_view.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:pongstrong/shared/teams_view.dart';
import 'package:provider/provider.dart';

const String turnamentName = 'BMT-Cup';

const navbarStyle = TextStyle(
  color: Colors.black,
  fontSize: 16,
  decoration: TextDecoration.underline,
);

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  Future<void> _showBackConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turnier verlassen?'),
        content: const Text(
          'Möchtest du wirklich zurück zur Turnierübersicht?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Abbrechen',
              style: TextStyle(
                color: GroupPhaseColors.cupred,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.cupred,
              foregroundColor: Colors.white,
            ),
            child: const Text('Zurück'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Provider.of<TournamentSelectionState>(context, listen: false)
          .clearSelectedTournament();
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Display tournament name somewhere in the UI (perhaps in body or a side panel)
    // final selectedTournament =
    //     Provider.of<TournamentSelectionState>(context).selectedTournamentId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück zur Übersicht',
          onPressed: () => _showBackConfirmationDialog(context),
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  Provider.of<DesktopAppState>(context, listen: false)
                      .setAppState(DesktopAppView.playingfield)!();
                },
                child: const Text('Spielfeld', style: navbarStyle),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Provider.of<DesktopAppState>(context, listen: false)
                      .setAppState(DesktopAppView.teams)!();
                },
                child: const Text('Gruppenphase', style: navbarStyle),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Provider.of<DesktopAppState>(context, listen: false)
                      .setAppState(DesktopAppView.tournamentTree)!();
                },
                child: const Text('Turnierbaum', style: navbarStyle),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Provider.of<DesktopAppState>(context, listen: false)
                      .setAppState(DesktopAppView.rules)!();
                },
                child: const Text('Regeln', style: navbarStyle),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => TestDataHelpers.uploadTeamsFromJson(context),
                child: const Text('Load Teams', style: navbarStyle),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: () {
        switch (Provider.of<DesktopAppState>(context).state) {
          case DesktopAppView.playingfield:
            return const PlayingField();
          case DesktopAppView.rules:
            return const RulesView();
          case DesktopAppView.teams:
            return const TeamsView();
          case DesktopAppView.tournamentTree:
            return const TreeViewPage();
          default:
            return const Placeholder();
        }
      }(),
    );
  }
}
