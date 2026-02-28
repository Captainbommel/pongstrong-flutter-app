import 'package:flutter/material.dart';
import 'package:pongstrong/models/groups/tabellen.dart' as tabellen;
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/models/match/scoring.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/widgets/match_edit_dialog.dart';
import 'package:provider/provider.dart';

class TeamsView extends StatelessWidget {
  const TeamsView({super.key});

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
          // Group header
          Container(
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
          ),
          // Content
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

  Widget _buildLargeScreenLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Matches on the left
        Expanded(
          flex: 3,
          child: _buildMatchesList(context),
        ),
        const SizedBox(width: 16),
        // Table on the right
        Expanded(
          flex: 2,
          child: _buildTable(context),
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout(BuildContext context) {
    return Column(
      children: [
        _buildMatchesList(context),
        const SizedBox(height: 16),
        _buildTable(context),
      ],
    );
  }

  Widget _buildMatchesList(BuildContext context) {
    // Use Selector to only rebuild when matches for this group change
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
              Builder(builder: (context) {
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
                    // Pre-fetch team names once for caching
                    final team1 = data.getTeam(match.teamId1);
                    final team2 = data.getTeam(match.teamId2);
                    final team1Name = team1?.name ?? 'Team 1';
                    final team2Name = team2?.name ?? 'Team 2';

                    return _MatchCard(
                      key: ValueKey(match.id),
                      matchIndex: index + 1,
                      match: match,
                      team1Name: team1Name,
                      team2Name: team2Name,
                      onEditTap: isAdmin && match.done
                          ? () => _onEditGroupMatch(
                              context, match, team1Name, team2Name, groupIndex)
                          : null,
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTable(BuildContext context) {
    // Use Selector to only rebuild when this specific group's table changes
    return Selector<TournamentDataState, List<tabellen.TableRow>>(
      selector: (_, state) => groupIndex < state.tabellen.tables.length
          ? state.tabellen.tables[groupIndex]
          : [],
      builder: (context, currentTable, child) {
        final data = Provider.of<TournamentDataState>(context, listen: false);

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
                  'Tabelle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnColored,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder.all(
                    color: GroupPhaseColors.steelblue,
                    width: 1.5,
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                  },
                  children: [
                    _tableHeaderRow(),
                    ...currentTable.map((row) {
                      final team = data.getTeam(row.teamId);
                      return _tableDataRow(
                        team?.name ?? 'Team',
                        row.points.toString(),
                        row.difference.toString(),
                        row.cups.toString(),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TableRow _tableHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        color: GroupPhaseColors.steelblue.withAlpha(100),
      ),
      children: [
        _tableCell('Team', isHeader: true, alignment: Alignment.centerLeft),
        _tableCell('Punkte', isHeader: true),
        _tableCell('Diff.', isHeader: true),
        _tableCell('Becher', isHeader: true),
      ],
    );
  }

  TableRow _tableDataRow(String team, String points, String diff, String cups) {
    return TableRow(
      children: [
        _tableCell(team, alignment: Alignment.centerLeft),
        _tableCell(points),
        _tableCell(diff),
        _tableCell(cups),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool isHeader = false, Alignment alignment = Alignment.center}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }
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
      result['score1']!,
      result['score2']!,
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

class _MatchCard extends StatelessWidget {
  final int matchIndex;
  final Match match;
  final String team1Name;
  final String team2Name;
  final VoidCallback? onEditTap;

  const _MatchCard({
    super.key,
    required this.matchIndex,
    required this.match,
    required this.team1Name,
    required this.team2Name,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = match.done;

    return GestureDetector(
      onTap: onEditTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.surface
              : GroupPhaseColors.grouppurple.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone
                ? GroupPhaseColors.steelblue
                : GroupPhaseColors.grouppurple,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Checkmark for finished matches or match index
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.check_circle,
                  color: GroupPhaseColors.steelblue,
                  size: 24,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '$matchIndex.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: GroupPhaseColors.grouppurple,
                  ),
                ),
              ),
            // Teams and scores
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamRow(team1Name, match.score1, isDone),
                  const SizedBox(height: 4),
                  _buildTeamRow(team2Name, match.score2, isDone),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Table number at the back
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? GroupPhaseColors.steelblue
                    : GroupPhaseColors.grouppurple.withAlpha(150),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  match.tableNumber.toString(),
                  style: const TextStyle(
                    color: AppColors.textOnColored,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(String teamName, int score, bool isDone) {
    return Row(
      children: [
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isDone) ...[
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 20,
            decoration: BoxDecoration(
              color: GroupPhaseColors.cupred.withAlpha(100),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              displayScore(score),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
