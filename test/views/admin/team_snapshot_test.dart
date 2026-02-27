import 'package:flutter_test/flutter_test.dart';
import 'package:pongstrong/views/admin/team_edit_controller.dart';
import 'package:pongstrong/views/admin/team_snapshot.dart';

void main() {
  // =========================================================================
  // TeamSnapshot.listEquals
  // =========================================================================
  group('TeamSnapshot.listEquals', () {
    test('empty lists are equal', () {
      expect(TeamSnapshot.listEquals([], []), isTrue);
    });

    test('identical content is equal', () {
      expect(TeamSnapshot.listEquals(['a', 'b'], ['a', 'b']), isTrue);
    });

    test('different lengths are not equal', () {
      expect(TeamSnapshot.listEquals(['a'], ['a', 'b']), isFalse);
    });

    test('different content is not equal', () {
      expect(TeamSnapshot.listEquals(['a', 'b'], ['a', 'c']), isFalse);
    });

    test('order matters', () {
      expect(TeamSnapshot.listEquals(['a', 'b'], ['b', 'a']), isFalse);
    });
  });

  // =========================================================================
  // TeamSnapshot constructor & fromController
  // =========================================================================
  group('TeamSnapshot.fromController', () {
    test('captures name, members, group, reserve from controller', () {
      final c = TeamEditController(
        id: 'team1',
        name: 'Eagles',
        members: ['Alice', 'Bob'],
        groupIndex: 2,
        isReserve: true,
      );

      final snap = TeamSnapshot.fromController(c);

      expect(snap.id, 'team1');
      expect(snap.name, 'Eagles');
      expect(snap.members, ['Alice', 'Bob']);
      expect(snap.groupIndex, 2);
      expect(snap.isReserve, isTrue);

      c.dispose();
    });

    test('trims name whitespace', () {
      final c = TeamEditController(name: '  Falcons  ');
      final snap = TeamSnapshot.fromController(c);
      expect(snap.name, 'Falcons');
      c.dispose();
    });

    test('captures empty controller correctly', () {
      final c = TeamEditController();
      final snap = TeamSnapshot.fromController(c);

      expect(snap.id, isNull);
      expect(snap.name, isEmpty);
      // Default member count produces empty strings
      expect(snap.members, ['', '']);
      expect(snap.groupIndex, isNull);
      expect(snap.isReserve, isFalse);

      c.dispose();
    });

    test('captures 3 members when all filled', () {
      final c = TeamEditController(
        name: 'Trio',
        members: ['A', 'B', 'C'],
      );
      final snap = TeamSnapshot.fromController(c);
      expect(snap.members, ['A', 'B', 'C']);
      c.dispose();
    });

    test('reflects live controller state after mutation', () {
      final c = TeamEditController(
        id: 'x',
        name: 'Before',
        members: ['M1', 'M2'],
        groupIndex: 0,
      );

      // Mutate the controller
      c.nameController.text = 'After';
      c.memberControllers[0].text = 'Changed';
      c.groupIndex = 3;
      c.isReserve = true;

      final snap = TeamSnapshot.fromController(c);
      expect(snap.name, 'After');
      expect(snap.members[0], 'Changed');
      expect(snap.groupIndex, 3);
      expect(snap.isReserve, isTrue);

      c.dispose();
    });
  });

  // =========================================================================
  // TeamSnapshot.dataEquals
  // =========================================================================
  group('TeamSnapshot.dataEquals', () {
    TeamSnapshot makeSnap({
      String? id,
      String name = 'Team',
      List<String> members = const ['A', 'B'],
      int? groupIndex,
      bool isReserve = false,
    }) {
      return TeamSnapshot(
        id: id,
        name: name,
        members: members,
        groupIndex: groupIndex,
        isReserve: isReserve,
      );
    }

    test('identical snapshots are equal', () {
      final a = makeSnap(id: '1', groupIndex: 0);
      final b = makeSnap(id: '1', groupIndex: 0);
      expect(a.dataEquals(b), isTrue);
    });

    test('id is NOT compared (only data fields matter)', () {
      final a = makeSnap(id: '1');
      final b = makeSnap(id: '2');
      expect(a.dataEquals(b), isTrue);
    });

    test('different name → not equal', () {
      final a = makeSnap(name: 'Alpha');
      final b = makeSnap(name: 'Beta');
      expect(a.dataEquals(b), isFalse);
    });

    test('different members → not equal', () {
      final a = makeSnap(members: ['A', 'B']);
      final b = makeSnap(members: ['A', 'C']);
      expect(a.dataEquals(b), isFalse);
    });

    test('different member count → not equal', () {
      final a = makeSnap(members: ['A', 'B']);
      final b = makeSnap(members: ['A', 'B', 'C']);
      expect(a.dataEquals(b), isFalse);
    });

    test('different groupIndex → not equal', () {
      final a = makeSnap(groupIndex: 0);
      final b = makeSnap(groupIndex: 1);
      expect(a.dataEquals(b), isFalse);
    });

    test('null vs non-null groupIndex → not equal', () {
      final a = makeSnap();
      final b = makeSnap(groupIndex: 0);
      expect(a.dataEquals(b), isFalse);
    });

    test('different isReserve → not equal', () {
      final a = makeSnap();
      final b = makeSnap(isReserve: true);
      expect(a.dataEquals(b), isFalse);
    });

    test('all fields differ → not equal', () {
      final a = makeSnap(name: 'X', members: ['1'], groupIndex: 0);
      final b = makeSnap(
          name: 'Y', members: ['2', '3'], groupIndex: 1, isReserve: true);
      expect(a.dataEquals(b), isFalse);
    });
  });

  // =========================================================================
  // Snapshot-based unsaved-changes detection (integration-style)
  // =========================================================================
  group('Snapshot diff detection', () {
    /// Simulates the page's snapshot/diff workflow:
    /// 1. Create controllers, take snapshots
    /// 2. Mutate, then check if changes are detected
    test('no mutation → no unsaved changes', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'A', members: ['M1', 'M2']),
        TeamEditController(id: 't2', name: 'B', members: ['M3', 'M4']),
      ];
      final snapshots = _takeSnapshots(controllers);

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isFalse);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('name change → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'Original', members: ['M1', 'M2']),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].nameController.text = 'Changed';

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('member change → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'T', members: ['A', 'B']),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].memberControllers[1].text = 'Z';

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('group change → detected', () {
      final controllers = [
        TeamEditController(
            id: 't1', name: 'T', members: ['A', 'B'], groupIndex: 0),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].groupIndex = 1;

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('reserve toggle → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'T', members: ['A', 'B']),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].isReserve = true;

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('adding a member field → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'T', members: ['A', 'B']),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].addMemberField();
      // Adding an empty 3rd slot changes memberValues length
      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('revert to original values → no unsaved changes', () {
      final controllers = [
        TeamEditController(
            id: 't1', name: 'Team', members: ['A', 'B'], groupIndex: 0),
      ];
      final snapshots = _takeSnapshots(controllers);

      // Mutate
      controllers[0].nameController.text = 'Changed';
      controllers[0].groupIndex = 2;
      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      // Revert
      controllers[0].nameController.text = 'Team';
      controllers[0].groupIndex = 0;
      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isFalse);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('marking existing team for removal → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'T', members: ['A', 'B']),
      ];
      final snapshots = _takeSnapshots(controllers);

      controllers[0].markedForRemoval = true;

      expect(_hasUnsavedChanges(controllers, snapshots, 24, 24), isTrue);

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('target team count change → detected', () {
      final controllers = <TeamEditController>[];
      final snapshots = _takeSnapshots(controllers);

      expect(_hasUnsavedChanges(controllers, snapshots, 16, 24), isTrue);
    });

    test('new team with content → detected', () {
      final controllers = [
        TeamEditController(id: 't1', name: 'Existing', members: ['A', 'B']),
      ];
      final snapshots = _takeSnapshots(controllers);
      final originalNewControllers = <TeamEditController>{};

      // Add a new controller (simulating user adding a team)
      final newCtrl = TeamEditController();
      newCtrl.nameController.text = 'Newcomer';
      controllers.add(newCtrl);

      expect(
        _hasUnsavedChangesWithNew(
            controllers, snapshots, originalNewControllers, 24, 24),
        isTrue,
      );

      for (final c in controllers) {
        c.dispose();
      }
    });

    test('new empty team (no name) → no unsaved changes', () {
      final controllers = <TeamEditController>[];
      final snapshots = _takeSnapshots(controllers);

      // Add a new controller with no content — should not trigger changes
      final newCtrl = TeamEditController();
      final originalNewControllers = <TeamEditController>{newCtrl};
      controllers.add(newCtrl);

      expect(
        _hasUnsavedChangesWithNew(
            controllers, snapshots, originalNewControllers, 24, 24),
        isFalse,
      );

      for (final c in controllers) {
        c.dispose();
      }
    });
  });

  // =========================================================================
  // Diff-based save: which teams need updating?
  // =========================================================================
  group('Diff-based save decisions', () {
    test('unchanged team is skipped', () {
      final c = TeamEditController(
          id: 't1', name: 'T', members: ['A', 'B'], groupIndex: 0);
      final snap = TeamSnapshot.fromController(c);
      final current = TeamSnapshot.fromController(c);

      expect(current.dataEquals(snap), isTrue);

      c.dispose();
    });

    test('only group changed — name/members update is skipped', () {
      final c = TeamEditController(
          id: 't1', name: 'T', members: ['A', 'B'], groupIndex: 0);
      final original = TeamSnapshot.fromController(c);

      c.groupIndex = 2;
      final current = TeamSnapshot.fromController(c);

      // Full diff detects a change
      expect(current.dataEquals(original), isFalse);
      // But name/members haven't changed
      expect(current.name == original.name, isTrue);
      expect(
          TeamSnapshot.listEquals(current.members, original.members), isTrue);

      c.dispose();
    });

    test('only name changed — group update is skipped', () {
      final c = TeamEditController(
          id: 't1', name: 'Old', members: ['A', 'B'], groupIndex: 1);
      final original = TeamSnapshot.fromController(c);

      c.nameController.text = 'New';
      final current = TeamSnapshot.fromController(c);

      expect(current.dataEquals(original), isFalse);
      expect(current.groupIndex == original.groupIndex, isTrue);

      c.dispose();
    });

    test('only members changed — group update is skipped', () {
      final c = TeamEditController(
          id: 't1', name: 'T', members: ['A', 'B'], groupIndex: 1);
      final original = TeamSnapshot.fromController(c);

      c.memberControllers[0].text = 'X';
      final current = TeamSnapshot.fromController(c);

      expect(current.dataEquals(original), isFalse);
      expect(current.groupIndex == original.groupIndex, isTrue);
      expect(current.name == original.name, isTrue);

      c.dispose();
    });

    test('name AND group changed — both need updating', () {
      final c = TeamEditController(
          id: 't1', name: 'Old', members: ['A', 'B'], groupIndex: 0);
      final original = TeamSnapshot.fromController(c);

      c.nameController.text = 'New';
      c.groupIndex = 2;
      final current = TeamSnapshot.fromController(c);

      expect(current.dataEquals(original), isFalse);
      expect(current.name != original.name, isTrue);
      expect(current.groupIndex != original.groupIndex, isTrue);

      c.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers – mirror the page's snapshot/diff logic for testability
// ---------------------------------------------------------------------------

/// Takes snapshots of existing controllers (those with an id).
Map<String, TeamSnapshot> _takeSnapshots(List<TeamEditController> controllers) {
  final map = <String, TeamSnapshot>{};
  for (final c in controllers) {
    if (c.markedForRemoval) continue;
    if (c.id != null) {
      map[c.id!] = TeamSnapshot.fromController(c);
    }
  }
  return map;
}

/// Simplified version of the page's _hasUnsavedChanges getter.
bool _hasUnsavedChanges(
  List<TeamEditController> controllers,
  Map<String, TeamSnapshot> originalSnapshots,
  int targetTeamCount,
  int originalTargetTeamCount,
) {
  return _hasUnsavedChangesWithNew(controllers, originalSnapshots, {},
      targetTeamCount, originalTargetTeamCount);
}

/// Full version including new-controller tracking.
bool _hasUnsavedChangesWithNew(
  List<TeamEditController> controllers,
  Map<String, TeamSnapshot> originalSnapshots,
  Set<TeamEditController> originalNewControllers,
  int targetTeamCount,
  int originalTargetTeamCount,
) {
  if (targetTeamCount != originalTargetTeamCount) return true;

  // Check for deletions of existing teams
  final currentExistingIds = controllers
      .where((c) => !c.markedForRemoval && c.id != null)
      .map((c) => c.id!)
      .toSet();
  for (final origId in originalSnapshots.keys) {
    if (!currentExistingIds.contains(origId)) return true;
  }

  // Check for new teams with content
  for (final c in controllers) {
    if (c.markedForRemoval) continue;
    if (c.id == null && !originalNewControllers.contains(c)) {
      if (c.nameController.text.trim().isNotEmpty) return true;
    }
  }

  // Check each existing team for data changes
  for (final c in controllers) {
    if (c.markedForRemoval) {
      if (c.id != null && originalSnapshots.containsKey(c.id)) return true;
      continue;
    }
    if (c.id != null && originalSnapshots.containsKey(c.id)) {
      final snap = TeamSnapshot.fromController(c);
      if (!snap.dataEquals(originalSnapshots[c.id!]!)) return true;
    }
  }

  return false;
}
