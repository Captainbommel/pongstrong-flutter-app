import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/tournament/configurations.dart';

void main() {
  group('Configurations.generateMatchPairings', () {
    test('Even team count returns correct pairings', () {
      final pairings = Configurations.generateMatchPairings(4);
      expect(pairings.length, 6);
      expect(
          pairings,
          containsAll([
            [0, 3],
            [1, 2],
            [0, 2],
            [3, 1],
            [0, 1],
            [2, 3]
          ]));
    });

    test('Odd team count returns correct pairings (dummy removed)', () {
      final pairings = Configurations.generateMatchPairings(5);
      expect(pairings.length, 10); // 5 teams: 5*4/2 = 10 matches
      expect(pairings.every((p) => !p.contains(-1)), true);
      final allTeams = pairings.expand((p) => p).toSet();
      expect(allTeams.contains(-1), false);
    });

    test('Throws for less than 2 teams', () {
      expect(
          () => Configurations.generateMatchPairings(1), throwsArgumentError);
    });

    test('Large even team count', () {
      final pairings = Configurations.generateMatchPairings(10);
      expect(pairings.length, 45); // 10*9/2 = 45 matches
    });

    test('Large odd team count', () {
      final pairings = Configurations.generateMatchPairings(11);
      expect(pairings.length, 55); // 11*10/2 = 55 matches
      expect(pairings.every((p) => !p.contains(-1)), true);
    });

    test('All teams play each other once', () {
      const n = 7;
      final pairings = Configurations.generateMatchPairings(n);
      final expectedMatches = <Set<int>>{};
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          expectedMatches.add({i, j});
        }
      }
      final actualMatches = pairings.map((p) => {p[0], p[1]}).toSet();
      expect(actualMatches, expectedMatches);
    });
  });

  group('Configurations.generateTableConfiguration', () {
    test('Valid configuration for even teams', () {
      final config = Configurations.generateTableConfiguration(2, 8, 2);
      expect(config, isNotNull);
      expect(config!.length, 2);
      expect(config[0].length, 6); // 4 teams per group: 4*3/2 = 6 matches
    });

    test('Returns null for uneven distribution', () {
      final config = Configurations.generateTableConfiguration(3, 10, 2);
      expect(config, isNull);
    });

    test('Valid configuration for odd teams per group', () {
      final config = Configurations.generateTableConfiguration(3, 9, 2);
      expect(config, isNotNull);
      expect(config!.length, 3);
      expect(config[0].length, 3); // 3 teams per group: 3 matches
    });

    test('Table assignment cycles correctly', () {
      final config = Configurations.generateTableConfiguration(2, 8, 3);
      expect(config, isNotNull);
      final tables = config!.expand((g) => g).toSet();
      expect(tables.difference({1, 2, 3}), isEmpty);
    });

    test('Warns when more tables than groups', () {
      // Just check that it doesn't throw and returns a config
      final config = Configurations.generateTableConfiguration(2, 8, 5);
      expect(config, isNotNull);
    });

    test('Large configuration', () {
      final config = Configurations.generateTableConfiguration(4, 32, 4);
      expect(config, isNotNull);
      expect(config!.length, 4);
      expect(config[0].length, 28); // 8 teams per group: 8*7/2 = 28 matches
    });
  });
}
