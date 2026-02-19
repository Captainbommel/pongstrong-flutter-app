// Bracket seeding and group-to-knockout transition logic.
//
// Handles single-elimination bracket generation, tournament seeding,
// group conflict resolution, and the full transition from group phase
// to knockout rounds for 1–10 groups.
import 'package:pongstrong/models/knockouts.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/models/tabellen.dart';

// ============================================================================
// Legacy 6-group transition
// ============================================================================

/// Transitions a 6-group tournament into knockout mode (legacy layout).
///
/// Uses hardcoded slot patterns for Champions (16 teams), Europa (4),
/// and Conference (4). Superseded by [evaluateGroups] for general use.
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

// ============================================================================
// Generalized group-to-knockout transition (1–10 groups, group size 4)
// ============================================================================

/// Smallest power of 2 ≥ [x].
int _nextPow2(int x) {
  if (x <= 1) return 1;
  int p = 1;
  while (p < x) {
    p *= 2;
  }
  return p;
}

/// Largest power of 2 ≤ [x].
int _prevPow2(int x) {
  final next = _nextPow2(x);
  return next == x ? x : next >> 1;
}

/// Nearest power of 2 to [x]; ties prefer the *next* power (promotes rather
/// than demotes on a tie).
int _nearestPow2(int x) {
  if (x <= 2) return x <= 1 ? 1 : 2;
  final next = _nextPow2(x);
  final prev = next >> 1;
  return (next - x <= x - prev) ? next : prev;
}

/// Standard single-elimination seeding for a bracket of [size] teams.
///
/// Returns a list where index = bracket slot, value = seed number (1-based).
/// Example for size 8: `[1, 8, 4, 5, 2, 7, 3, 6]`
///   → Match 0: seed 1 vs seed 8
///   → Match 1: seed 4 vs seed 5
///   → Match 2: seed 2 vs seed 7
///   → Match 3: seed 3 vs seed 6
List<int> generateSeeding(int size) {
  var seeds = [1];
  while (seeds.length < size) {
    final expanded = <int>[];
    final n = seeds.length * 2 + 1;
    for (final s in seeds) {
      expanded
        ..add(s)
        ..add(n - s);
    }
    seeds = expanded;
  }
  return seeds;
}

/// Creates rounds for a single-elimination bracket of [bracketSize] teams.
///
/// Each round halves the match count until 1 remains (the final).
/// IDs follow the pattern: `<prefix><roundNum><matchNum>` (e.g. `c13`).
List<List<Match>> createBracketRounds(int bracketSize, String prefix) {
  if (bracketSize < 2) return [];
  final rounds = <List<Match>>[];
  int count = bracketSize ~/ 2;
  int r = 1;
  while (count >= 1) {
    rounds.add(List.generate(count, (i) => Match(id: '$prefix$r${i + 1}')));
    count ~/= 2;
    r++;
  }
  return rounds;
}

/// Returns the earliest round (1-indexed) where two teams at bracket
/// positions [a] and [b] could meet, assuming both win every match.
int _earliestMeetingRound(int a, int b) {
  for (int r = 1; r <= 20; r++) {
    if ((a >> r) == (b >> r)) return r;
  }
  return 999; // unreachable for valid bracket slots
}

/// Counts same-group pairs whose earliest possible meeting is before
/// round [minRound].
int _countEarlyMeetings(
  List<String?> slots,
  Map<String, int> groups,
  int size,
  int minRound,
) {
  int count = 0;
  for (int i = 0; i < size; i++) {
    for (int j = i + 1; j < size; j++) {
      final a = slots[i];
      final b = slots[j];
      if (a == null || b == null) continue;
      if (groups[a] != groups[b]) continue;
      if (_earliestMeetingRound(i, j) < minRound) count++;
    }
  }
  return count;
}

