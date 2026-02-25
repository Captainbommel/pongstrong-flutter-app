import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/views/admin/team_edit_controller.dart';

void main() {
  group('TeamEditController', () {
    test('defaults: isReserve false, isNew true, markedForRemoval false', () {
      final c = TeamEditController();
      expect(c.isReserve, isFalse);
      expect(c.isNew, isTrue);
      expect(c.markedForRemoval, isFalse);
      expect(c.id, isNull);
      expect(c.groupIndex, isNull);
      expect(c.nameController.text, isEmpty);
      expect(c.member1Controller.text, isEmpty);
      expect(c.member2Controller.text, isEmpty);
      c.dispose();
    });

    test('isReserve can be set via constructor', () {
      final c = TeamEditController(isReserve: true);
      expect(c.isReserve, isTrue);
      c.dispose();
    });

    test('isReserve can be toggled after construction', () {
      final c = TeamEditController();
      expect(c.isReserve, isFalse);
      c.isReserve = true;
      expect(c.isReserve, isTrue);
      c.isReserve = false;
      expect(c.isReserve, isFalse);
      c.dispose();
    });

    test('constructor populates text controllers from parameters', () {
      final c = TeamEditController(
        id: 'team_42',
        name: 'Eagles',
        member1: 'Alice',
        member2: 'Bob',
        groupIndex: 2,
        isNew: false,
      );
      expect(c.id, 'team_42');
      expect(c.nameController.text, 'Eagles');
      expect(c.member1Controller.text, 'Alice');
      expect(c.member2Controller.text, 'Bob');
      expect(c.groupIndex, 2);
      expect(c.isNew, isFalse);
      c.dispose();
    });

    test('dispose does not throw', () {
      final c = TeamEditController(name: 'Test');
      expect(() => c.dispose(), returnsNormally);
    });
  });
}
