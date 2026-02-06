import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Reusable standings table widget for displaying group phase rankings.
///
/// Used in both the desktop playing field and mobile views.
class StandingsTable extends StatelessWidget {
  final int groupIndex;
  final List<StandingsRow> rows;
  final bool showGroupHeader;

  const StandingsTable({
    super.key,
    required this.groupIndex,
    required this.rows,
    this.showGroupHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        border: const TableBorder(
          top: BorderSide(width: 2),
          bottom: BorderSide(width: 2),
          left: BorderSide(width: 2),
          right: BorderSide(width: 2),
          horizontalInside: BorderSide(width: 1.2),
          verticalInside: BorderSide(width: 1.2),
        ),
        children: [
          _buildHeaderRow(
            showGroupHeader
                ? 'Gruppe ${String.fromCharCode(65 + groupIndex)}'
                : 'Team',
          ),
          ...rows.map((row) => _buildDataRow(row)),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow(String firstCol) {
    return TableRow(
      decoration: const BoxDecoration(color: FieldColors.darkSkyblue),
      children: [
        _cell(firstCol, isHeader: true),
        _cell('Punkte', isHeader: true, center: true),
        _cell('Diff.', isHeader: true, center: true),
        _cell('Becher', isHeader: true, center: true),
      ],
    );
  }

  TableRow _buildDataRow(StandingsRow row) {
    return TableRow(
      children: [
        _cell(row.teamName),
        _cell(row.points.toString(), center: true),
        _cell(row.difference.toString(), center: true),
        _cell(row.cups.toString(), center: true),
      ],
    );
  }

  TableCell _cell(String text, {bool isHeader = false, bool center = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Data class for a single row in the standings table
class StandingsRow {
  final String teamName;
  final int points;
  final int difference;
  final int cups;

  const StandingsRow({
    required this.teamName,
    required this.points,
    required this.difference,
    required this.cups,
  });
}
