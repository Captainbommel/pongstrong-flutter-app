import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/models/team.dart';
import 'package:pongstrong/views/admin/teams_management/team_edit_controller.dart';

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
      expect(c.memberControllers.length, Team.defaultMemberCount);
      for (final mc in c.memberControllers) {
        expect(mc.text, isEmpty);
      }
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

    test('constructor populates text controllers from members list', () {
      final c = TeamEditController(
        id: 'team_42',
        name: 'Eagles',
        members: ['Alice', 'Bob'],
        groupIndex: 2,
        isNew: false,
      );
      expect(c.id, 'team_42');
      expect(c.nameController.text, 'Eagles');
      expect(c.memberControllers[0].text, 'Alice');
      expect(c.memberControllers[1].text, 'Bob');
      expect(c.groupIndex, 2);
      expect(c.isNew, isFalse);
      c.dispose();
    });

    test('members list with 3 entries creates 3 controllers', () {
      final c = TeamEditController(
        name: 'Trio',
        members: ['Alice', 'Bob', 'Charlie'],
      );
      expect(c.memberControllers.length, 3);
      expect(c.memberControllers[2].text, 'Charlie');
      c.dispose();
    });

    test('addMemberField adds up to Team.maxMembers', () {
      final c = TeamEditController();
      expect(c.memberControllers.length, Team.defaultMemberCount);
      expect(c.canAddMember, isTrue);
      c.addMemberField();
      expect(c.memberControllers.length, Team.maxMembers);
      expect(c.canAddMember, isFalse);
      expect(c.addMemberField(), isFalse);
      c.dispose();
    });

    test('removeMemberField removes down to Team.defaultMemberCount', () {
      final c = TeamEditController(members: ['A', 'B', 'C']);
      expect(c.canRemoveMember, isTrue);
      c.removeMemberField();
      expect(c.memberControllers.length, Team.defaultMemberCount);
      expect(c.canRemoveMember, isFalse);
      expect(c.removeMemberField(), isFalse);
      c.dispose();
    });

    test('membersText joins non-empty member names', () {
      final c = TeamEditController(members: ['Alice', '', 'Charlie']);
      expect(c.membersText, 'Alice & Charlie');
      c.dispose();
    });

    test('memberValues returns trimmed list', () {
      final c = TeamEditController(members: ['Alice', 'Bob']);
      expect(c.memberValues, ['Alice', 'Bob']);
      c.dispose();
    });

    test('dispose does not throw', () {
      final c = TeamEditController(name: 'Test');
      expect(() => c.dispose(), returnsNormally);
    });
  });
}
