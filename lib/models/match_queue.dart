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
  bool switchPlaying(int index) {
    if (waiting[index].isEmpty) return false;
    if (!isFree(index + 1)) return false;

    final match = waiting[index][0];
    waiting[index].removeAt(0);
    playing.add(match);
    return true;
  }

  // remove removes the Match from the MatchQueue
  bool removeFromPlaying(String id) {
    final index = playing.indexWhere((m) => m.id == id);
    if (index != -1) {
      playing.removeAt(index);
      return true;
    }
    return false;
  }

  // Next returns the first Match from Queue index
  Match? next(int index) {
    if (waiting[index].isEmpty) return null;
    return waiting[index][0];
  }

  // nextMatches returns all Matches with unoccupied table
  List<Match> nextMatches() {
    final matches = <Match>[];
    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].isNotEmpty && isFree(waiting[i][0].tischNr)) {
        matches.add(waiting[i][0]);
      }
    }
    return matches;
  }

  // NextNextMatch returns all Matches with occupied table
  List<Match> nextNextMatches() {
    final matches = <Match>[];
    for (int i = 0; i < waiting.length; i++) {
      if (waiting[i].isNotEmpty && !isFree(waiting[i][0].tischNr)) {
        matches.add(waiting[i][0]);
      }
    }
    return matches;
  }

  // getMatchID returns the ID of the Match at table t if in Playing
  String? getMatchId(int index) {
    for (var match in playing) {
      if (match.tischNr == index) {
        return match.id;
      }
    }
    return null;
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

  // isFree checks if table index is free
  bool isFree(int index) {
    for (var m in playing) {
      if (m.tischNr == index) return false;
    }
    return true;
  }

  // isEmpty returns true if q is completely empty
  bool isEmpty() {
    for (var line in waiting) {
      if (line.isNotEmpty) return false;
    }
    return playing.isEmpty;
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
      [0, 1, 2, 3, 4, 5],
      [1, 2, 3, 4, 5, 0],
      [2, 3, 4, 5, 0, 1],
      [3, 4, 5, 0, 1, 2],
      [4, 5, 0, 1, 2, 3],
      [5, 0, 1, 2, 3, 4],
    ];

    for (int i = 0; i < pattern[0].length; i++) {
      for (int j = 0; j < gruppenphase.groups.length; j++) {
        queue.waiting[i].add(gruppenphase.groups[pattern[j][i]][i]);
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
}
