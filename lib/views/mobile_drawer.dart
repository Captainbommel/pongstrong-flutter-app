import 'package:flutter/material.dart';
import 'package:pongstrong/state/app_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/widgets/confirmation_dialog.dart';
import 'package:provider/provider.dart';

/// Mobile navigation drawer.
///
/// Provides drawer-based navigation on small screens.
class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

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
            title: const Text('Spielfeld'),
            onTap: () => Provider.of<AppState>(context, listen: false)
                .setViewAndCloseDrawer(AppView.playingField),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_handball_rounded),
                Icon(Icons.sports_bar_rounded),
              ],
            ),
          ),
          const Divider(
            height: 20,
            thickness: 5,
            indent: 0,
            color: FieldColors.springgreen,
          ),
          ListTile(
            title: const Text('Gruppenphase'),
            onTap: () => Provider.of<AppState>(context, listen: false)
                .setViewAndCloseDrawer(AppView.groupPhase),
            trailing: const Icon(Icons.group_rounded),
          ),
          ListTile(
            title: const Text('Turnierbaum'),
            onTap: () => Provider.of<AppState>(context, listen: false)
                .setViewAndCloseDrawer(AppView.tournamentTree),
            trailing: const Icon(Icons.account_tree_rounded),
          ),
          ListTile(
            title: const Text('Regelwerk'),
            onTap: () => Provider.of<AppState>(context, listen: false)
                .setViewAndCloseDrawer(AppView.rules),
            trailing: const Icon(Icons.gavel_rounded),
          ),
          const Divider(
            height: 20,
            thickness: 5,
            indent: 0,
            color: FieldColors.springgreen,
          ),
          // Admin - only for email users
          Consumer<AuthState>(
            builder: (context, authState, child) {
              if (!authState.isEmailUser) return const SizedBox.shrink();
              return ListTile(
                title: const Text(
                  'Turnierverwaltung',
                  style: TextStyle(
                    color: GroupPhaseColors.cupred,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => Provider.of<AppState>(context, listen: false)
                    .setViewAndCloseDrawer(AppView.adminPanel),
                trailing: const Icon(
                  Icons.settings,
                  color: GroupPhaseColors.cupred,
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Turnier wechseln'),
            onTap: () async {
              final confirmed = await showConfirmationDialog(
                context,
                title: 'Turnier verlassen?',
                content: const Text(
                    'Möchtest du wirklich zurück zur Turnierübersicht?'),
                confirmText: 'Zurück',
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
