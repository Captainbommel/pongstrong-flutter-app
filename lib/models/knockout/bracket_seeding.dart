// Bracket seeding and group-to-knockout transition logic.
//
// Handles single-elimination bracket generation, tournament seeding,
// group conflict resolution, and the full transition from group phase
// to knockout rounds for 1–10 groups.
import 'package:pongstrong/models/groups/tabellen.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';

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
    rounds.add(List.generate(count, (i) => Match(id: '$prefix$r-${i + 1}')));
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

/// Counts same-tier pairs in R1 matches (slots i and i+1 for even i).
/// This prevents first-place teams from playing each other in round 1.
int _countR1TierConflicts(
  List<String?> slots,
  Map<String, int> tiers,
  int size,
) {
  int count = 0;
  for (int i = 0; i < size - 1; i += 2) {
    final a = slots[i];
    final b = slots[i + 1];
    if (a == null || b == null) continue;
    final tierA = tiers[a];
    final tierB = tiers[b];
    if (tierA == null || tierB == null) continue;
    // Only count conflicts between first-place teams (tier 0)
    if (tierA == 0 && tierB == 0) count++;
  }
  return count;
}

/// Combined cost function for conflict resolution.
/// Heavily penalizes tier conflicts (first-vs-first in R1) in addition to
/// same-group early meetings. The large multiplier ensures tier conflicts
/// are always resolved first.
int _countAllConflicts(
  List<String?> slots,
  Map<String, int> groups,
  Map<String, int> tiers,
  int size,
  int minRound,
) {
  final groupConflicts = _countEarlyMeetings(slots, groups, size, minRound);
  final tierConflicts = _countR1TierConflicts(slots, tiers, size);
  // Weight tier conflicts heavily to prioritize avoiding first-vs-first
  return tierConflicts * 1000 + groupConflicts;
}