/// Swaps teams so that no same-group pair can meet before the **semi-final**.
///
/// For a 4-team bracket (2 rounds) this is a no-op — R1 *is* the semi.
/// For an 8-team bracket (3 rounds) this prevents R1 same-group matchups.
/// For a 16-team bracket (4 rounds) this prevents both R1 (first-round) and
/// R2 (quarter-final) same-group matchups.
void _resolveGroupConflicts(
  List<String?> slots,
  Map<String, int> groups,
  int size,
) {
  // Number of rounds in the bracket (log₂ of size).
  int totalRounds = 0;
  int s = size;
  while (s > 1) {
    totalRounds++;
    s >>= 1;
  }

  // Semi-final = round (totalRounds − 1).  Meetings before that are bad.
  // For ≤ 2-round brackets the semi IS round 1, so nothing to fix.
  final minRound = totalRounds - 1;
  if (minRound < 1) return;

  bool improved = true;
  while (improved) {
    improved = false;
    final before = _countEarlyMeetings(slots, groups, size, minRound);
    if (before == 0) break;

    // Find the first offending pair.
    for (int i = 0; i < size && !improved; i++) {
      for (int j = i + 1; j < size && !improved; j++) {
        final a = slots[i];
        final b = slots[j];
        if (a == null || b == null) continue;
        if (groups[a] != groups[b]) continue;
        if (_earliestMeetingRound(i, j) >= minRound) continue;

        // Try swapping slots[j] with every other slot.
        for (int k = 0; k < size && !improved; k++) {
          if (k == i || k == j) continue;
          final c = slots[k];
          if (c == null) continue;
          slots[j] = c;
          slots[k] = b;
          if (_countEarlyMeetings(slots, groups, size, minRound) < before) {
            improved = true;
          } else {
            slots[j] = b;
            slots[k] = c;
          }
        }

        // Also try swapping slots[i].
        if (!improved) {
          for (int k = 0; k < size && !improved; k++) {
            if (k == i || k == j) continue;
            final c = slots[k];
            if (c == null) continue;
            slots[i] = c;
            slots[k] = a;
            if (_countEarlyMeetings(slots, groups, size, minRound) < before) {
              improved = true;
            } else {
              slots[i] = a;
              slots[k] = c;
            }
          }
        }
      }
    }
  }
}

/// Seeds [teams] into [rounds] using standard tournament seeding, resolves
/// same-group conflicts (ensuring they don't meet before the semi-final),
/// and pre-advances bye teams.
void _seedBracket(
  List<List<Match>> rounds,
  List<String> teams,
  Map<String, int> groups,
  int bracketSize,
) {
  if (rounds.isEmpty || teams.length < 2) return;

  final seeding = generateSeeding(bracketSize);
  final slots = List<String?>.filled(bracketSize, null);
  for (int i = 0; i < bracketSize; i++) {
    final idx = seeding[i] - 1;
    if (idx < teams.length) slots[i] = teams[idx];
  }

  _resolveGroupConflicts(slots, groups, bracketSize);

  // Populate first-round matches.
  for (int m = 0; m < rounds[0].length; m++) {
    rounds[0][m].teamId1 = slots[m * 2] ?? '';
    rounds[0][m].teamId2 = slots[m * 2 + 1] ?? '';
  }

  // Handle byes: pre-advance the lone team to round 2.
  if (rounds.length > 1) {
    for (int m = 0; m < rounds[0].length; m++) {
      final match = rounds[0][m];
      String? bye;
      if (match.teamId1.isNotEmpty && match.teamId2.isEmpty) {
        bye = match.teamId1;
        match.teamId1 = '';
      } else if (match.teamId2.isNotEmpty && match.teamId1.isEmpty) {
        bye = match.teamId2;
        match.teamId2 = '';
      }
      if (bye != null) {
        final next = rounds[1][m ~/ 2];
        if (m.isEven) {
          next.teamId1 = bye;
        } else {
          next.teamId2 = bye;
        }
      }
    }
  }
}

/// Assigns table numbers (1..[tableCount]) cyclically to all KO matches.
// TODO: Split tables across leagues so that Champions, Europa, and Conference
// each get their own dedicated subset of tables. This would allow all three
// leagues to start and run simultaneously instead of sequentially.
void mapTablesDynamic(Knockouts knock, {int tableCount = 6}) {
  void assign(List<List<Match>> rounds, int offset) {
    int t = offset;
    for (final round in rounds) {
      for (final match in round) {
        match.tableNumber = t % tableCount + 1;
        t++;
      }
    }
  }

  assign(knock.champions.rounds, 0);
  assign(knock.europa.rounds, 0);
  assign(knock.conference.rounds, knock.europa.rounds.isEmpty ? 0 : 4);
  for (int i = 0; i < knock.superCup.matches.length; i++) {
    knock.superCup.matches[i].tableNumber = (5 + i) % tableCount + 1;
  }
}

