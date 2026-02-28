import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          const DrawerHeader(
            decoration: BoxDecoration(
              color: GroupPhaseColors.cupred,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Pongstrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Spielfeld'),
            onTap: () => Provider.of<AppState>(context, listen: false)
                .setViewAndCloseDrawer(AppView.playingField),
            trailing: const Icon(Icons.sports_handball_rounded),
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
            color: GroupPhaseColors.cupred,
          ),
          ListTile(
            title: const Text('Verlassen'),
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
            trailing: const Icon(Icons.exit_to_app_rounded),
          ),
          const Spacer(),
          // Join code + Admin, pinned to bottom
          Consumer2<AuthState, TournamentDataState>(
            builder: (context, authState, tournamentData, child) {
              final code = tournamentData.joinCode;
              final isAdmin = authState.isAdmin;
              return Column(
                children: [
                  if (code != null) _buildJoinCodeTile(context, code),
                  if (isAdmin) _buildAdminTile(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context) {
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
  }

  Widget _buildJoinCodeTile(BuildContext context, String code) {
    return ListTile(
      title: Text(
        code,
        style: const TextStyle(
          color: GroupPhaseColors.cupred,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
        ),
      ),
      onTap: () => Clipboard.setData(ClipboardData(text: code)),
      trailing: const Icon(
        Icons.copy,
        color: GroupPhaseColors.cupred,
      ),
    );
  }
}
