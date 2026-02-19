import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/groups.dart';

void main() {
  group('Groups', () {
    test('creates empty Groups', () {
      final groups = Groups();
      expect(groups.groups, isEmpty);
    });

    test('creates Groups with team lists', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);
      expect(groups.groups.length, 2);
      expect(groups.groups[0].length, 4);
      expect(groups.groups[1].length, 4);
    });
  });

  group('JSON serialization', () {
    test('toJson converts groups to JSON correctly', () {
      final groups = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
      ]);

      final json = groups.toJson();
      expect(json['numberOfGroups'], 2);
      expect(json['groups'], isA<Map<String, dynamic>>());
      expect((json['groups'] as Map<String, dynamic>)['group0'],
          ['t1', 't2', 't3', 't4']);
      expect((json['groups'] as Map<String, dynamic>)['group1'],
          ['t5', 't6', 't7', 't8']);
    });

    test('fromJson creates Groups from JSON correctly', () {
      final json = {
        'numberOfGroups': 2,
        'groups': {
          'group0': ['t1', 't2', 't3', 't4'],
          'group1': ['t5', 't6', 't7', 't8'],
        },
      };

      final groups = Groups.fromJson(json);
      expect(groups.groups.length, 2);
      expect(groups.groups[0], ['t1', 't2', 't3', 't4']);
      expect(groups.groups[1], ['t5', 't6', 't7', 't8']);
    });

    test('round trip serialization preserves data', () {
      final original = Groups(groups: [
        ['t1', 't2', 't3', 't4'],
        ['t5', 't6', 't7', 't8'],
        ['t9', 't10', 't11', 't12'],
      ]);

      final json = original.toJson();
      final restored = Groups.fromJson(json);

      expect(restored.groups.length, original.groups.length);
      for (int i = 0; i < original.groups.length; i++) {
        expect(restored.groups[i], original.groups[i]);
      }
    });

    test('handles empty groups', () {
      final original = Groups(groups: []);
      final json = original.toJson();
      final restored = Groups.fromJson(json);

      expect(restored.groups, isEmpty);
    });

    test('handles different group sizes', () {
      final original = Groups(groups: [
        ['t1', 't2'],
        ['t3', 't4', 't5'],
        ['t6'],
      ]);

      final json = original.toJson();
      final restored = Groups.fromJson(json);

      expect(restored.groups.length, 3);
      expect(restored.groups[0].length, 2);
      expect(restored.groups[1].length, 3);
      expect(restored.groups[2].length, 1);
    });
  });
}
