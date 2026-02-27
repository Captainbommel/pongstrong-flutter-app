import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups.dart';
import 'package:pongstrong/models/team.dart';

void main() {
  group('Team', () {
    test('creates team with default values', () {
      final team = Team();
      expect(team.id, '');
      expect(team.name, '');
      expect(team.member1, '');
      expect(team.member2, '');
      expect(team.member3, '');
    });

    test('creates team with custom values', () {
      final team = Team(
        id: 't1',
        name: 'Team Alpha',
        member1: 'Alice',
        member2: 'Bob',
        member3: 'Charlie',
      );
      expect(team.id, 't1');
      expect(team.name, 'Team Alpha');
      expect(team.member1, 'Alice');
      expect(team.member2, 'Bob');
      expect(team.member3, 'Charlie');
    });

    test('members getter returns only non-empty members', () {
      expect(Team(member1: 'A', member2: 'B', member3: 'C').members,
          ['A', 'B', 'C']);
      expect(Team(member1: 'A', member2: 'B').members, ['A', 'B']);
      expect(Team(member1: 'A').members, ['A']);
      expect(Team().members, isEmpty);
    });

    test('maxMembers is 3', () {
      expect(Team.maxMembers, 3);
    });

    test('defaultMemberCount is 2', () {
      expect(Team.defaultMemberCount, 2);
    });
  });

  group('origin', () {
    test('returns correct group index for team', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
        ['t9', 't10', 't11', 't12'],
      ]);

      final team1 = Team(id: 't1');
      final team5 = Team(id: 't5');
      final team10 = Team(id: 't10');

      expect(team1.origin(groups), 0);
      expect(team5.origin(groups), 1);
      expect(team10.origin(groups), 2);
    });

    test('returns -1 for team not in any group', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);

      final team = Team(id: 't99');
      expect(team.origin(groups), -1);
    });

    test('returns -1 for empty groups', () {
      final groups = Groups(groups: []);
      final team = Team(id: 't1');
      expect(team.origin(groups), -1);
    });
  });

  group('JSON serialization', () {
    test('toJson converts team to JSON correctly', () {
      final team = Team(
        id: 't1',
        name: 'Team Alpha',
        member1: 'Alice',
        member2: 'Bob',
        member3: 'Charlie',
      );

      final json = team.toJson();
      expect(json['id'], 't1');
      expect(json['name'], 'Team Alpha');
      expect(json['member1'], 'Alice');
      expect(json['member2'], 'Bob');
      expect(json['member3'], 'Charlie');
    });

    test('fromJson creates team from JSON correctly', () {
      final json = {
        'id': 't1',
        'name': 'Team Alpha',
        'member1': 'Alice',
        'member2': 'Bob',
        'member3': 'Charlie',
      };

      final team = Team.fromJson(json);
      expect(team.id, 't1');
      expect(team.name, 'Team Alpha');
      expect(team.member1, 'Alice');
      expect(team.member2, 'Bob');
      expect(team.member3, 'Charlie');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};
      final team = Team.fromJson(json);
      expect(team.id, '');
      expect(team.name, '');
      expect(team.member1, '');
      expect(team.member2, '');
      expect(team.member3, '');
    });

    test('round trip serialization preserves data', () {
      final original = Team(
        id: 't1',
        name: 'Team Alpha',
        member1: 'Alice',
        member2: 'Bob',
        member3: 'Charlie',
      );

      final json = original.toJson();
      final restored = Team.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.member1, original.member1);
      expect(restored.member2, original.member2);
      expect(restored.member3, original.member3);
    });
  });

  group('equality', () {
    test('teams with same values are equal', () {
      final team1 = Team(
        id: 't1',
        name: 'Team Alpha',
        member1: 'Alice',
        member2: 'Bob',
        member3: 'Charlie',
      );
      final team2 = Team(
        id: 't1',
        name: 'Team Alpha',
        member1: 'Alice',
        member2: 'Bob',
        member3: 'Charlie',
      );

      expect(team1 == team2, true);
      expect(team1.hashCode, team2.hashCode);
    });

    test('teams with different values are not equal', () {
      final team1 = Team(id: 't1', name: 'Team Alpha');
      final team2 = Team(id: 't2', name: 'Team Beta');

      expect(team1 == team2, false);
    });

    test('team is equal to itself', () {
      final team = Team(id: 't1', name: 'Team Alpha');
      expect(team == team, true);
    });
  });
}
