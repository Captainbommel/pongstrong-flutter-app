import 'match.dart';
import 'tabellen.dart';
import 'gruppenphase.dart';
import 'knockouts.dart';

// cups helps with negative values
int cups(int n) {
  switch (n) {
    case -1:
      return 10;
    case -2:
      return 16;
    default:
      return n;
  }
}

// isValid checks if a score is valid
bool isValid(int b1, int b2) {
  if (b1 == -1 && b2 >= 0 && b2 <= 10) return true;
  if (b2 == -1 && b1 >= 0 && b1 <= 10) return true;
  if (b1 == -2 && b2 >= 10) return true;
  if (b2 == -2 && b1 >= 10) return true;
  if (b1 == 10 && b2 < 10) return true;
  if (b2 == 10 && b1 < 10) return true;
  if (b1 == 16 && b2 >= 10 && b2 < 16) return true;
  if (b2 == 16 && b1 >= 10 && b1 < 16) return true;
  if (b1 == 19 && b2 >= 16 && b2 < 19) return true;
  if (b2 == 19 && b1 >= 16 && b1 < 19) return true;
  if (b1 >= 19 && b2 >= 19 && (b1 > b2 || b2 > b1)) return true;
  return false;
}

// evaluate evaluates a List of Matches and returns a table
List<TableRow> evaluate(List<Match> matches) {
  final table = List.generate(4, (_) => TableRow());

  // Build a map of teamId -> table index by scanning all matches
  final teamIndexMap = <String, int>{};
  for (var match in matches) {
    if (!teamIndexMap.containsKey(match.teamId1)) {
      teamIndexMap[match.teamId1] = teamIndexMap.length;
    }
    if (!teamIndexMap.containsKey(match.teamId2)) {
      teamIndexMap[match.teamId2] = teamIndexMap.length;
    }
  }

  // Set team IDs in table based on their assigned indices
  for (var entry in teamIndexMap.entries) {
    table[entry.value].teamId = entry.key;
  }

  // Calculate standings for each finished match
  for (var match in matches) {
    if (match.done) {
      final t1 = teamIndexMap[match.teamId1]!;
      final t2 = teamIndexMap[match.teamId2]!;

      final points = match.getPoints();
      if (points != null) {
        table[t1].punkte += points.$1;
        table[t2].punkte += points.$2;
      }

      table[t1].differenz += cups(match.score1) - cups(match.score2);
      table[t2].differenz += cups(match.score2) - cups(match.score1);

      table[t1].becher += cups(match.score1);
      table[t2].becher += cups(match.score2);
    }
  }

  return table;
}

// evalGruppen evaluates all groups in Gruppenphase and returns Tabellen
Tabellen evalGruppen(Gruppenphase gruppenphase) {
  final tables = <List<TableRow>>[];
  for (var group in gruppenphase.groups) {
    tables.add(evaluate(group));
  }
  final tabellen = Tabellen(tables: tables);
  tabellen.sortTables();
  return tabellen;
}

// EvaluateGroups8 switches the tournament into knockout mode (8 groups)
Knockouts evaluateGroups8(Tabellen tabellen) {
  tabellen.sortTables();

  final teamIds = tabellen.tables
      .map((table) => table.map((row) => row.teamId).toList())
      .toList();

  final knock = Knockouts();
  knock.instantiate();

  // champ
  const fir = [0, 2, 4, 6, 1, 3, 5, 7];
  const sec = [1, 3, 5, 7, 0, 2, 4, 6];
  for (int j = 0; j < 8; j++) {
    knock.champions.rounds[0][j].teamId1 = teamIds[fir[j]][0];
    knock.champions.rounds[0][j].teamId2 = teamIds[sec[j]][1];
  }

  // euro & conf
  int i = 0, j = 0;
  while (j < 8) {
    if (i % 2 == 0) {
      knock.europa.rounds[0][j ~/ 2].teamId1 = teamIds[i][2];
    } else {
      knock.europa.rounds[0][j ~/ 2].teamId2 = teamIds[i][2];
      j++;
    }
    i++;
  }
  i = 0;
  j = 0;
  while (j < 8) {
    if (i % 2 == 0) {
      knock.conference.rounds[0][j ~/ 2].teamId1 = teamIds[i][3];
    } else {
      knock.conference.rounds[0][j ~/ 2].teamId2 = teamIds[i][3];
      j++;
    }
    i++;
  }

  mapTables(knock);
  return knock;
}

