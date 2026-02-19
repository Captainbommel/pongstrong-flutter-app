import 'package:flutter/material.dart';
import 'package:pongstrong/state/app_state.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/widgets/confirmation_dialog.dart';
import 'package:provider/provider.dart';

/// Mobile navigation drawer.
///
/// Provides drawer-based navigation on small screens.
class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TournamentDataState>(
      builder: (context, tournamentData, child) {
        // Determine which navigation items to show
        final isKnockoutsOnly =
            tournamentData.tournamentStyle == 'knockoutsOnly';
        final isEveryoneVsEveryone =
            tournamentData.tournamentStyle == 'everyoneVsEveryone';
        final isKnockoutPhase = tournamentData.isKnockoutMode;
        final rulesEnabled = tournamentData.rulesEnabled;
        final hasStarted = tournamentData.hasData;

        final showGroupPhase = hasStarted && !isKnockoutsOnly;
        final showTournamentTree = hasStarted &&
            !isEveryoneVsEveryone &&
            (isKnockoutsOnly || isKnockoutPhase);

        return _buildDrawerContent(
            context, showGroupPhase, showTournamentTree, rulesEnabled);
      },
    );
  }

  Widget _buildDrawerContent(BuildContext context, bool showGroupPhase,
      bool showTournamentTree, bool rulesEnabled) {
    return Drawer(
      key: const Key('MobileDrawer'),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
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
          if (showGroupPhase)
            ListTile(
              title: const Text('Gruppenphase'),
              onTap: () => Provider.of<AppState>(context, listen: false)
                  .setViewAndCloseDrawer(AppView.groupPhase),
              trailing: const Icon(Icons.group_rounded),
            ),
          if (showTournamentTree)
            ListTile(
              title: const Text('Turnierbaum'),
              onTap: () => Provider.of<AppState>(context, listen: false)
                  .setViewAndCloseDrawer(AppView.tournamentTree),
              trailing: const Icon(Icons.account_tree_rounded),
            ),
          if (rulesEnabled)
            ListTile(
              title: const Text('Regeln'),
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
                Provider.of<AuthState>(context, listen: false)
                    .clearTournamentRole();
                Provider.of<TournamentSelectionState>(context, listen: false)
                    .clearSelectedTournament();
              }
            },
            trailing: const Icon(Icons.swap_horiz_rounded),
          ),
          const Spacer(),
          // Admin - only for tournament creator, pinned to bottom of screen
          Consumer<AuthState>(
            builder: (context, authState, child) {
              if (!authState.isAdmin) return const SizedBox.shrink();
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
        ],
      ),
    );
  }
}
