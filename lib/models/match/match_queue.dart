import 'package:pongstrong/models/groups/gruppenphase.dart';
import 'package:pongstrong/models/knockout/knockouts.dart';
import 'package:pongstrong/models/match/match.dart';

/// Manages the match scheduling queue with waiting and currently playing matches.
class MatchQueue {
  /// Matches waiting to be played, grouped by table assignment.
  List<List<Match>> waiting;

  /// Matches currently being played.
  List<Match> playing;

  MatchQueue({
    List<List<Match>>? waiting,
    List<Match>? playing,
  })  : waiting = waiting ?? [],
        playing = playing ?? [];

  /// Moves a match from the waiting queue to the playing list.
  bool switchPlaying(String matchId) {
    Match? match;
    int groupIndex = -1;
    int matchIndex = -1;

    // find the match by ID anywhere in waiting lists
    for (int i = 0; i < waiting.length; i++) {
      for (int j = 0; j < waiting[i].length; j++) {
        if (waiting[i][j].id == matchId) {
          match = waiting[i][j];
          groupIndex = i;
          matchIndex = j;
          break;
        }
      }
      if (match != null) break;
    }

    if (match == null) return false;
    if (!isFree(match.tableNumber)) return false;

    waiting[groupIndex].removeAt(matchIndex);
    playing.add(match);
    return true;
  }

  /// Removes a finished match from the playing list.
  bool removeFromPlaying(String id) {
    final index = playing.indexWhere((match) => match.id == id);

    if (index != -1) {
      playing.removeAt(index);
      return true;
    }

    return false;
  }

  /// Returns all waiting matches whose table is free and are next in line.
  ///
  /// When there are more tables than groups, this looks deeper into each
  /// group's queue so that extra tables are utilised immediately.
  List<Match> nextMatches() {
    final matches = <Match>[];
    final tables = <int>{};

    // Create a list of indices sorted by the length of their waiting lists (descending)
    final rankedIndices = List.generate(waiting.length, (i) => i)
      ..sort((a, b) => waiting[b].length.compareTo(waiting[a].length));

    // Round-robin across groups: each pass picks at most one match per group
    // on a free, unclaimed table. Repeat until no new match is found.
    final positions = List.filled(waiting.length, 0);
    bool added = true;
    while (added) {
      added = false;
      for (final i in rankedIndices) {
        while (positions[i] < waiting[i].length) {
          final match = waiting[i][positions[i]];
          positions[i]++;
          if (isFree(match.tableNumber) &&
              !tables.contains(match.tableNumber)) {
            tables.add(match.tableNumber);
            matches.add(match);
            added = true;
            break; // one match per group per pass
          }
        }
      }
    }

    return matches;
  }

  /// Returns the first blocked match per group (table occupied or claimed).
  List<Match> nextNextMatches() {
    final readyIds = nextMatches().map((m) => m.id).toSet();
    final matches = <Match>[];
    final tables = <int>{};

    // Create a list of indices sorted by the length of their waiting lists (descending)
    final rankedIndices = List.generate(waiting.length, (i) => i)
      ..sort((a, b) => waiting[b].length.compareTo(waiting[a].length));

    for (final i in rankedIndices) {
      for (final match in waiting[i]) {
        if (!readyIds.contains(match.id) &&
            !tables.contains(match.tableNumber)) {
          matches.add(match);
          tables.add(match.tableNumber);
          break;
        }
      }
    }
    return matches;
  }

  /// Checks if the given table number is free (not currently in use).
  bool isFree(int tableNumber) {
    for (final match in playing) {
      if (match.tableNumber == tableNumber) {
        return false;
      }
    }
    return true;
  }

  /// Returns `true` if [match] is already in the queue (waiting or playing).
  bool contains(Match match) {
    for (final line in waiting) {
      for (final m in line) {
        if (m.id == match.id) return true;
      }
    }
    for (final m in playing) {
      if (m.id == match.id) return true;
    }
    return false;
  }

  /// Returns `true` if no matches remain in waiting or playing.
  bool isEmpty() {
    for (final group in waiting) {
      if (group.isNotEmpty) return false;
    }
    return playing.isEmpty;
  }

  /// Removes all matches from waiting and playing lists.
  void clearQueue() {
    for (final line in waiting) {
      line.clear();
    }
    playing.clear();
  }

  /// Adds ready knockout matches to the waiting queue.
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

    void enqueue(Match match) {
      if (matchReady(match) && !contains(match)) {
        final idx = match.tableNumber - 1;
        if (idx < 0) return;
        // Auto-expand waiting lists if tischNr exceeds current size
        while (idx >= waiting.length) {
          waiting.add(<Match>[]);
        }
        waiting[idx].add(match);
      }
    }

    // search for new matches
    for (final round in knock.champions.rounds) {
      for (final match in round) {
        enqueue(match);
      }
    }
    for (final round in knock.europa.rounds) {
      for (final match in round) {
        enqueue(match);
      }
    }
    for (final round in knock.conference.rounds) {
      for (final match in round) {
        enqueue(match);
      }
    }
    for (final match in knock.superCup.matches) {
      enqueue(match);
    }
  }

  /// Creates a [MatchQueue] from a [Gruppenphase].
  static MatchQueue create(Gruppenphase gruppenphase) {
    final queue = MatchQueue(
      waiting: List.generate(gruppenphase.groups.length, (_) => <Match>[]),
      playing: [],
    );

    for (int i = 0; i < gruppenphase.groups.length; i++) {
      for (final match in gruppenphase.groups[i]) {
        queue.waiting[i].add(match);
      }
    }

    return queue;
  }

  /// Serialises this queue to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'waiting': waiting
            .map((line) => line.map((m) => m.toJson()).toList())
            .toList(),
        'playing': playing.map((m) => m.toJson()).toList(),
      };

  /// Creates a [MatchQueue] from a Firestore JSON map.
  factory MatchQueue.fromJson(Map<String, dynamic> json) => MatchQueue(
        waiting: (json['waiting'] as List?)
                ?.map((line) => (line as List)
                    .map((m) => Match.fromJson(m as Map<String, dynamic>))
                    .toList())
                .toList() ??
            [],
        playing: (json['playing'] as List?)
                ?.map((m) => Match.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Creates a deep copy of this MatchQueue.
  /// Note: This uses JSON serialization and should be used sparingly for performance reasons.
  MatchQueue clone() => MatchQueue.fromJson(toJson());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MatchQueue) return false;
    if (playing.length != other.playing.length) return false;
    for (int i = 0; i < playing.length; i++) {
      if (playing[i] != other.playing[i]) return false;
    }
    if (waiting.length != other.waiting.length) return false;
    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].length != other.waiting[i].length) return false;
      for (int j = 0; j < waiting[i].length; j++) {
        if (waiting[i][j] != other.waiting[i][j]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(playing),
        Object.hashAll(waiting.map((w) => Object.hashAll(w))),
      );
}
