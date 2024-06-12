import 'package:flutter/material.dart';
import 'package:pongstrong/colors.dart';
import 'package:pongstrong/match_view.dart';

/// Matches für das Spielfeld
final runningMatches = [
  for (var i = 0; i < 8; i++)
    Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView(
        'Kotstulle',
        'Testikuläre Torsion',
        (i + 1).toString(),
        TableColors.get(i),
        true,
        onTap: () => debugPrint('Match ${i + 1} pressed'),
        key: Key('cumatch_$i'), // is this needed?
      ),
    )
];

/// Matches für das Spielfeld
final upcomingMatches = [
  for (var i = 0; i < 8; i++)
    Padding(
      padding: const EdgeInsets.all(4.0),
      child: MatchView(
        'WookieMookie',
        'Penispumpe3000',
        (i + 1).toString(),
        TableColors.get(i),
        i > 4 ? false : true,
        onTap: i > 4 ? null : () => debugPrint('Match ${i + 1} pressed'),
        key: Key('upmatch_$i'), // is this needed?
      ),
    )
];

/// Tabellen für das Spielfeld
final tables = [
  for (var i = 0; i < 6; i++)
    Padding(
      padding: const EdgeInsets.all(8.0),
      key: Key('table_$i'), // is this needed?
      child: table,
    )
];

final table = Table(
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
    pongTableRow('Gruppe A', 'Punkte', 'Diff.', 'Becher'),
    pongTableRow('Kotstulle', '6', '3', '3'),
    pongTableRow('Testikuläre Torsion', '3', '0', '3'),
    pongTableRow('WookieMookie', '0', '-3', '0'),
    pongTableRow('Penispumpe3000', '0', '0', '0')
  ],
);

TableRow pongTableRow(
  String group,
  String points,
  String diff,
  String cups,
) {
  return TableRow(
    decoration: const BoxDecoration(color: Colors.white),
    children: [
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(group),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(points),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(diff),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(2.0),
        child: Center(
          child: Text(cups),
        ),
      ),
    ],
  );
}
