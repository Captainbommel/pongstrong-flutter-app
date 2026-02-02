import 'package:flutter/material.dart';
import 'package:pongstrong/mobile_app/mobile_app_state.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

//? rename HomeDrawer
//? remember if übersicht was extendet
class MobileDrawer extends StatelessWidget {
  const MobileDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('MobileDrawer'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  FieldColors.tomato,
                  FieldColors.springgreen,
                ],
              ),
            ),
            child: Text(
              'Spielfeld',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Laufende Spiele'),
            onTap: Provider.of<MobileAppState>(context, listen: false)
                .setAppState(MobileAppView.runningMatches),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_handball_rounded),
                Icon(Icons.sports_bar_rounded),
              ],
            ),
          ),
          ListTile(
            title: const Text('Nächste Spiele'),
            onTap: Provider.of<MobileAppState>(context, listen: false)
                .setAppState(MobileAppView.upcomingMatches),
            trailing: const Icon(Icons.event_available_rounded),
          ),
          const Divider(
            height: 20,
            thickness: 5,
            indent: 0,
            color: FieldColors.springgreen,
          ),
          ListTile(
            title: const Text('Gruppenphase'),
            onTap: Provider.of<MobileAppState>(context, listen: false)
                .setAppState(MobileAppView.teams),
            trailing: const Icon(Icons.group_rounded),
          ),
          ListTile(
            title: const Text('Turnierbaum'),
            onTap: Provider.of<MobileAppState>(context, listen: false)
                .setAppState(MobileAppView.tournamentTree),
            trailing: const Icon(Icons.account_tree_rounded),
          ),
          ListTile(
            title: const Text('Regelwerk'),
            onTap: Provider.of<MobileAppState>(context, listen: false)
                .setAppState(MobileAppView.rules),
            trailing: const Icon(Icons.gavel_rounded),
          ),
          const Divider(
            height: 20,
            thickness: 5,
            indent: 0,
            color: FieldColors.springgreen,
          ),
          ListTile(
            title: const Text('Turnier wechseln'),
            onTap: () async {
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
            },
            trailing: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
    );
  }
}