/// Generalized group→knockout transition for **1–10 groups** of 4 teams.
///
/// ### Distribution
///
/// | League     | Teams                                                    |
/// |------------|----------------------------------------------------------|
/// | Champions  | `nearest_pow2(2·N)` — all 1sts + 2nds (± promoted/demoted)|
/// | Europa     | largest power-of-2 ≤ remaining teams (filled first)      |
/// | Conference | teams left after Europa (omitted if < 2)                  |
///
/// 4th-place teams **never** enter Champions; they always land in the
/// lowest available league.  The remaining-team pool is ordered by group
/// rank (demoted 2nds → remaining 3rds → all 4ths) so that Europa is
/// filled with higher-ranked teams first.
///
/// When `2·N` is not a power of two the function either **promotes** the best
/// 3rd-place teams (and 4ths if necessary) into Champions, or **demotes** the
/// worst 2nd-place teams to the Europa/Conference pool — whichever direction
/// requires fewer added/removed teams.
///
/// ### Seeding
///
/// * Standard tournament seeding (seed 1 vs seed B, seed 2 vs B−1, …).
/// * Same-group teams are separated so they cannot meet before the
///   semi-final (no quarter-final or earlier same-group matchups).
/// * Bye slots (bracket size > team count) are pre-advanced to round 2.
///
/// ### Group-separation heuristic
///
/// * 1st-place teams occupy the top seeds, 2nd-place the next tier, promoted
///   3rds the bottom seeds.  Standard seeding therefore pairs 1sts
///   against lower-ranked opponents in round 1.
/// * The swap pass guarantees that no two members of the same group can meet
///   before the semi-final (e.g. not in the quarter-final of a 16-team
///   bracket).
Knockouts evaluateGroups(Tabellen tabellen) {
  tabellen.sortTables();
  final n = tabellen.tables.length;

  if (n < 2 || n > 10) {
    throw ArgumentError('Need 2–10 groups, got $n');
  }

  // ── group-origin map ─────────────────────────────────────────────────────
  final groupOf = <String, int>{};
  for (int g = 0; g < n; g++) {
    for (final row in tabellen.tables[g]) {
      groupOf[row.teamId] = g;
    }
  }

  // ── rank tiers, each sorted by cross-group performance ────────────────
  List<TableRow> tier(int rank) {
    final rows = [for (int g = 0; g < n; g++) tabellen.tables[g][rank]];
    Tabellen.sortTable(rows);
    return rows;
  }

  final firsts = tier(0);
  final seconds = tier(1);
  final thirds = tier(2);
  final fourths = tier(3);

  // ── champion bracket size ─────────────────────────────────────────────
  final champSize = _nearestPow2(2 * n);

  // ── select champion teams (in seed order) ─────────────────────────────
  final champ = <String>[];
  final champSet = <String>{};
  void pick(TableRow r) {
    champ.add(r.teamId);
    champSet.add(r.teamId);
  }

  // All firsts always go to champions (seeds 1..N).
  for (final r in firsts) {
    pick(r);
  }

  if (champSize >= 2 * n) {
    // All seconds also go (seeds N+1..2N).
    for (final r in seconds) {
      pick(r);
    }
    // Fill remaining slots with best 3rds only (4ths never enter Champions).
    int extra = champSize - 2 * n;
    for (int i = 0; i < thirds.length && extra > 0; i++, extra--) {
      pick(thirds[i]);
    }
  } else {
    // Demote worst seconds; only the best (champSize − N) seconds stay.
    final keep = champSize - n;
    for (int i = 0; i < keep; i++) {
      pick(seconds[i]);
    }
  }

  // ── remaining teams → Europa / Conference ─────────────────────────────
  final rest = <String>[];
  // Demoted 2nds first (already performance-sorted)
  for (final r in seconds) {
    if (!champSet.contains(r.teamId)) rest.add(r.teamId);
  }
  // Remaining 3rds next
  for (final r in thirds) {
    if (!champSet.contains(r.teamId)) rest.add(r.teamId);
  }
  // All 4ths last (never in champions)
  for (final r in fourths) {
    rest.add(r.teamId);
  }

  final euroSize = rest.length >= 2 ? _prevPow2(rest.length) : 0;
  var euro = rest.take(euroSize).toList();
  var conf = rest.skip(euroSize).toList();

  // Leagues need ≥ 2 teams; otherwise those teams are excluded.
  if (euro.length < 2) euro = [];
  if (conf.length < 2) conf = [];

  final eBracket = euro.length >= 2 ? _nextPow2(euro.length) : 0;
  final fBracket = conf.length >= 2 ? _nextPow2(conf.length) : 0;

  // ── build knockout structure ──────────────────────────────────────────
  final knock = Knockouts(
    champions: Champions(rounds: createBracketRounds(champSize, 'c')),
    europa: Europa(
      rounds: eBracket > 0 ? createBracketRounds(eBracket, 'e') : [],
    ),
    conference: Conference(
      rounds: fBracket > 0 ? createBracketRounds(fBracket, 'f') : [],
    ),
    superCup: Super()..instantiate(),
  );

  // ── seed each bracket ─────────────────────────────────────────────────
  _seedBracket(knock.champions.rounds, champ, groupOf, champSize);
  if (eBracket > 0) {
    _seedBracket(knock.europa.rounds, euro, groupOf, eBracket);
  }
  if (fBracket > 0) {
    _seedBracket(knock.conference.rounds, conf, groupOf, fBracket);
  }

  // ── table assignment ──────────────────────────────────────────────────
  mapTablesDynamic(knock);

  return knock;
}
