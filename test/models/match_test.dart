import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/match.dart';

void main() {
  group('Match', () {
    test('creates match with default values', () {
      final match = Match();
      expect(match.teamId1, '');
      expect(match.teamId2, '');
      expect(match.score1, 0);
      expect(match.score2, 0);
      expect(match.tischNr, 0);
      expect(match.id, '');
      expect(match.done, false);
    });

    test('creates match with custom values', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 10,
        score2: 5,
        tischNr: 3,
        id: 'g11',
        done: true,
      );
      expect(match.teamId1, 'team1');
      expect(match.teamId2, 'team2');
      expect(match.score1, 10);
      expect(match.score2, 5);
      expect(match.tischNr, 3);
      expect(match.id, 'g11');
      expect(match.done, true);
    });
  });

  group('getWinnerId', () {
    //TODO: remove since getWinnerId mostly gets covered by evaluation tests?
    test('returns team1 ID when team1 wins by deathcup', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: -1,
        score2: 5,
      );
      expect(match.getWinnerId(), 'team1');
    });

    test('returns team2 ID when team2 wins by deathcup', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 5,
        score2: -1,
      );
      expect(match.getWinnerId(), 'team2');
    });

    test('returns team1 ID when team1 has higher score', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 10,
        score2: 5,
      );
      expect(match.getWinnerId(), 'team1');
    });

    test('returns team2 ID when team2 has higher score', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 5,
        score2: 10,
      );
      expect(match.getWinnerId(), 'team2');
    });

    test('returns null for tie', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 5,
        score2: 5,
      );
      expect(match.getWinnerId(), null);
    });

    test('returns null for unfinished match', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 0,
        score2: 0,
      );
      expect(match.getWinnerId(), null);
    });
  });

  group('getPoints', () {
    test('returns correct points for normal win', () {
      final match = Match(score1: 10, score2: 5);
      final points = match.getPoints();
      expect(points, isNotNull);
      expect(points!.$1, 3); // winner gets 3
      expect(points.$2, 0); // loser gets 0
    });

    test('returns correct points for overtime win', () {
      final match = Match(score1: 16, score2: 12);
      final points = match.getPoints();
      expect(points, isNotNull);
      expect(points!.$1, 2); // overtime winner
      expect(points.$2, 1); // overtime loser
    });

    test('returns correct points for deathcup', () {
      final match = Match(score1: -1, score2: 5);
      final points = match.getPoints();
      expect(points, isNotNull);
      expect(points!.$1, 4); // deathcup winner
      expect(points.$2, 0); // deathcup loser
    });

    test('returns null for invalid scores', () {
      final match = Match(score1: 5, score2: 5);
      expect(match.getPoints(), isNull);
    });

    test('delegates to calculatePoints from evaluation', () {
      // Verify it matches the standalone function
      final match = Match(score1: 19, score2: 17);
      expect(match.getPoints(), (2, 1));
    });
  });

  group('JSON serialization', () {
    test('toJson converts match to JSON correctly', () {
      final match = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 10,
        score2: 5,
        tischNr: 3,
        id: 'g11',
        done: true,
      );

      final json = match.toJson();
      expect(json['teamId1'], 'team1');
      expect(json['teamId2'], 'team2');
      expect(json['score1'], 10);
      expect(json['score2'], 5);
      expect(json['tischnummer'], 3);
      expect(json['id'], 'g11');
      expect(json['done'], true);
    });

    test('fromJson creates match from JSON correctly', () {
      final json = {
        'teamId1': 'team1',
        'teamId2': 'team2',
        'score1': 10,
        'score2': 5,
        'tischnummer': 3,
        'id': 'g11',
        'done': true,
      };

      final match = Match.fromJson(json);
      expect(match.teamId1, 'team1');
      expect(match.teamId2, 'team2');
      expect(match.score1, 10);
      expect(match.score2, 5);
      expect(match.tischNr, 3);
      expect(match.id, 'g11');
      expect(match.done, true);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};
      final match = Match.fromJson(json);
      expect(match.teamId1, '');
      expect(match.teamId2, '');
      expect(match.score1, 0);
      expect(match.score2, 0);
      expect(match.tischNr, 0);
      expect(match.id, '');
      expect(match.done, false);
    });

    test('round trip serialization preserves data', () {
      final original = Match(
        teamId1: 'team1',
        teamId2: 'team2',
        score1: 10,
        score2: 5,
        tischNr: 3,
        id: 'g11',
        done: true,
      );

      final json = original.toJson();
      final restored = Match.fromJson(json);

      expect(restored.teamId1, original.teamId1);
      expect(restored.teamId2, original.teamId2);
      expect(restored.score1, original.score1);
      expect(restored.score2, original.score2);
      expect(restored.tischNr, original.tischNr);
      expect(restored.id, original.id);
      expect(restored.done, original.done);
    });
  });
}
