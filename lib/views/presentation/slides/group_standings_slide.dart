import 'package:flutter/material.dart';
import 'package:pongstrong/models/groups/tabellen.dart' as model;
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';

/// Slide showing the standings table for a single group.
///
/// The [groupIndex] determines which group is displayed.
/// Styled after the FieldView card pattern used in the main app.
class GroupStandingsSlide extends StatelessWidget {
  final TournamentDataState data;
  final int groupIndex;

  const GroupStandingsSlide({
    super.key,
    required this.data,
    required this.groupIndex,
  });

  @override
  Widget build(BuildContext context) {
    final tables = data.tabellen.tables;
    if (tables.isEmpty || groupIndex >= tables.length) {
      return const Center(
        child: Text(
          'Keine Tabellendaten',
          style: TextStyle(fontSize: 28, color: AppColors.textSecondary),
        ),
      );
    }

    final rows = tables[groupIndex];
    final groupLetter = String.fromCharCode(65 + groupIndex);

    // Check if all matches in this group are done
    final groupMatches = data.gruppenphase.groups.length > groupIndex
        ? data.gruppenphase.groups[groupIndex]
        : <Match>[];
    final allDone =
        groupMatches.isNotEmpty && groupMatches.every((m) => m.done);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side:
                  const BorderSide(width: 3, color: GroupPhaseColors.steelblue),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header – FieldView style
                Container(
                  color: GroupPhaseColors.steelblue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered title
                      Text(
                        'Gruppe $groupLetter',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: AppColors.textSecondary,
                              offset: Offset(1, 1),
                              blurRadius: 1.5,
                            ),
                          ],
                        ),
                      ),
                      // Badge pushed to the right
                      if (allDone)
                        Positioned(
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '✓ Abgeschlossen',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Table body
                ColoredBox(
                  color: FieldColors.fieldbackground,
                  child: _StandingsTable(
                    rows: rows,
                    teamNameResolver: (id) => data.getTeam(id)?.name ?? id,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<model.TableRow> rows;
  final String Function(String) teamNameResolver;

  const _StandingsTable({
    required this.rows,
    required this.teamNameResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(52),
          1: FlexColumnWidth(3),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(),
          4: FlexColumnWidth(),
        },
        children: [
          _headerRow(),
          ...List.generate(rows.length, (i) => _dataRow(i, rows[i])),
        ],
      ),
    );
  }

  TableRow _headerRow() {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: GroupPhaseColors.steelblue.withAlpha(100),
          ),
        ),
      ),
      children: const [
        _LargeCell(text: '#', isHeader: true, center: true),
        _LargeCell(text: 'Team', isHeader: true),
        _LargeCell(text: 'Pkt.', isHeader: true, center: true),
        _LargeCell(text: 'Diff.', isHeader: true, center: true),
        _LargeCell(text: 'Becher', isHeader: true, center: true),
      ],
    );
  }

  TableRow _dataRow(int index, model.TableRow row) {
    final name = teamNameResolver(row.teamId);

    return TableRow(
      decoration: BoxDecoration(
        border: index < rows.length - 1
            ? Border(
                bottom: BorderSide(
                  color: AppColors.grey300.withAlpha(120),
                ),
              )
            : null,
      ),
      children: [
        _LargeCell(
          text: '${index + 1}.',
          center: true,
        ),
        _LargeCell(text: name),
        _LargeCell(
          text: '${row.points}',
          center: true,
        ),
        _LargeCell(text: '${row.difference}', center: true),
        _LargeCell(text: '${row.cups}', center: true),
      ],
    );
  }
}

class _LargeCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool center;

  const _LargeCell({
    required this.text,
    this.isHeader = false,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isHeader ? 16 : 22,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: isHeader ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