/// Swaps teams so that no same-group pair can meet before the **semi-final**
/// AND no two first-place teams play each other in round 1.
///
/// For a 4-team bracket (2 rounds) this is a no-op — R1 *is* the semi.
/// For an 8-team bracket (3 rounds) this prevents R1 same-group matchups.
/// For a 16-team bracket (4 rounds) this prevents both R1 (first-round) and
/// R2 (quarter-final) same-group matchups.
///
/// The [tiers] map assigns each team to a tier (0 = first-place, 1 = second,
/// etc.). First-place teams (tier 0) are prevented from meeting in round 1.
void _resolveGroupConflicts(
  List<String?> slots,
  Map<String, int> groups,
  Map<String, int> tiers,
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
    final before = _countAllConflicts(slots, groups, tiers, size, minRound);
    if (before == 0) break;

    // Find any offending pair (same-group meeting early OR first-vs-first R1).
    for (int i = 0; i < size && !improved; i++) {
      for (int j = i + 1; j < size && !improved; j++) {
        final a = slots[i];
        final b = slots[j];
        if (a == null || b == null) continue;

        // Check if this pair is problematic
        final sameGroup = groups[a] == groups[b];
        final earlyMeeting = _earliestMeetingRound(i, j) < minRound;
        final firstVsFirstR1 = (i ~/ 2 == j ~/ 2) &&
            (i % 2 == 0 && j % 2 == 1) &&
            tiers[a] == 0 &&
            tiers[b] == 0;

        if (!(sameGroup && earlyMeeting) && !firstVsFirstR1) continue;

        // Try swapping slots[j] with every other slot.
        for (int k = 0; k < size && !improved; k++) {
          if (k == i || k == j) continue;
          final c = slots[k];
          if (c == null) continue;
          slots[j] = c;
          slots[k] = b;
          if (_countAllConflicts(slots, groups, tiers, size, minRound) <
              before) {
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
            if (_countAllConflicts(slots, groups, tiers, size, minRound) <
                before) {
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
/// prevents first-place teams from meeting in R1, and pre-advances bye teams.
///
/// The [tiers] map assigns each team to a tier (0 = first-place, 1 = second,
/// etc.) for proper seed separation in round 1.
void _seedBracket(
  List<List<Match>> rounds,
  List<String> teams,
  Map<String, int> groups,
  Map<String, int> tiers,
  int bracketSize,
) {
  if (rounds.isEmpty || teams.length < 2) return;

  final seeding = generateSeeding(bracketSize);
  final slots = List<String?>.filled(bracketSize, null);
  for (int i = 0; i < bracketSize; i++) {
    final idx = seeding[i] - 1;
    if (idx < teams.length) slots[i] = teams[idx];
  }

  _resolveGroupConflicts(slots, groups, tiers, bracketSize);

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

/// Splits tables across leagues so that Champions, Europa, and Conference each
/// get their own dedicated subset of tables, allowing all three leagues to
/// start and run simultaneously.
///
/// Tables are allocated proportionally based on the number of first-round
/// matches each league has. Every active league receives at least one table.
/// The Super Cup cycles across the full table range (it runs after all leagues
/// finish).
///
/// If [tableCount] is less than the number of active leagues, falls back to
/// shared cycling (no dedicated subsets).
void mapTablesDynamic(Knockouts knock,
    {int tableCount = 6, bool splitTables = false}) {
  // When splitting is disabled, use simple shared cycling (original behaviour).
  if (!splitTables) {
    int t = 0;
    void assign(List<List<Match>> rounds) {
      for (final round in rounds) {
        for (final match in round) {
          match.tableNumber = t % tableCount + 1;
          t++;
        }
      }
    }

    assign(knock.champions.rounds);
    assign(knock.europa.rounds);
    assign(knock.conference.rounds);
    for (int i = 0; i < knock.superCup.matches.length; i++) {
      knock.superCup.matches[i].tableNumber = t % tableCount + 1;
      t++;
    }
    return;
  }

  // Collect active leagues (those with at least one round).
  final activeLeagues = <List<List<Match>>>[];
  if (knock.champions.rounds.isNotEmpty) {
    activeLeagues.add(knock.champions.rounds);
  }
  if (knock.europa.rounds.isNotEmpty) {
    activeLeagues.add(knock.europa.rounds);
  }
  if (knock.conference.rounds.isNotEmpty) {
    activeLeagues.add(knock.conference.rounds);
  }

  if (activeLeagues.isEmpty) {
    // Only Super Cup — assign trivially.
    for (int i = 0; i < knock.superCup.matches.length; i++) {
      knock.superCup.matches[i].tableNumber = i % tableCount + 1;
    }
    return;
  }

  // Not enough tables for separate subsets → fall back to shared cycling.
  if (tableCount < activeLeagues.length) {
    int t = 0;
    for (final rounds in activeLeagues) {
      for (final round in rounds) {
        for (final match in round) {
          match.tableNumber = t % tableCount + 1;
          t++;
        }
      }
    }
    for (int i = 0; i < knock.superCup.matches.length; i++) {
      knock.superCup.matches[i].tableNumber = t % tableCount + 1;
      t++;
    }
    return;
  }

  // ── Proportional allocation based on first-round match counts ─────────
  final firstRoundCounts = activeLeagues.map((r) => r[0].length).toList();
  final totalFirst = firstRoundCounts.fold<int>(0, (s, c) => s + c);

  // Start with 1 table per league, then distribute the remainder.
  final allocations = List<int>.filled(activeLeagues.length, 1);
  final int extra = tableCount - activeLeagues.length;

  if (totalFirst > 0 && extra > 0) {
    // Floor-distribute proportionally.
    final extraPerLeague = <int>[];
    int assigned = 0;
    for (int i = 0; i < activeLeagues.length; i++) {
      final e = (extra * firstRoundCounts[i] / totalFirst).floor();
      extraPerLeague.add(e);
      assigned += e;
    }
    for (int i = 0; i < activeLeagues.length; i++) {
      allocations[i] += extraPerLeague[i];
    }

    // Hand out remaining tables (from rounding) by largest-remainder.
    final int leftover = extra - assigned;
    if (leftover > 0) {
      final indices = List.generate(activeLeagues.length, (i) => i);
      indices.sort((a, b) {
        final fracA =
            (extra * firstRoundCounts[a] / totalFirst) - extraPerLeague[a];
        final fracB =
            (extra * firstRoundCounts[b] / totalFirst) - extraPerLeague[b];
        return fracB.compareTo(fracA);
      });
      for (int i = 0; i < leftover; i++) {
        allocations[indices[i]]++;
      }
    }
  }

  // ── Assign table numbers within each league's dedicated range ─────────
  int tableStart = 0;
  for (int i = 0; i < activeLeagues.length; i++) {
    final rounds = activeLeagues[i];
    final count = allocations[i];
    int t = 0;
    for (final round in rounds) {
      for (final match in round) {
        match.tableNumber = tableStart + (t % count) + 1;
        t++;
      }
    }
    tableStart += count;
  }

  // Super Cup runs after all leagues finish → use the full table range.
  for (int i = 0; i < knock.superCup.matches.length; i++) {
    knock.superCup.matches[i].tableNumber = i % tableCount + 1;
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
/// * First-place teams are also prevented from meeting each other in round 1.
Knockouts evaluateGroups(Tabellen tabellen,
    {int tableCount = 6, bool splitTables = false}) {
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

  // ── tier map (0=first, 1=second, 2=third, 3=fourth) ───────────────────────
  final tierOf = <String, int>{};
  for (int g = 0; g < n; g++) {
    for (int rank = 0; rank < tabellen.tables[g].length; rank++) {
      tierOf[tabellen.tables[g][rank].teamId] = rank;
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
  _seedBracket(knock.champions.rounds, champ, groupOf, tierOf, champSize);
  if (eBracket > 0) {
    _seedBracket(knock.europa.rounds, euro, groupOf, tierOf, eBracket);
  }
  if (fBracket > 0) {
    _seedBracket(knock.conference.rounds, conf, groupOf, tierOf, fBracket);
  }

  // ── table assignment ──────────────────────────────────────────────────
  mapTablesDynamic(knock, tableCount: tableCount, splitTables: splitTables);

  return knock;
}
