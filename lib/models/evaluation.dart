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

// evaluate evaluates a slice of Matches and returns a table
List<TableRow> evaluate(List<Match> matches) {
  final table = List.generate(4, (_) => TableRow());
  const pattern = [0, 1, 2, 3, 0, 2, 1, 3, 3, 0, 1, 2];

  for (int i = 0; i < matches.length; i++) {
    final match = matches[i];
    final t1 = pattern[i * 2];
    final t2 = pattern[i * 2 + 1];

    if (match.done) {
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

  // Set team IDs
  for (int i = 0; i < 2; i++) {
    table[pattern[i * 2]].teamId = matches[0].teamId1;
    table[pattern[i * 2 + 1]].teamId = matches[0].teamId2;
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
  const first = [1, 4, 2, 5, 3, 6];
  for (int j = 0; j < 6; j++) {
    knock.champions.rounds[0][first[j] - 1].teamId1 = teamIds[j][0];
  }

  const second = [
    [7, 0],
    [0, 0],
    [5, 1],
    [2, 1],
    [7, 1],
    [0, 1]
  ];
  for (int j = 0; j < 6; j++) {
    if (second[j][0] == 0) continue;
    final idx = second[j][0] - 1;
    final teamIdx = second[j][1];
    knock.champions.rounds[0][idx].teamId2 = teamIds[j][teamIdx];
  }

  // Find best thirds
  final allThirds = <TableRow>[];
  for (int i = 0; i < 6; i++) {
    allThirds.add(tabellen.tables[i][2]);
  }
  Tabellen.sortTable(allThirds);

  final thirdIds = allThirds.map((row) => row.teamId).toList();
  final bestThirdIds = thirdIds.sublist(0, 4);

  const pattern = [
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

  // Fill remaining slots 1, 3, 4, 6 with best thirds
  for (int i = 0; i < 3; i++) {
    for (var posPattern in pattern) {
      if (posPattern[1].contains(thirdIds.indexOf(bestThirdIds[i]))) {
        knock.champions.rounds[0][posPattern[0][0] - 1].teamId2 =
            bestThirdIds[i];
        break;
      }
    }
  }

  // EUROPA - find best fourths
  final allFourth = <TableRow>[];
  for (int i = 0; i < 6; i++) {
    allFourth.add(tabellen.tables[i][3]);
  }
  Tabellen.sortTable(allFourth);

  final fourthIds = allFourth.map((row) => row.teamId).toList();
  final bestFourthIds = fourthIds.sublist(0, 4);

  var i = 0;
  var j = 0;
  while (j < 8) {
    if (i % 2 == 0) {
      knock.europa.rounds[0][j ~/ 2].teamId1 = bestFourthIds[i];
    } else {
      knock.europa.rounds[0][j ~/ 2].teamId2 = bestFourthIds[i];
      j++;
    }
    i++;
  }

  // CONFERENCE
  i = 0;
  j = 0;
  while (j < 8) {
    if (i % 2 == 0) {
      knock.conference.rounds[0][j ~/ 2].teamId1 = fourthIds[i + 4];
    } else {
      knock.conference.rounds[0][j ~/ 2].teamId2 = fourthIds[i + 4];
      j++;
    }
    i++;
  }

  mapTables(knock);
  return knock;
}
