import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';

/// A single entry in the flat match queue with ordering metadata.
///
/// The queue is a sorted flat list. [groupRank] determines the ideal
/// play-order across groups (lower = earlier round / higher priority).
/// [tableOrder] is the sequential position at this entry's specific table.
///
/// The scheduler walks the list top-to-bottom, picking the first match
/// per free table ⟹ `nextMatches`. The first *blocked* match per table
/// (table occupied) becomes `nextNextMatches`.
class MatchQueueEntry {
  /// The actual match data.
  final Match match;

  /// Ideal play-order rank. For group phase this is the match-index within
  /// its group (0-based). For knockouts this is the round index.
  /// Lower values are scheduled first.
  final int groupRank;

  /// Sequential order at this match's specific table (0-based).
  /// E.g. if three matches share table 2, they get tableOrder 0, 1, 2.
  final int tableOrder;

  MatchQueueEntry({
    required this.match,
    this.groupRank = 0,
    this.tableOrder = 0,
  });

  /// Convenience getter for the match ID.
  String get matchId => match.id;

  /// Convenience getter for the table number.
  int get tableNumber => match.tableNumber;

  /// Serialises this entry to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'match': match.toJson(),
        'groupRank': groupRank,
        'tableOrder': tableOrder,
      };

  /// Creates a [MatchQueueEntry] from a JSON map.
  factory MatchQueueEntry.fromJson(Map<String, dynamic> json) =>
      MatchQueueEntry(
        match: Match.fromJson(json['match'] as Map<String, dynamic>),
        groupRank: (json['groupRank'] as int?) ?? 0,
        tableOrder: (json['tableOrder'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchQueueEntry &&
          match == other.match &&
          groupRank == other.groupRank &&
          tableOrder == other.tableOrder;

  @override
  int get hashCode => Object.hash(match, groupRank, tableOrder);
}

/// Manages the match scheduling queue as a single flat, sorted list.
///
/// The [queue] is sorted so that walking top-to-bottom and picking the
/// first entry per free table reliably gives the next matches to play.
/// This solves the old problem of `nextNextMatches` not working when
/// there are more tables than groups.
class MatchQueue {
  /// Flat sorted list of pending match entries.
  /// Sorted by [groupRank] ascending, then [tableOrder] ascending.
  List<MatchQueueEntry> queue;

  /// Matches currently being played.
  List<Match> playing;

  MatchQueue({
    List<MatchQueueEntry>? queue,
    List<Match>? playing,
  })  : queue = queue ?? [],
        playing = playing ?? [];

  // ─── Core scheduling ──────────────────────────────────────

  /// Returns matches that can start now.
  ///
  /// Walks [queue] top-to-bottom, collecting the first entry per free
  /// (not playing, not yet claimed) table.
  List<Match> nextMatches() {
    final occupiedTables = playing.map((m) => m.tableNumber).toSet();
    final claimedTables = <int>{};
    final result = <Match>[];

    for (final entry in queue) {
      if (!occupiedTables.contains(entry.tableNumber) &&
          !claimedTables.contains(entry.tableNumber)) {
        result.add(entry.match);
        claimedTables.add(entry.tableNumber);
      }
    }

    return result;
  }

  /// Returns the first blocked match per table (table occupied by a
  /// playing match or already claimed by [nextMatches]).
  List<Match> nextNextMatches() {
    final nextIds = nextMatches().map((m) => m.id).toSet();
    final claimedTables = <int>{};
    final result = <Match>[];

    for (final entry in queue) {
      if (!nextIds.contains(entry.matchId) &&
          !claimedTables.contains(entry.tableNumber)) {
        result.add(entry.match);
        claimedTables.add(entry.tableNumber);
      }
    }

    return result;
  }

  // ─── Queue mutations ──────────────────────────────────────

  /// Moves a match from [queue] to [playing].
  ///
  /// Returns `false` if the match is not found or its table is occupied.
  bool switchPlaying(String matchId) {
    final index = queue.indexWhere((e) => e.matchId == matchId);
    if (index == -1) return false;

    final entry = queue[index];
    if (!isFree(entry.tableNumber)) return false;

    queue.removeAt(index);
    playing.add(entry.match);
    return true;
  }

  /// Removes a finished match from [playing].
  bool removeFromPlaying(String id) {
    final index = playing.indexWhere((m) => m.id == id);
    if (index == -1) return false;

    playing.removeAt(index);
    return true;
  }

  // ─── Queries ──────────────────────────────────────────────

  /// Checks if the given [tableNumber] is free (not occupied by playing).
  bool isFree(int tableNumber) {
    return !playing.any((m) => m.tableNumber == tableNumber);
  }

  /// Returns `true` if [match] exists anywhere in queue or playing.
  bool contains(Match match) {
    return queue.any((e) => e.matchId == match.id) ||
        playing.any((m) => m.id == match.id);
  }

  /// Returns `true` if no matches remain in queue or playing.
  bool isEmpty() {
    return queue.isEmpty && playing.isEmpty;
  }

  /// Removes all matches from queue and playing.
  void clearQueue() {
    queue.clear();
    playing.clear();
  }

  // ─── Knockout integration ─────────────────────────────────

  /// Adds ready knockout matches to the queue.
  ///
  /// Ready = both teams set and not yet done. Matches already in the
  /// queue (or playing) are skipped. New entries are appended and then
  /// the queue is re-sorted.
  void updateKnockQueue(Knockouts knock) {
    if (knock.champions.rounds.isEmpty || knock.champions.rounds[0].isEmpty) {
      return;
    }
    if (knock.champions.rounds[0][0].teamId1.isEmpty &&
        knock.champions.rounds[0][0].teamId2.isEmpty) {
      return;
    }

    bool matchReady(Match m) =>
        m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done;

    // Track current max tableOrder per table for new entries
    final tableUsage = <int, int>{};
    for (final entry in queue) {
      final t = entry.tableNumber;
      final current = tableUsage[t] ?? 0;
      if (entry.tableOrder >= current) {
        tableUsage[t] = entry.tableOrder + 1;
      }
    }

    void enqueue(Match match, int roundIndex) {
      if (matchReady(match) && !contains(match)) {
        if (match.tableNumber <= 0) return;
        final tbl = match.tableNumber;
        final tOrder = tableUsage[tbl] ?? 0;
        tableUsage[tbl] = tOrder + 1;

        queue.add(MatchQueueEntry(
          match: match,
          groupRank: roundIndex,
          tableOrder: tOrder,
        ));
      }
    }

    for (int r = 0; r < knock.champions.rounds.length; r++) {
      for (final match in knock.champions.rounds[r]) {
        enqueue(match, r);
      }
    }
    for (int r = 0; r < knock.europa.rounds.length; r++) {
      for (final match in knock.europa.rounds[r]) {
        enqueue(match, r);
      }
    }
    for (int r = 0; r < knock.conference.rounds.length; r++) {
      for (final match in knock.conference.rounds[r]) {
        enqueue(match, r);
      }
    }
    for (final match in knock.superCup.matches) {
      // Super cup gets a high groupRank so it's scheduled last
      enqueue(match, 100);
    }

    _sortQueue();
  }

  // ─── Factory: group phase ─────────────────────────────────

  /// Creates a [MatchQueue] from a [Gruppenphase].
  ///
  /// Matches are interleaved across groups: all "match 0" entries first
  /// (one per group), then all "match 1" entries, etc. This ensures fair
  /// round-robin distribution across tables and groups.
  static MatchQueue create(Gruppenphase gruppenphase) {
    final entries = <MatchQueueEntry>[];

    // Find max matches per group
    int maxMatches = 0;
    for (final group in gruppenphase.groups) {
      if (group.length > maxMatches) maxMatches = group.length;
    }

    // Track how many matches have been assigned to each table
    final tableUsage = <int, int>{};

    // Interleave: for each match index, iterate through all groups
    for (int matchIdx = 0; matchIdx < maxMatches; matchIdx++) {
      for (int groupIdx = 0;
          groupIdx < gruppenphase.groups.length;
          groupIdx++) {
        if (matchIdx < gruppenphase.groups[groupIdx].length) {
          final match = gruppenphase.groups[groupIdx][matchIdx];
          final tbl = match.tableNumber;
          final tOrder = tableUsage[tbl] ?? 0;
          tableUsage[tbl] = tOrder + 1;

          entries.add(MatchQueueEntry(
            match: match,
            groupRank: matchIdx,
            tableOrder: tOrder,
          ));
        }
      }
    }

    final queue = MatchQueue(queue: entries, playing: []);
    queue._sortQueue();
    return queue;
  }

  /// Creates a [MatchQueue] with entries for the given [matches].
  ///
  /// Useful for KO-only or round-robin tournament styles where matches
  /// don't come from a multi-group Gruppenphase.
  static MatchQueue fromMatches(List<Match> matches) {
    final tableUsage = <int, int>{};
    final entries = <MatchQueueEntry>[];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final tbl = match.tableNumber;
      final tOrder = tableUsage[tbl] ?? 0;
      tableUsage[tbl] = tOrder + 1;

      entries.add(MatchQueueEntry(
        match: match,
        groupRank: i, // simple sequential ordering
        tableOrder: tOrder,
      ));
    }

    final queue = MatchQueue(queue: entries, playing: []);
    queue._sortQueue();
    return queue;
  }

  // ─── Sorting ──────────────────────────────────────────────

  /// Sorts [queue] by [groupRank] ascending, then [tableOrder] ascending.
  void _sortQueue() {
    queue.sort((a, b) {
      final cmp = a.groupRank.compareTo(b.groupRank);
      if (cmp != 0) return cmp;
      return a.tableOrder.compareTo(b.tableOrder);
    });
  }

  // ─── Serialisation ────────────────────────────────────────

  /// Serialises this queue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'queue': queue.map((e) => e.toJson()).toList(),
        'playing': playing.map((m) => m.toJson()).toList(),
      };

  /// Creates a [MatchQueue] from a JSON map.
  factory MatchQueue.fromJson(Map<String, dynamic> json) => MatchQueue(
        queue: (json['queue'] as List?)
                ?.map(
                    (e) => MatchQueueEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        playing: (json['playing'] as List?)
                ?.map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Creates a deep copy of this MatchQueue.
  MatchQueue clone() => MatchQueue.fromJson(toJson());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MatchQueue) return false;
    if (playing.length != other.playing.length) return false;
    for (int i = 0; i < playing.length; i++) {
      if (playing[i] != other.playing[i]) return false;
    }
    if (queue.length != other.queue.length) return false;
    for (int i = 0; i < queue.length; i++) {
      if (queue[i] != other.queue[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(playing),
        Object.hashAll(queue),
      );
}
