import 'package:flutter/material.dart';
import 'package:pongstrong/models/groups/tabellen.dart' as tabellen;
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/views/standings/match_card.dart';
import 'package:pongstrong/views/standings/standings_table.dart';
import 'package:pongstrong/widgets/match_edit_dialog.dart';
import 'package:provider/provider.dart';

class StandingsView extends StatelessWidget {
  const StandingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final tournamentData = Provider.of<TournamentDataState>(context);

    if (!tournamentData.hasData) {
      return const Center(
        child: Text(
          'Keine Daten verfügbar',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final gruppenphase = tournamentData.gruppenphase;
    if (gruppenphase.groups.isEmpty) {
      return const Center(
        child: Text(
          'Keine Gruppendaten verfügbar',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLargeScreen = screenWidth > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: List.generate(
          gruppenphase.groups.length,
          (groupIndex) => Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: _GroupOverview(
              key: ValueKey('group_$groupIndex'),
              groupIndex: groupIndex,
              matches: gruppenphase.groups[groupIndex],
              table: groupIndex < tournamentData.tabellen.tables.length
                  ? tournamentData.tabellen.tables[groupIndex]
                  : [],
              isLargeScreen: isLargeScreen,
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupOverview extends StatelessWidget {
  final int groupIndex;
  final List<Match> matches;
  final List<tabellen.TableRow> table;
  final bool isLargeScreen;

  const _GroupOverview({
    super.key,
    required this.groupIndex,
    required this.matches,
    required this.table,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    final groupName = 'Gruppe ${String.fromCharCode(65 + groupIndex)}';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: GroupPhaseColors.steelblue,
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGroupHeader(groupName),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isLargeScreen
                ? _buildLargeScreenLayout(context)
                : _buildSmallScreenLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String groupName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: GroupPhaseColors.steelblue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(9),
          topRight: Radius.circular(9),
        ),
      ),
      child: Text(
        groupName,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnColored,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLargeScreenLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildMatchList(context),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: StandingsTable(groupIndex: groupIndex),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context) {
    return Column(
      children: [
        _buildMatchList(context),
        const SizedBox(height: 16),
        StandingsTable(groupIndex: groupIndex),
      ],
    );
  }

  Widget _buildMatchList(BuildContext context) {
    return Selector<TournamentDataState, List<Match>>(
      selector: (_, state) => matches,
      builder: (context, currentMatches, child) {
        return Container(
          decoration: BoxDecoration(
            color: GroupPhaseColors.steelblue.withAlpha(50),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: GroupPhaseColors.steelblue.withAlpha(100),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.grouppurple.withAlpha(150),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
                child: const Text(
                  'Spiele',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnColored,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Builder(
                builder: (context) {
                  final data =
                      Provider.of<TournamentDataState>(context, listen: false);
                  final isAdmin =
                      Provider.of<AuthState>(context, listen: false).isAdmin;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: currentMatches.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final match = currentMatches[index];
                      final team1 = data.getTeam(match.teamId1);
                      final team2 = data.getTeam(match.teamId2);
                      final team1Name = team1?.name ?? 'Team 1';
                      final team2Name = team2?.name ?? 'Team 2';

                      return MatchCard(
                        key: ValueKey(match.id),
                        matchIndex: index + 1,
                        match: match,
                        team1Name: team1Name,
                        team2Name: team2Name,
                        onEditTap: isAdmin && match.done
                            ? () => _onEditGroupMatch(
                                  context,
                                  match,
                                  team1Name,
                                  team2Name,
                                  groupIndex,
                                )
                            : null,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onEditGroupMatch(
    BuildContext context,
    Match match,
    String team1Name,
    String team2Name,
    int groupIndex,
  ) async {
    final result = await MatchEditDialog.show(
      context,
      match: match,
      team1Name: team1Name,
      team2Name: team2Name,
    );

    if (result != null && context.mounted) {
      final tournamentData =
          Provider.of<TournamentDataState>(context, listen: false);
      final success = await tournamentData.editMatchScore(
        match.id,
        result.score1,
        result.score2,
        groupIndex,
        isKnockout: false,
      );

      if (context.mounted) {
        if (success) {
          SnackBarHelper.showSuccess(context, 'Ergebnis aktualisiert');
        } else {
          SnackBarHelper.showError(context, 'Fehler beim Aktualisieren');
        }
      }
    }
  }
}
