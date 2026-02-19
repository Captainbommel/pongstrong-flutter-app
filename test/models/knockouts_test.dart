import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/knockouts.dart';

void main() {
  group('Champions', () {
    test('creates empty Champions', () {
      final champions = Champions();
      expect(champions.rounds, isEmpty);
    });

    test('instantiate creates correct structure', () {
      final champions = Champions();
      champions.instantiate();

      expect(champions.rounds.length, 4);
      expect(champions.rounds[0].length, 8); // Round of 16
      expect(champions.rounds[1].length, 4); // Quarter finals
      expect(champions.rounds[2].length, 2); // Semi finals
      expect(champions.rounds[3].length, 1); // Final
    });

    test('instantiate assigns correct match IDs', () {
      final champions = Champions();
      champions.instantiate();

      expect(champions.rounds[0][0].id, 'c11');
      expect(champions.rounds[0][7].id, 'c18');
      expect(champions.rounds[1][0].id, 'c21');
      expect(champions.rounds[3][0].id, 'c41');
    });
  });

  group('Europa', () {
    test('instantiate creates correct structure', () {
      final europa = Europa();
      europa.instantiate();

      expect(europa.rounds.length, 3);
      expect(europa.rounds[0].length, 4);
      expect(europa.rounds[1].length, 2);
      expect(europa.rounds[2].length, 1);
    });

    test('instantiate assigns correct match IDs', () {
      final europa = Europa();
      europa.instantiate();

      expect(europa.rounds[0][0].id, 'e11');
      expect(europa.rounds[2][0].id, 'e31');
    });
  });

  group('Conference', () {
    test('instantiate creates correct structure', () {
      final conference = Conference();
      conference.instantiate();

      expect(conference.rounds.length, 3);
      expect(conference.rounds[0].length, 4);
      expect(conference.rounds[1].length, 2);
      expect(conference.rounds[2].length, 1);
    });

    test('instantiate assigns correct match IDs', () {
      final conference = Conference();
      conference.instantiate();

      expect(conference.rounds[0][0].id, 'f11');
      expect(conference.rounds[2][0].id, 'f31');
    });
  });

  group('Super', () {
    test('instantiate creates correct structure', () {
      final superCup = Super();
      superCup.instantiate();

      expect(superCup.matches.length, 2);
    });

    test('instantiate assigns correct match IDs', () {
      final superCup = Super();
      superCup.instantiate();

      expect(superCup.matches[0].id, 's1');
      expect(superCup.matches[1].id, 's2');
    });
  });

  group('Knockouts', () {
    test('creates knockouts with empty structures', () {
      final knockouts = Knockouts();
      expect(knockouts.champions.rounds, isEmpty);
      expect(knockouts.europa.rounds, isEmpty);
      expect(knockouts.conference.rounds, isEmpty);
      expect(knockouts.superCup.matches, isEmpty);
    });

    test('instantiate creates all structures', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      expect(knockouts.champions.rounds.length, 4);
      expect(knockouts.europa.rounds.length, 3);
      expect(knockouts.conference.rounds.length, 3);
      expect(knockouts.superCup.matches.length, 2);
    });
  });

  group('updateMatchScore', () {
    test('updates match in champions league', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      final updated = knockouts.updateMatchScore('c11', 10, 5);

      expect(updated, true);
      expect(knockouts.champions.rounds[0][0].score1, 10);
      expect(knockouts.champions.rounds[0][0].score2, 5);
      expect(knockouts.champions.rounds[0][0].done, true);
    });

    test('updates match in europa league', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      final updated = knockouts.updateMatchScore('e21', 16, 15);

      expect(updated, true);
      expect(knockouts.europa.rounds[1][0].score1, 16);
      expect(knockouts.europa.rounds[1][0].score2, 15);
      expect(knockouts.europa.rounds[1][0].done, true);
    });

    test('updates match in conference league', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      final updated = knockouts.updateMatchScore('f11', 10, 5);

      expect(updated, true);
      expect(knockouts.conference.rounds[0][0].score1, 10);
      expect(knockouts.conference.rounds[0][0].score2, 5);
      expect(knockouts.conference.rounds[0][0].done, true);
    });

    test('updates match in super cup', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      final updated = knockouts.updateMatchScore('s1', 10, 5);

      expect(updated, true);
      expect(knockouts.superCup.matches[0].score1, 10);
      expect(knockouts.superCup.matches[0].score2, 5);
      expect(knockouts.superCup.matches[0].done, true);
    });

    test('returns false for non-existent match', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      final updated = knockouts.updateMatchScore('invalid', 10, 5);

      expect(updated, false);
    });
  });

  group('update', () {
    test('moves winner to next round in champions league', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].score1 = 10;
      knockouts.champions.rounds[0][0].score2 = 5;
      knockouts.champions.rounds[0][0].done = true;

      knockouts.update();

      // Winner should be in next round
      expect(knockouts.champions.rounds[1][0].teamId1, 't1');
    });

    test('advances winners through multiple rounds', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      // Set up and finish first round matches
      for (int i = 0; i < 8; i++) {
        knockouts.champions.rounds[0][i].teamId1 = 't${i * 2}';
        knockouts.champions.rounds[0][i].teamId2 = 't${i * 2 + 1}';
        knockouts.champions.rounds[0][i].score1 = 10;
        knockouts.champions.rounds[0][i].score2 = 5;
        knockouts.champions.rounds[0][i].done = true;
      }

      knockouts.update();

      // Check quarter finals are populated
      for (int i = 0; i < 4; i++) {
        expect(knockouts.champions.rounds[1][i].teamId1.isNotEmpty, true);
      }
    });

    test('does not advance losers', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].score1 = 5;
      knockouts.champions.rounds[0][0].score2 = 10;
      knockouts.champions.rounds[0][0].done = true;

      knockouts.update();

      // Winner (t2) should be in next round, not t1
      expect(knockouts.champions.rounds[1][0].teamId1, 't2');
    });

    test('skips unfinished matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].done = false;

      knockouts.update();

      expect(knockouts.champions.rounds[1][0].teamId1, '');
    });

    test('moves europa and conference winners to super cup', () {
      final knockouts = Knockouts();
      knockouts.instantiate();

      // Need at least one team in champions to pass the early return check
      knockouts.champions.rounds[0][0].teamId1 = 'champTeam1';
      knockouts.champions.rounds[0][0].teamId2 = 'champTeam2';

      // Finish europa final
      knockouts.europa.rounds[2][0].teamId1 = 'europaWinner';
      knockouts.europa.rounds[2][0].teamId2 = 'europaLoser';
      knockouts.europa.rounds[2][0].score1 = 10;
      knockouts.europa.rounds[2][0].score2 = 5;
      knockouts.europa.rounds[2][0].done = true;

      // Finish conference final
      knockouts.conference.rounds[2][0].teamId1 = 'confWinner';
      knockouts.conference.rounds[2][0].teamId2 = 'confLoser';
      knockouts.conference.rounds[2][0].score1 = 10;
      knockouts.conference.rounds[2][0].score2 = 5;
      knockouts.conference.rounds[2][0].done = true;

      knockouts.update();

      // Check that both winners are placed in super cup
      final firstMatch = knockouts.superCup.matches[0];
      final teams = {firstMatch.teamId1, firstMatch.teamId2};

      expect(teams.contains('europaWinner'), true);
      expect(teams.contains('confWinner'), true);
    });
  });

  group('clearDependentMatches', () {
    Knockouts makePopulatedKnockouts() {
      final knockouts = Knockouts();
      knockouts.instantiate();

      // Populate champions round 1 with team IDs
      for (int i = 0; i < 8; i++) {
        knockouts.champions.rounds[0][i].teamId1 = 'c1_${i}_a';
        knockouts.champions.rounds[0][i].teamId2 = 'c1_${i}_b';
        knockouts.champions.rounds[0][i].score1 = 10;
        knockouts.champions.rounds[0][i].score2 = 5;
        knockouts.champions.rounds[0][i].done = true;
      }
      // Populate champions round 2
      for (int i = 0; i < 4; i++) {
        knockouts.champions.rounds[1][i].teamId1 = 'c2_${i}_a';
        knockouts.champions.rounds[1][i].teamId2 = 'c2_${i}_b';
        knockouts.champions.rounds[1][i].score1 = 10;
        knockouts.champions.rounds[1][i].score2 = 5;
        knockouts.champions.rounds[1][i].done = true;
      }
      // Populate champions semi-finals
      for (int i = 0; i < 2; i++) {
        knockouts.champions.rounds[2][i].teamId1 = 'c3_${i}_a';
        knockouts.champions.rounds[2][i].teamId2 = 'c3_${i}_b';
        knockouts.champions.rounds[2][i].score1 = 10;
        knockouts.champions.rounds[2][i].score2 = 5;
        knockouts.champions.rounds[2][i].done = true;
      }
      // Populate champions final
      knockouts.champions.rounds[3][0].teamId1 = 'champFinalA';
      knockouts.champions.rounds[3][0].teamId2 = 'champFinalB';
      knockouts.champions.rounds[3][0].score1 = 10;
      knockouts.champions.rounds[3][0].score2 = 5;
      knockouts.champions.rounds[3][0].done = true;

      // Populate europa rounds
      for (int i = 0; i < 4; i++) {
        knockouts.europa.rounds[0][i].teamId1 = 'e1_${i}_a';
        knockouts.europa.rounds[0][i].teamId2 = 'e1_${i}_b';
        knockouts.europa.rounds[0][i].score1 = 10;
        knockouts.europa.rounds[0][i].score2 = 5;
        knockouts.europa.rounds[0][i].done = true;
      }
      for (int i = 0; i < 2; i++) {
        knockouts.europa.rounds[1][i].teamId1 = 'e2_${i}_a';
        knockouts.europa.rounds[1][i].teamId2 = 'e2_${i}_b';
        knockouts.europa.rounds[1][i].score1 = 10;
        knockouts.europa.rounds[1][i].score2 = 5;
        knockouts.europa.rounds[1][i].done = true;
      }
      knockouts.europa.rounds[2][0].teamId1 = 'euroFinalA';
      knockouts.europa.rounds[2][0].teamId2 = 'euroFinalB';
      knockouts.europa.rounds[2][0].score1 = 10;
      knockouts.europa.rounds[2][0].score2 = 5;
      knockouts.europa.rounds[2][0].done = true;

      // Populate conference rounds
      for (int i = 0; i < 4; i++) {
        knockouts.conference.rounds[0][i].teamId1 = 'f1_${i}_a';
        knockouts.conference.rounds[0][i].teamId2 = 'f1_${i}_b';
        knockouts.conference.rounds[0][i].score1 = 10;
        knockouts.conference.rounds[0][i].score2 = 5;
        knockouts.conference.rounds[0][i].done = true;
      }
      for (int i = 0; i < 2; i++) {
        knockouts.conference.rounds[1][i].teamId1 = 'f2_${i}_a';
        knockouts.conference.rounds[1][i].teamId2 = 'f2_${i}_b';
        knockouts.conference.rounds[1][i].score1 = 10;
        knockouts.conference.rounds[1][i].score2 = 5;
        knockouts.conference.rounds[1][i].done = true;
      }
      knockouts.conference.rounds[2][0].teamId1 = 'confFinalA';
      knockouts.conference.rounds[2][0].teamId2 = 'confFinalB';
      knockouts.conference.rounds[2][0].score1 = 10;
      knockouts.conference.rounds[2][0].score2 = 5;
      knockouts.conference.rounds[2][0].done = true;

      // Populate super cup
      knockouts.superCup.matches[0].teamId1 = 'superA';
      knockouts.superCup.matches[0].teamId2 = 'superB';
      knockouts.superCup.matches[0].score1 = 10;
      knockouts.superCup.matches[0].score2 = 5;
      knockouts.superCup.matches[0].done = true;

      knockouts.superCup.matches[1].teamId1 = 'superC';
      knockouts.superCup.matches[1].teamId2 = 'superD';
      knockouts.superCup.matches[1].score1 = 10;
      knockouts.superCup.matches[1].score2 = 5;
      knockouts.superCup.matches[1].done = true;

      return knockouts;
    }

    test('clears subsequent champions rounds when early round match edited',
        () {
      final knockouts = makePopulatedKnockouts();
      // Edit a round 1 champions match → rounds 2,3,4 should be cleared
      final cleared = knockouts.clearDependentMatches('c11');

      // Rounds 2-4 all get cleared
      for (int r = 1; r < knockouts.champions.rounds.length; r++) {
        for (var match in knockouts.champions.rounds[r]) {
          expect(match.teamId1, isEmpty);
          expect(match.teamId2, isEmpty);
          expect(match.done, isFalse);
        }
      }
      expect(cleared, isNotEmpty);
    });

    test('champions final change clears super cup match 2', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('c41');

      // Super cup match 2 should be cleared (champions winner feeds it)
      expect(knockouts.superCup.matches[1].teamId1, isEmpty);
      expect(knockouts.superCup.matches[1].teamId2, isEmpty);
      expect(knockouts.superCup.matches[1].done, isFalse);
      expect(cleared, contains('s2'));
    });

    test('europa final change clears both super cup matches', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('e31');

      // Europa final winner feeds super cup match 1
      expect(knockouts.superCup.matches[0].teamId1, isEmpty);
      expect(knockouts.superCup.matches[0].done, isFalse);
      // Super cup match 2 also cleared (cascade)
      expect(knockouts.superCup.matches[1].teamId1, isEmpty);
      expect(knockouts.superCup.matches[1].done, isFalse);
      expect(cleared, contains('s1'));
      expect(cleared, contains('s2'));
    });

    test('conference final change clears both super cup matches', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('f31');

      expect(knockouts.superCup.matches[0].teamId1, isEmpty);
      expect(knockouts.superCup.matches[0].done, isFalse);
      expect(knockouts.superCup.matches[1].teamId1, isEmpty);
      expect(knockouts.superCup.matches[1].done, isFalse);
      expect(cleared, contains('s1'));
      expect(cleared, contains('s2'));
    });

    test('europa early round clears subsequent europa rounds and super cup',
        () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('e11');

      // Europa rounds 2-3 should be cleared
      for (int r = 1; r < knockouts.europa.rounds.length; r++) {
        for (var match in knockouts.europa.rounds[r]) {
          expect(match.teamId1, isEmpty);
          expect(match.teamId2, isEmpty);
          expect(match.done, isFalse);
        }
      }
      expect(cleared, isNotEmpty);
    });

    test('super cup match 1 clears super cup match 2', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('s1');

      expect(knockouts.superCup.matches[1].teamId1, isEmpty);
      expect(knockouts.superCup.matches[1].teamId2, isEmpty);
      expect(knockouts.superCup.matches[1].done, isFalse);
      expect(cleared, contains('s2'));
    });

    test('super cup match 2 clears nothing', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('s2');

      expect(cleared, isEmpty);
      // Super cup match 1 should be untouched
      expect(knockouts.superCup.matches[0].teamId1, 'superA');
      expect(knockouts.superCup.matches[0].done, isTrue);
    });

    test('non-existent match ID returns empty list', () {
      final knockouts = makePopulatedKnockouts();
      final cleared = knockouts.clearDependentMatches('nonexistent');
      expect(cleared, isEmpty);
    });

    test('clearing already empty dependent matches returns empty list', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      // Only populate round 1 match, leave rest empty
      knockouts.champions.rounds[0][0].teamId1 = 'a';
      knockouts.champions.rounds[0][0].teamId2 = 'b';
      knockouts.champions.rounds[0][0].done = true;

      final cleared = knockouts.clearDependentMatches('c11');
      // Subsequent rounds are already empty, so nothing should be in cleared list
      expect(cleared, isEmpty);
    });
  });

  group('mapTables', () {
    test('assigns table numbers to all matches', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Check champions league tables
      for (var round in knockouts.champions.rounds) {
        for (var match in round) {
          expect(match.tischNr, greaterThan(0));
          expect(match.tischNr, lessThanOrEqualTo(6));
        }
      }

      // Check europa league tables
      for (var round in knockouts.europa.rounds) {
        for (var match in round) {
          expect(match.tischNr, greaterThan(0));
          expect(match.tischNr, lessThanOrEqualTo(6));
        }
      }

      // Check conference league tables
      for (var round in knockouts.conference.rounds) {
        for (var match in round) {
          expect(match.tischNr, greaterThan(0));
          expect(match.tischNr, lessThanOrEqualTo(6));
        }
      }

      // Check super cup tables
      for (var match in knockouts.superCup.matches) {
        expect(match.tischNr, greaterThan(0));
        expect(match.tischNr, lessThanOrEqualTo(6));
      }
    });
  });

  group('JSON serialization', () {
    test('round trip serialization preserves data', () {
      final knockouts = Knockouts();
      knockouts.instantiate();
      mapTables(knockouts);

      // Add some match data
      knockouts.champions.rounds[0][0].teamId1 = 't1';
      knockouts.champions.rounds[0][0].teamId2 = 't2';
      knockouts.champions.rounds[0][0].score1 = 10;
      knockouts.champions.rounds[0][0].score2 = 5;
      knockouts.champions.rounds[0][0].done = true;

      final json = knockouts.toJson();
      final restored = Knockouts.fromJson(json);

      expect(restored.champions.rounds[0][0].teamId1, 't1');
      expect(restored.champions.rounds[0][0].teamId2, 't2');
      expect(restored.champions.rounds[0][0].score1, 10);
      expect(restored.champions.rounds[0][0].score2, 5);
      expect(restored.champions.rounds[0][0].done, true);
    });
  });
}
