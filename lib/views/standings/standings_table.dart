import 'package:flutter/material.dart';
import 'package:pongstrong/models/groups/tabellen.dart' as tabellen;
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// Displays the standings table for a single group.
///
/// Uses [Selector] to only rebuild when the group's table data changes.
class StandingsTable extends StatelessWidget {
  final int groupIndex;

  const StandingsTable({super.key, required this.groupIndex});

  @override
  Widget build(BuildContext context) {
    // Only rebuild when this group's table changes
    return Selector<TournamentDataState, List<tabellen.TableRow>>(
      selector: (_, state) => groupIndex < state.tabellen.tables.length
          ? state.tabellen.tables[groupIndex]
          : [],
      builder: (context, currentTable, child) {
        final state = Provider.of<TournamentDataState>(context, listen: false);
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
                      final team = state.getTeam(row.teamId);
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
