import 'package:flutter/material.dart';
import 'package:pongstrong/appstate.dart';
import 'package:pongstrong/colors.dart';
import 'package:provider/provider.dart';

class MobileDrawer extends StatelessWidget {
  const MobileDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
            onTap: Provider.of<AppState>(context).setRunningMatches,
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
            onTap: Provider.of<AppState>(context).setUpcomingMatches,
            trailing: const Icon(Icons.event_available_rounded),
          ),
          const Divider(
            height: 20,
            thickness: 5,
            indent: 0,
            color: FieldColors.springgreen,
          ),
          ExpansionTile(
            shape: const Border(),
            title: const Text('Übersicht'),
            children: [
              ListTile(
                title: const Text('Tabelle'),
                onTap: Provider.of<AppState>(context).setTables,
                trailing: const Icon(Icons.leaderboard_rounded),
              ),
              const ListTile(
                title: Text('Turnierbaum'),
                onTap: null,
                trailing: Icon(Icons.account_tree_rounded),
              ),
              const ListTile(
                title: Text('Regelwerk'),
                onTap: null,
                trailing: Icon(Icons.gavel_rounded),
              ),
              const ListTile(
                title: Text('Teams'),
                onTap: null,
                trailing: Icon(Icons.group_rounded),
              ),
            ],
          )
        ],
      ),
    );
  }
}
