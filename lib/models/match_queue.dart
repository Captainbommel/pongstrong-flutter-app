import 'match.dart';
import 'gruppenphase.dart';
import 'knockouts.dart';

class MatchQueue {
  List<List<Match>> waiting;
  List<Match> playing;

  MatchQueue({
    List<List<Match>>? waiting,
    List<Match>? playing,
  })  : waiting = waiting ?? [],
        playing = playing ?? [];

  // switchPlaying moves the match at index from Waiting to Playing
  bool switchPlaying(String matchId) {
    Match? match;
    int groupIndex = -1;

    // find the match by ID in waiting lists
    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].isNotEmpty && waiting[i][0].id == matchId) {
        match = waiting[i][0];
        groupIndex = i;
        break;
      }
    }

    if (match == null) return false;
    if (!isFree(match.tischNr)) return false;

    waiting[groupIndex].removeAt(0);
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

  // nextMatches returns all Matches with unoccupied table that are next in line
  List<Match> nextMatches() {
    final matches = <Match>[];

    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].isNotEmpty && isFree(waiting[i][0].tischNr)) {
        matches.add(waiting[i][0]);
      }
    }

    return matches;
  }

  // nextNextMatches returns all Matches with occupied table that are next in line
  List<Match> nextNextMatches() {
    final matches = <Match>[];

    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].isNotEmpty && !isFree(waiting[i][0].tischNr)) {
        matches.add(waiting[i][0]);
      }
    }

    return matches;
  }

  // isFree checks if table tischNr is free
  bool isFree(int tischNr) {
    for (var match in playing) {
      if (match.tischNr == tischNr) {
        return false;
      }
    }
    return true;
  }

  // contains checks if a Match is already in the MatchQueue
  bool contains(Match match) {
    for (var line in waiting) {
      for (var m in line) {
        if (m.id == match.id) return true;
      }
    }
    for (var m in playing) {
      if (m.id == match.id) return true;
    }
    return false;
  }

  // isEmpty returns true if q is completely empty
  bool isEmpty() {
    for (var group in waiting) {
      if (group.isNotEmpty) return false;
    }
    return playing.isEmpty;
  }

  // clearQueue removes all matches from waiting and playing
  void clearQueue() {
    for (var line in waiting) {
      line.clear();
    }
    playing.clear();
  }

  // updateKnockQueue adds new ready Matches to the matchQueue
  void updateKnockQueue(Knockouts knock) {
    if (knock.champions.rounds[0][0].teamId1.isEmpty &&
        knock.champions.rounds[0][0].teamId2.isEmpty) {
      return;
    }

    bool matchReady(Match m) =>
        m.teamId1.isNotEmpty && m.teamId2.isNotEmpty && !m.done;

    // search for new matches
    for (var round in knock.champions.rounds) {
      for (var match in round) {
        if (matchReady(match) && !contains(match)) {
          waiting[match.tischNr - 1].add(match);
        }
      }
    }
    for (var round in knock.europa.rounds) {
      for (var match in round) {
        if (matchReady(match) && !contains(match)) {
          waiting[match.tischNr - 1].add(match);
        }
      }
    }
    for (var round in knock.conference.rounds) {
      for (var match in round) {
        if (matchReady(match) && !contains(match)) {
          waiting[match.tischNr - 1].add(match);
        }
      }
    }
    for (var match in knock.superCup.matches) {
      if (matchReady(match) && !contains(match)) {
        waiting[match.tischNr - 1].add(match);
      }
    }
  }

  // formMatchQueue creates a MatchQueue out of Gruppenphase
  static MatchQueue create(Gruppenphase gruppenphase) {
    final queue = MatchQueue(
      waiting: List.generate(6, (_) => <Match>[]),
      playing: [],
    );

    const pattern = [
      [1, 2, 5, 6, 3, 4],
      [3, 4, 1, 2, 5, 6],
      [5, 6, 3, 4, 1, 2],
      [1, 2, 5, 6, 3, 4],
      [3, 4, 1, 2, 5, 6],
      [5, 6, 3, 4, 1, 2],
    ];

    for (int i = 0; i < pattern[0].length; i++) {
      for (int j = 0; j < gruppenphase.groups.length; j++) {
        queue.waiting[pattern[j][i] - 1].add(gruppenphase.groups[j][i]);
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
                ?.map((m) => Match.fromJson(m))
                .toList() ??
            [],
      );

  /// Creates a deep copy of this MatchQueue.
  /// Note: This uses JSON serialization and should be used sparingly for performance reasons.
  MatchQueue clone() => MatchQueue.fromJson(toJson());
}