// EvaluateGroups6 switches the tournament into knockout mode (6 groups)
Knockouts evaluateGroups6(Tabellen tabellen) {
  tabellen.sortTables();

  final teamIds = tabellen.tables
      .map((table) => table.map((row) => row.teamId).toList())
      .toList();

  final knock = Knockouts();
  knock.instantiate();

  // CHAMP

  /// The first number refers to the 8 slots in the first round of the champions knockout,
  /// the second number indicates the empty team slot.
  const firstsSlotPattern = [
    [1, 0],
    [4, 0],
    [2, 0],
    [5, 0],
    [3, 0],
    [6, 0],
  ];

  for (int j = 0; j < 6; j++) {
    knock.champions.rounds[0][firstsSlotPattern[j][0]].teamId1 = teamIds[j][0];
  }

  /// The first number refers to the 8 slots in the first round of the champions knockout,
  /// the second number indicates the empty team slot.
  const secondsSlotPattern = [
    [7, 0],
    [0, 0],
    [5, 1],
    [2, 1],
    [7, 1],
    [0, 1]
  ];
  for (int j = 0; j < 6; j++) {
    final idx = secondsSlotPattern[j][0];
    final slot = secondsSlotPattern[j][1];

    if (slot == 0) {
      knock.champions.rounds[0][idx].teamId1 = teamIds[j][1];
    } else {
      knock.champions.rounds[0][idx].teamId2 = teamIds[j][1];
    }
  }

  // Find best thirds
  final allThirds = <TableRow>[];
  for (int i = 0; i < 6; i++) {
    allThirds.add(tabellen.tables[i][2]);
  }
  Tabellen.sortTable(allThirds);

  final thirdIds = allThirds.map((row) => row.teamId).toList();
  final bestThirdIds = thirdIds.sublist(0, 4);

  /// The first number refers to the 8 slots in the first round of the champions knockout,
  /// the list indicates all allowed origin groups (0-5) for that slot, so
  /// that no two teams from the same group meet in the second round.
  const bestThirdsSlotPattern = [
    [
      [1],
      [2, 3, 4]
    ],
    [
      [3],
      [0, 1, 5]
    ],
    [
      [4],
      [0, 4, 5]
    ],
    [
      [6],
      [1, 2, 3]
    ]
  ];
  for (int i = 0; i < 4; i++) {
    final remainingThirds = List.of(bestThirdIds);

    for (int j = 0; j < remainingThirds.length; j++) {
      // find origin group of this third placed team
      final origin = tabellen.tables.indexWhere(
        (table) => table.any((row) => row.teamId == remainingThirds[j]),
      );

      // loop over allowed slots of pattern_i
      for (int k = 0; k < 3; k++) {
        // check if origin matches an allowed origin
        if (bestThirdsSlotPattern[i][1][k] == origin + 1) {
          knock.champions.rounds[0][bestThirdsSlotPattern[i][0][0]].teamId2 =
              remainingThirds[j];
          remainingThirds.removeAt(j);
          break;
        }
      }
    }

    if (remainingThirds.isEmpty) {
      break;
    }

    bestThirdIds.insertAll(0, bestThirdIds.sublist(3));
    bestThirdIds.removeRange(3, bestThirdIds.length);
  }

  // EUROPA

  // find best fourths
  final allFourth = <TableRow>[];
  for (int i = 0; i < 6; i++) {
    allFourth.add(tabellen.tables[i][3]);
  }

  Tabellen.sortTable(allFourth);

  final fourthIds = allFourth.map((row) => row.teamId).toList();

  // 5th-6th best thirds and top 2 fourths
  final euroTeamIds = <String>[
    thirdIds[4],
    thirdIds[5],
    fourthIds[0],
    fourthIds[1],
  ];

  // skips round 0
  knock.europa.rounds[1][0].teamId1 = euroTeamIds[0];
  knock.europa.rounds[1][0].teamId2 = euroTeamIds[1];
  knock.europa.rounds[1][1].teamId1 = euroTeamIds[2];
  knock.europa.rounds[1][1].teamId2 = euroTeamIds[3];

  // CONFERENCE

  // 3rd-6th best fourths
  final confTeamIds = <String>[
    fourthIds[2],
    fourthIds[3],
    fourthIds[4],
    fourthIds[5],
  ];

  // skips round 0
  knock.conference.rounds[1][0].teamId1 = confTeamIds[0];
  knock.conference.rounds[1][0].teamId2 = confTeamIds[1];
  knock.conference.rounds[1][1].teamId1 = confTeamIds[2];
  knock.conference.rounds[1][1].teamId2 = confTeamIds[3];

  mapTables(knock);
  return knock;
}
