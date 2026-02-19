import 'package:pongstrong/models/gruppenphase.dart';
import 'package:pongstrong/models/knockouts.dart';
import 'package:pongstrong/models/match.dart';

class MatchQueue {
  List<List<Match>> waiting;
  List<Match> playing;

  MatchQueue({
    List<List<Match>>? waiting,
    List<Match>? playing,
  })  : waiting = waiting ?? [],
        playing = playing ?? [];

  // switchPlaying moves the match from Waiting to Playing
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
    if (!isFree(match.tischNr)) return false;

    waiting[groupIndex].removeAt(matchIndex);
    playing.add(match);
    return true;
  }

  // removeFromPlaying removes the Match from the MatchQueue
  bool removeFromPlaying(String id) {
    final index = playing.indexWhere((match) => match.id == id);

    if (index != -1) {
      playing.removeAt(index);
      return true;
    }

    return false;
  }

  // nextMatches returns all Matches with unoccupied table that are next in line.
  // When there are more tables than groups, this looks deeper into each
  // group's queue so that extra tables are utilised immediately.
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
          if (isFree(match.tischNr) && !tables.contains(match.tischNr)) {
            tables.add(match.tischNr);
            matches.add(match);
            added = true;
            break; // one match per group per pass
          }
        }
      }
    }

    return matches;
  }

  // nextNextMatches returns the first blocked match per group (table occupied
  // or claimed by a ready match) that is not already returned by nextMatches.
  List<Match> nextNextMatches() {
    final readyIds = nextMatches().map((m) => m.id).toSet();
    final matches = <Match>[];
    final tables = <int>{};

    // Create a list of indices sorted by the length of their waiting lists (descending)
    final rankedIndices = List.generate(waiting.length, (i) => i)
      ..sort((a, b) => waiting[b].length.compareTo(waiting[a].length));

    for (final i in rankedIndices) {
      for (final match in waiting[i]) {
        if (!readyIds.contains(match.id) && !tables.contains(match.tischNr)) {
          matches.add(match);
          tables.add(match.tischNr);
          break;
        }
      }
    }
    return matches;
  }

  // isFree checks if table tischNr is free
  bool isFree(int tischNr) {
    for (final match in playing) {
      if (match.tischNr == tischNr) {
        return false;
      }
    }
    return true;
  }

  // contains checks if a Match is already in the MatchQueue
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

  // isEmpty returns true if q is completely empty
  bool isEmpty() {
    for (final group in waiting) {
      if (group.isNotEmpty) return false;
    }
    return playing.isEmpty;
  }

  // clearQueue removes all matches from waiting and playing
  void clearQueue() {
    for (final line in waiting) {
      line.clear();
    }
    playing.clear();
  }

  // updateKnockQueue adds new ready Matches to the matchQueue
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
        final idx = match.tischNr - 1;
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

  // formMatchQueue creates a MatchQueue out of Gruppenphase
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

  Map<String, dynamic> toJson() => {
        'waiting': waiting
            .map((line) => line.map((m) => m.toJson()).toList())
            .toList(),
        'playing': playing.map((m) => m.toJson()).toList(),
      };

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
}
