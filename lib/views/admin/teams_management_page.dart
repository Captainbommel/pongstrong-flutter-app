import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pongstrong/models/team.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/views/admin/team_edit_controller.dart';
import 'package:pongstrong/views/admin/team_snapshot.dart';
import 'package:provider/provider.dart';

/// A dedicated page for managing teams and group assignments
/// Provides inline editing for better UX
class TeamsManagementPage extends StatefulWidget {
  final AdminPanelState adminState;

  const TeamsManagementPage({
    super.key,
    required this.adminState,
  });

  @override
  State<TeamsManagementPage> createState() => _TeamsManagementPageState();
}

class _TeamsManagementPageState extends State<TeamsManagementPage> {
  final List<TeamEditController> _teamControllers = [];
  int _targetTeamCount = 24;
  int _numberOfGroups = 6;
  bool _isSaving = false;
  bool _showSaveSuccess = false;
  Timer? _saveSuccessTimer;

  /// Snapshots taken right after loading / saving, keyed by team id.
  /// New (unsaved) controllers are tracked by object identity in [_originalNewControllers].
  Map<String, TeamSnapshot> _originalSnapshots = {};

  /// Set of controller refs that existed as empty/new slots at snapshot time.
  Set<TeamEditController> _originalNewControllers = {};
  int _originalTargetTeamCount = 0;
  int _originalNumberOfGroups = 0;

  /// Original order of existing team IDs (active first, reserve last).
  List<String> _originalTeamOrder = [];

  /// Whether the current controller state differs from the last snapshot.
  bool get _hasUnsavedChanges {
    if (_targetTeamCount != _originalTargetTeamCount) return true;
    if (_numberOfGroups != _originalNumberOfGroups) return true;

    // Check for deletions of existing teams
    final currentExistingIds = _teamControllers
        .where((c) => !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toSet();
    for (final origId in _originalSnapshots.keys) {
      if (!currentExistingIds.contains(origId)) return true;
    }

    // Check for new teams with content
    for (final c in _teamControllers) {
      if (c.markedForRemoval) continue;
      if (c.id == null && !_originalNewControllers.contains(c)) {
        if (c.nameController.text.trim().isNotEmpty) return true;
      }
    }

    // Check for order changes among existing teams
    final currentOrder = _teamControllers
        .where((c) => !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toList();
    if (!TeamSnapshot.listEquals(currentOrder, _originalTeamOrder)) return true;

    // Check each existing team for data changes
    for (final c in _teamControllers) {
      if (c.markedForRemoval) {
        if (c.id != null && _originalSnapshots.containsKey(c.id)) return true;
        continue;
      }
      if (c.id != null && _originalSnapshots.containsKey(c.id)) {
        final snap = TeamSnapshot.fromController(c);
        if (!snap.dataEquals(_originalSnapshots[c.id!]!)) return true;
      }
    }

    return false;
  }

  /// Take a snapshot of the current state for future diffing.
  void _takeSnapshots() {
    _originalSnapshots = {};
    _originalNewControllers = {};
    _originalTargetTeamCount = _targetTeamCount;
    _originalNumberOfGroups = _numberOfGroups;
    _originalTeamOrder = [];
    for (final c in _teamControllers) {
      if (c.markedForRemoval) continue;
      if (c.id != null) {
        _originalSnapshots[c.id!] = TeamSnapshot.fromController(c);
        _originalTeamOrder.add(c.id!);
      } else {
        _originalNewControllers.add(c);
      }
    }
  }

  TournamentStyle get _style => widget.adminState.tournamentStyle;
  bool get _isGroupPhase => _style == TournamentStyle.groupsAndKnockouts;
  bool get _isKOOnly => _style == TournamentStyle.knockoutsOnly;
  bool get _isRoundRobin => _style == TournamentStyle.everyoneVsEveryone;

  /// Number of active (non-reserve) teams with data filled in
  int get _activeFilledCount => _teamControllers
      .where((c) =>
          !c.isReserve &&
          !c.markedForRemoval &&
          c.nameController.text.isNotEmpty)
      .length;

  /// Returns the allowed team counts for the dropdown based on tournament style
  List<int> get _allowedTeamCounts {
    switch (_style) {
      case TournamentStyle.groupsAndKnockouts:
        return [_numberOfGroups * 4];
      case TournamentStyle.knockoutsOnly:
        return [8, 16, 32, 64]; // powers of 2
      case TournamentStyle.everyoneVsEveryone:
        return List.generate(63, (i) => i + 2); // 2..64
    }
  }

  /// Safely clamp a group index: return null if it's out of range for the
  /// current number of groups, so the dropdown never receives a stale value.
  int? _clampedGroupIndex(int? index) {
    if (index == null) return null;
    if (index < 0 || index >= _numberOfGroups) return null;
    return index;
  }

  /// Returns a map from group index to the number of active teams assigned.
  Map<int, int> _groupCounts() {
    final counts = <int, int>{};
    for (final c in _teamControllers) {
      if (!c.isReserve && !c.markedForRemoval && c.groupIndex != null) {
        counts[c.groupIndex!] = (counts[c.groupIndex!] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers({
    int? preserveTargetCount,
    int? preserveGroupCount,
    Map<String, int?>? preserveGroupIndices,
  }) {
    for (final controller in _teamControllers) {
      controller.dispose();
    }
    _teamControllers.clear();

    // Restore or read group count from admin state
    _numberOfGroups = preserveGroupCount ?? widget.adminState.numberOfGroups;

    final maxGroupIndex = _numberOfGroups - 1;
    for (final team in widget.adminState.teams) {
      // Prefer preserved in-memory group index (post-save), fall back to admin state
      int? groupIndex;
      if (preserveGroupIndices != null &&
          preserveGroupIndices.containsKey(team.id)) {
        groupIndex = preserveGroupIndices[team.id];
      } else {
        final stateIndex = widget.adminState.getTeamGroupIndex(team.id);
        groupIndex = stateIndex >= 0 ? stateIndex : null;
      }
      // Clamp: ignore stale group indices that exceed current group count
      if (groupIndex != null && groupIndex > maxGroupIndex) {
        groupIndex = null;
      }
      _teamControllers.add(TeamEditController(
        id: team.id,
        name: team.name,
        members: [team.member1, team.member2, team.member3]
            .where((s) => s.isNotEmpty)
            .toList(),
        groupIndex: groupIndex,
        isNew: false,
      ));
    }

    if (_teamControllers.isNotEmpty) {
      // Priority: explicit caller value > admin state value > derive from team count
      final stateCount = widget.adminState.targetTeamCount;
      final validKo = [8, 16, 32, 64];
      if (preserveTargetCount != null &&
          (_isKOOnly
              ? validKo.contains(preserveTargetCount)
              : preserveTargetCount >= 2)) {
        // Post-save: restore the user's in-page selection
        _targetTeamCount = preserveTargetCount;
      } else if (_isGroupPhase) {
        // Groups+KO: target is always numberOfGroups * 4
        _targetTeamCount = _numberOfGroups * 4;
      } else if (_isKOOnly && validKo.contains(stateCount)) {
        // First open in KO-only: use the value already chosen in the admin panel
        _targetTeamCount = stateCount;
      } else if (_isRoundRobin && stateCount >= 2) {
        // First open in round-robin: same
        _targetTeamCount = stateCount;
      } else {
        _targetTeamCount = _teamControllers.length;
        // Snap KO-only count to nearest valid power of 2
        if (_isKOOnly && !validKo.contains(_targetTeamCount)) {
          final valid = [64, 32, 16, 8];
          _targetTeamCount = valid.firstWhere(
            (v) => v <= _teamControllers.length,
            orElse: () => 8,
          );
        }
      }
      // Apply active/reserve categorization instead of trimming.
      // Always use persisted reserve IDs when available so the bench
      // survives both page reloads and post-save re-initialization.
      _applyReserveMarking(usePersistedIds: true);
    } else {
      // No registered teams yet — seed with admin state count or mode default
      final stateCount = widget.adminState.targetTeamCount;
      if (_isGroupPhase) {
        _targetTeamCount = _numberOfGroups * 4;
      } else if (_isKOOnly) {
        _targetTeamCount =
            [8, 16, 32, 64].contains(stateCount) ? stateCount : 8;
      } else {
        _targetTeamCount = 8;
      }
      // In round-robin mode, don't pre-create empty slots
      if (!_isRoundRobin) {
        for (int i = 0; i < _targetTeamCount; i++) {
          _teamControllers.add(TeamEditController());
        }
      }
    }

    _takeSnapshots();
  }

  /// Categorize team controllers as active or reserve based on _targetTeamCount.
  /// In round-robin mode, all teams are active (no reserve concept).
  /// When persisted reserve IDs exist (from Firestore), those are used instead
  /// of position-based marking so that the bench survives page reloads.
  void _applyReserveMarking({bool usePersistedIds = false}) {
    if (_isRoundRobin) {
      for (final c in _teamControllers) {
        c.isReserve = false;
      }
      return;
    }

    final persistedReserveIds = widget.adminState.reserveTeamIds;

    // Use persisted IDs when caller requests it AND there are persisted IDs
    // that actually match current controllers (after a fresh import all IDs
    // are new, so stale persisted IDs must be ignored).
    final hasMatchingReserveIds = usePersistedIds &&
        persistedReserveIds.isNotEmpty &&
        _teamControllers
            .any((c) => c.id != null && persistedReserveIds.contains(c.id));

    if (hasMatchingReserveIds) {
      for (final c in _teamControllers) {
        if (c.markedForRemoval) continue;
        c.isReserve = c.id != null && persistedReserveIds.contains(c.id);
        if (c.isReserve && _isGroupPhase) c.groupIndex = null;
      }
      // After applying persisted IDs, pad active zone to _targetTeamCount
      final activeCount = _teamControllers
          .where((c) => !c.isReserve && !c.markedForRemoval)
          .length;
      for (int i = activeCount; i < _targetTeamCount; i++) {
        _teamControllers.add(TeamEditController());
      }
    } else {
      final filledCount = _teamControllers
          .where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty)
          .length;

      if (filledCount <= _targetTeamCount) {
        // All filled teams fit in active zone
        for (final c in _teamControllers) {
          c.isReserve = false;
        }
        // Trim excess empty slots that would overflow the active zone
        final nonRemoved =
            _teamControllers.where((c) => !c.markedForRemoval).length;
        if (nonRemoved > _targetTeamCount) {
          // Dispose & remove empty-unnamed controllers from the end
          int excess = nonRemoved - _targetTeamCount;
          for (int i = _teamControllers.length - 1; i >= 0 && excess > 0; i--) {
            final c = _teamControllers[i];
            if (!c.markedForRemoval &&
                c.nameController.text.isEmpty &&
                c.id == null) {
              c.dispose();
              _teamControllers.removeAt(i);
              excess--;
            }
          }
        }
        // Pad with empty slots if needed
        while (_teamControllers.where((c) => !c.markedForRemoval).length <
            _targetTeamCount) {
          _teamControllers.add(TeamEditController());
        }
      } else {
        // More teams than target: split into active + reserve
        int activeCount = 0;
        for (final c in _teamControllers) {
          if (c.markedForRemoval) continue;
          if (activeCount < _targetTeamCount) {
            c.isReserve = false;
            activeCount++;
          } else {
            c.isReserve = true;
            // Keep groupIndex so it survives bench transitions —
            // if the user increases group count again, the team
            // comes back with its old assignment intact.
          }
        }
      }
    }

    // Clamp stale group indices that exceed the current number of groups
    // (e.g. after switching from 10 → 9 groups).
    // Only clamp active teams — reserve teams keep their stale index so
    // it can be restored when the user increases groups again.
    if (_isGroupPhase) {
      final maxIndex = _numberOfGroups - 1;
      for (final c in _teamControllers) {
        if (!c.isReserve && c.groupIndex != null && c.groupIndex! > maxIndex) {
          c.groupIndex = null;
        }
      }
    }
  }

  /// Move a team from the active zone to the reserve (bench).
  void _moveToReserve(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.isReserve = true;
      controller.groupIndex = null;
    });
  }

  /// Promote a team from the reserve zone into the active tournament.
  void _promoteToActive(int index) {
    final controller = _teamControllers[index];
    final activeCount = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .length;

    if (activeCount >= _targetTeamCount) {
      // Try to replace an empty active slot
      final emptySlotIndex = _teamControllers.indexWhere((c) =>
          !c.isReserve &&
          !c.markedForRemoval &&
          c.nameController.text.isEmpty &&
          c.id == null);

      if (emptySlotIndex >= 0) {
        setState(() {
          final empty = _teamControllers.removeAt(emptySlotIndex);
          empty.dispose();
          controller.isReserve = false;
        });
        return;
      }

      SnackBarHelper.showWarning(context,
          'Kein Platz im Turnier. Verschiebe zuerst ein Team auf die Ersatzbank.');
      return;
    }

    setState(() {
      controller.isReserve = false;
    });
  }

  /// Update team slot count (for KO-only and Group+KO modes with fixed slots)
  void _updateTargetTeamCount(int count) {
    setState(() {
      _targetTeamCount = count;
      // Re-categorize controllers as active/reserve based on the new count
      _applyReserveMarking();
    });
  }

  /// Show a dialog to add a single team by name and members.
  /// In non-round-robin modes, the team is added to an empty active slot
  /// or placed on the bench if the active zone is full.
  Future<void> _showAddTeamDialog() async {
    final nameController = TextEditingController();
    final memberControllers = List.generate(
      Team.defaultMemberCount,
      (_) => TextEditingController(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Team hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Teamname *',
                    border: OutlineInputBorder(),
                  ),
                ),
                for (int i = 0; i < memberControllers.length; i++) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: memberControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Spieler ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (memberControllers.length > Team.defaultMemberCount)
                      IconButton(
                        onPressed: () => setDialogState(() {
                          memberControllers.last.dispose();
                          memberControllers.removeLast();
                        }),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                    const Spacer(),
                    if (memberControllers.length < Team.maxMembers)
                      IconButton(
                        onPressed: () => setDialogState(() {
                          memberControllers.add(TextEditingController());
                        }),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TreeColors.rebeccapurple,
                foregroundColor: AppColors.textOnColored,
              ),
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );

    // Capture values immediately; defer disposal so controllers are still
    // alive while the dialog exit animation is running.
    final name = nameController.text.trim();
    final memberValues = memberControllers.map((c) => c.text.trim()).toList();
    void disposeDialogControllers() {
      Future.delayed(const Duration(milliseconds: 300), () {
        nameController.dispose();
        for (final c in memberControllers) {
          c.dispose();
        }
      });
    }

    if (confirmed != true) {
      disposeDialogControllers();
      return;
    }

    if (name.isEmpty) {
      disposeDialogControllers();
      if (mounted) {
        SnackBarHelper.showWarning(context, 'Teamname darf nicht leer sein.');
      }
      return;
    }

    setState(() {
      if (_isRoundRobin) {
        // Round-robin: just append
        _teamControllers.add(TeamEditController(
          name: name,
          members: memberValues,
        ));
        _targetTeamCount =
            _teamControllers.where((c) => !c.markedForRemoval).length;
      } else {
        // Try to fill an empty active slot first
        final emptySlotIndex = _teamControllers.indexWhere((c) =>
            !c.isReserve &&
            !c.markedForRemoval &&
            c.nameController.text.isEmpty &&
            c.id == null);

        if (emptySlotIndex >= 0) {
          final slot = _teamControllers[emptySlotIndex];
          slot.nameController.text = name;
          for (int i = 0; i < slot.memberControllers.length; i++) {
            slot.memberControllers[i].text =
                i < memberValues.length ? memberValues[i] : '';
          }
          // Add extra controllers if the dialog had more members than the slot
          for (int i = slot.memberControllers.length;
              i < memberValues.length;
              i++) {
            if (memberValues[i].isNotEmpty) {
              slot.addMemberField();
              slot.memberControllers.last.text = memberValues[i];
            }
          }
        } else {
          // Active zone full — add to bench
          _teamControllers.add(TeamEditController(
            name: name,
            members: memberValues,
            isReserve: true,
          ));
        }
      }
    });

    disposeDialogControllers();
  }

  /// Show a dialog to edit an existing team's name and members.
  Future<void> _showEditTeamDialog(int index) async {
    final controller = _teamControllers[index];
    final nameCtrl =
        TextEditingController(text: controller.nameController.text);
    // Create dialog-local member controllers matching the current count
    final dialogMemberCtrls = controller.memberControllers
        .map((c) => TextEditingController(text: c.text))
        .toList();
    // Ensure at least defaultMemberCount fields
    while (dialogMemberCtrls.length < Team.defaultMemberCount) {
      dialogMemberCtrls.add(TextEditingController());
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Team bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Teamname *',
                    border: OutlineInputBorder(),
                  ),
                ),
                for (int i = 0; i < dialogMemberCtrls.length; i++) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: dialogMemberCtrls[i],
                    decoration: InputDecoration(
                      labelText: 'Spieler ${i + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (dialogMemberCtrls.length > Team.defaultMemberCount)
                      IconButton(
                        onPressed: () => setDialogState(() {
                          dialogMemberCtrls.last.dispose();
                          dialogMemberCtrls.removeLast();
                        }),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                    const Spacer(),
                    if (dialogMemberCtrls.length < Team.maxMembers)
                      IconButton(
                        onPressed: () => setDialogState(() {
                          dialogMemberCtrls.add(TextEditingController());
                        }),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: TreeColors.rebeccapurple,
                foregroundColor: AppColors.textOnColored,
              ),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );

    // Capture values immediately; defer disposal so controllers are still
    // alive while the dialog exit animation is running.
    final nameVal = nameCtrl.text.trim();
    final memberVals = dialogMemberCtrls.map((c) => c.text.trim()).toList();

    if (confirmed == true) {
      setState(() {
        controller.nameController.text = nameVal;
        // Sync member controllers: resize to match dialog result
        while (controller.memberControllers.length > memberVals.length) {
          controller.removeMemberField();
        }
        while (controller.memberControllers.length < memberVals.length) {
          controller.addMemberField();
        }
        for (int i = 0; i < memberVals.length; i++) {
          controller.memberControllers[i].text = memberVals[i];
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      nameCtrl.dispose();
      for (final c in dialogMemberCtrls) {
        c.dispose();
      }
    });
  }

  /// Remove a team entry entirely (round-robin: adjusts count; other modes: just marks for removal)
  void _removeTeamEntry(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.markedForRemoval = true;
      // Only adjust target count in round-robin (dynamic count);
      // In KO/Group modes the target is fixed.
      if (_isRoundRobin) {
        _targetTeamCount =
            _teamControllers.where((c) => !c.markedForRemoval).length;
      }
    });
  }

  /// Clear team fields but keep the slot (for group+KO and KO-only modes)
  void _clearTeamFields(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.nameController.clear();
      for (final mc in controller.memberControllers) {
        mc.clear();
      }
      // Reset back to default member count
      while (controller.canRemoveMember) {
        controller.removeMemberField();
      }
      controller.groupIndex = null;
    });
  }

  Future<void> _saveAllTeams() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final state = widget.adminState;
      final existingTeamIds = state.teams.map((t) => t.id).toSet();

      // Update admin state group count BEFORE saving group assignments so
      // assignTeamToGroup validates against the correct (new) count.
      if (_isGroupPhase && state.numberOfGroups != _numberOfGroups) {
        state.setNumberOfGroups(_numberOfGroups);
      }

      for (int i = 0; i < _teamControllers.length; i++) {
        final controller = _teamControllers[i];

        if (controller.markedForRemoval) {
          // Only delete if it actually exists in the backend
          if (controller.id != null &&
              existingTeamIds.contains(controller.id)) {
            await state.deleteTeam(controller.id!);
          }
          continue;
        }

        if (controller.nameController.text.trim().isEmpty) {
          continue;
        }

        final currentSnap = TeamSnapshot.fromController(controller);

        if (controller.isNew || controller.id == null) {
          // Brand-new team — must be created
          final mv = controller.memberValues;
          final success = await state.addTeam(
            name: currentSnap.name,
            member1: mv.isNotEmpty ? mv[0] : '',
            member2: mv.length > 1 ? mv[1] : '',
            member3: mv.length > 2 ? mv[2] : '',
          );

          if (success && state.teams.isNotEmpty) {
            controller.id = state.teams.last.id;
            controller.isNew = false;
          }
        } else {
          // Existing team — diff against snapshot to skip unchanged data
          final original = _originalSnapshots[controller.id!];
          if (original != null && currentSnap.dataEquals(original)) {
            continue; // Nothing changed — skip entirely
          }

          // Only write team data if name or members actually changed
          if (original == null ||
              currentSnap.name != original.name ||
              !TeamSnapshot.listEquals(currentSnap.members, original.members)) {
            final mv = controller.memberValues;
            await state.updateTeam(
              teamId: controller.id!,
              name: currentSnap.name,
              member1: mv.isNotEmpty ? mv[0] : '',
              member2: mv.length > 1 ? mv[1] : '',
              member3: mv.length > 2 ? mv[2] : '',
            );
          }
        }

        // Group assignment
        if (state.tournamentStyle == TournamentStyle.groupsAndKnockouts &&
            controller.id != null) {
          if (controller.isReserve) {
            // Reserve teams must never be in a group — remove if still
            // assigned so they won't count toward the group phase.
            final currentGroupIndex = state.getTeamGroupIndex(controller.id!);
            if (currentGroupIndex >= 0) {
              await state.removeTeamFromGroup(controller.id!);
            }
          } else {
            // Active team — only update if group changed from snapshot
            final original = _originalSnapshots[controller.id!];
            if (original == null ||
                currentSnap.groupIndex != original.groupIndex) {
              if (controller.groupIndex != null) {
                await state.assignTeamToGroup(
                    controller.id!, controller.groupIndex!);
              } else {
                final currentGroupIndex =
                    state.getTeamGroupIndex(controller.id!);
                if (currentGroupIndex >= 0) {
                  await state.removeTeamFromGroup(controller.id!);
                }
              }
            }
          }
        }
      }

      // Capture active team IDs before cleanup for reorder (preserving UI order)
      final activeIds = _teamControllers
          .where((c) => !c.isReserve && !c.markedForRemoval && c.id != null)
          .map((c) => c.id!)
          .toList();

      _teamControllers.removeWhere((c) => c.markedForRemoval);

      // Preserve group count before reload (loadGroups may override from Firebase)
      final preservedGroupCount = _numberOfGroups;
      await state.loadTeams();
      await state.loadGroups();
      // Restore the user's group count selection after reload
      if (state.numberOfGroups != preservedGroupCount) {
        state.setNumberOfGroups(preservedGroupCount);
      }
      // Reorder teams: active (tournament) teams first
      if (activeIds.isNotEmpty) {
        await state.reorderTeams(activeIds);
      }

      // Persist reserve team IDs so the bench survives page reloads
      final reserveIds = _teamControllers
          .where((c) => c.isReserve && !c.markedForRemoval && c.id != null)
          .map((c) => c.id!)
          .toSet();
      await state.saveReserveTeamIds(reserveIds);

      // Commit target team count to admin state and persist if changed
      state.setTargetTeamCount(_targetTeamCount);
      if (_targetTeamCount != _originalTargetTeamCount) {
        await state.saveTargetTeamCount(_targetTeamCount);
      }

      // Capture group indices before re-init so they survive the reload
      final preservedGroupIndices = <String, int?>{};
      for (final c in _teamControllers) {
        if (c.id != null) {
          preservedGroupIndices[c.id!] = c.groupIndex;
        }
      }

      _initializeControllers(
        preserveTargetCount: _targetTeamCount,
        preserveGroupCount: _numberOfGroups,
        preserveGroupIndices: preservedGroupIndices,
      );

      if (mounted) {
        setState(() {
          _showSaveSuccess = true;
        });
        _saveSuccessTimer?.cancel();
        _saveSuccessTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSaveSuccess = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Fehler beim Speichern: $e');
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _assignGroupsRandomly() async {
    final groupCount = _numberOfGroups;
    final activeControllers = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList()
      ..shuffle(Random());

    // Assign each controller a group index round-robin
    for (int i = 0; i < activeControllers.length; i++) {
      activeControllers[i].groupIndex = i % groupCount;
    }
    // Ensure reserve controllers have no group
    for (final c in _teamControllers) {
      if (c.isReserve) c.groupIndex = null;
    }
    setState(() {});
  }

  /// Distributes teams evenly across groups in sequential blocks:
  /// first N teams → group A, next N → group B, etc.
  void _distributeGroupsEvenly() {
    final groupCount = _numberOfGroups;
    final activeControllers = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList();
    final teamCount = activeControllers.length;
    final baseSize = teamCount ~/ groupCount;
    final remainder = teamCount % groupCount;

    int index = 0;
    for (int g = 0; g < groupCount; g++) {
      // First `remainder` groups get one extra team
      final size = baseSize + (g < remainder ? 1 : 0);
      for (int t = 0; t < size; t++) {
        activeControllers[index].groupIndex = g;
        index++;
      }
    }
    // Ensure reserve controllers have no group
    for (final c in _teamControllers) {
      if (c.isReserve) c.groupIndex = null;
    }
    setState(() {});
  }

  /// Reorders the controller list so that active teams are sorted by their
  /// group index (unassigned teams come last). Reserve teams stay at the end.
  void _orderByGroups() {
    final active = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList();
    final reserve = _teamControllers
        .where((c) => c.isReserve || c.markedForRemoval)
        .toList();

    active.sort((a, b) {
      final ga = a.groupIndex ?? 999;
      final gb = b.groupIndex ?? 999;
      return ga.compareTo(gb);
    });

    _teamControllers
      ..clear()
      ..addAll(active)
      ..addAll(reserve);
    setState(() {});
  }

  /// Removes the group assignment from every controller (active and reserve).
  void _clearAllGroups() {
    for (final c in _teamControllers) {
      c.groupIndex = null;
    }
    setState(() {});
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
          'Du hast ungespeicherte Änderungen. Möchtest du diese verwerfen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: TreeColors.rebeccapurple,
            ),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: AppColors.textOnColored,
            ),
            child: const Text('Verwerfen'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _saveAllTeams();
              if (mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(this.context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: AppColors.textOnColored,
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  void dispose() {
    _saveSuccessTimer?.cancel();
    for (final controller in _teamControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showGroups = _isGroupPhase;
    final isLocked = widget.adminState.isTournamentStarted;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            // ignore: use_build_context_synchronously
            Navigator.of(this.context).pop();
          }
        }
      },
      child: ChangeNotifierProvider.value(
        value: widget.adminState,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: AppColors.accent,
              selectionColor: AppColors.accent.withAlpha(64),
              selectionHandleColor: AppColors.accent,
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Teams & Gruppen'),
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: AppColors.textOnColored,
              actions: [
                if (_hasUnsavedChanges)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Center(
                      child: Text(
                        '• Ungespeichert',
                        style: TextStyle(
                          color: AppColors.caution,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                _buildTopControls(isLocked, showGroups, isMobile),
                Expanded(
                  child: _buildTeamsList(showGroups, isLocked, isMobile),
                ),
                _buildBottomBar(isLocked),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(bool isLocked, bool showGroups, bool isMobile) {
    final filledCount = _teamControllers
        .where((c) =>
            !c.markedForRemoval &&
            !c.isReserve &&
            c.nameController.text.isNotEmpty)
        .length;
    final activeCount = _teamControllers
        .where((c) => !c.markedForRemoval && !c.isReserve)
        .length;
    final allowed = _allowedTeamCounts;
    final isDropdownEnabled =
        !isLocked && (_isKOOnly || _isRoundRobin) && !_isGroupPhase;
    // In round-robin mode, the count is dynamic, so we don't use a dropdown
    final showTeamCountDropdown = !_isRoundRobin;

    // Mode label
    String modeLabel;
    IconData modeIcon;
    Color modeColor;
    switch (_style) {
      case TournamentStyle.groupsAndKnockouts:
        modeLabel = 'Gruppenphase + K.O.';
        modeIcon = Icons.grid_view;
        modeColor = AppColors.accent;
      case TournamentStyle.knockoutsOnly:
        modeLabel = 'Nur K.O.-Phase';
        modeIcon = Icons.account_tree;
        modeColor = TreeColors.rebeccapurple;
      case TournamentStyle.everyoneVsEveryone:
        modeLabel = 'Jeder gegen Jeden';
        modeIcon = Icons.sync_alt;
        modeColor = FieldColors.springgreen;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: modeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(modeIcon, size: 16, color: modeColor),
                const SizedBox(width: 6),
                Text(
                  modeLabel,
                  style: TextStyle(
                    color: modeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!isLocked && !showGroups) ...[
            // Teams count row (hidden for group+KO since team count is derived from groups)
            Row(
              children: [
                Icon(Icons.groups,
                    size: isMobile ? 20 : 24, color: TreeColors.rebeccapurple),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  _isRoundRobin ? 'Teams:' : 'Anzahl Teams:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                if (showTeamCountDropdown)
                  SizedBox(
                    width: isMobile ? 70 : 80,
                    child: DropdownButtonFormField<int>(
                      value: allowed.contains(_targetTeamCount)
                          ? _targetTeamCount
                          : allowed.first,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                            vertical: isMobile ? 6 : 8),
                        border: const OutlineInputBorder(),
                      ),
                      items: allowed.map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text(
                            '$count',
                            style: TextStyle(fontSize: isMobile ? 14 : null),
                          ),
                        );
                      }).toList(),
                      onChanged: isDropdownEnabled
                          ? (value) {
                              if (value != null) {
                                _updateTargetTeamCount(value);
                              }
                            }
                          : null,
                    ),
                  )
                else
                  // Round-robin: show count as text
                  Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: TreeColors.rebeccapurple,
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                      vertical: isMobile ? 4 : 6),
                  decoration: BoxDecoration(
                    color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Text(
                    _isRoundRobin
                        ? '$filledCount Teams'
                        : '$filledCount / $_targetTeamCount ausgefüllt',
                    style: TextStyle(
                      color: TreeColors.rebeccapurple,
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 12 : null,
                    ),
                  ),
                ),
              ],
            ),
            if (!isMobile) const SizedBox(height: 16),
          ],

          // Groups row (only for group+KO mode)
          if (showGroups) ...[
            Row(
              children: [
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  'Gruppen:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                SizedBox(
                  width: isMobile ? 65 : 70,
                  child: DropdownButtonFormField<int>(
                    value: _numberOfGroups,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 6 : 8),
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(9, (i) => i + 2).map((count) {
                      return DropdownMenuItem(
                        value: count,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : null,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: isLocked
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() {
                                _numberOfGroups = val;
                              });
                              _updateTargetTeamCount(val * 4);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people,
                          size: 12, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${_numberOfGroups * 4} Teams',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isLocked) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Gruppenoptionen',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    onSelected: (value) {
                      if (value == 'distribute') {
                        _distributeGroupsEvenly();
                      } else if (value == 'random') {
                        _assignGroupsRandomly();
                      } else if (value == 'order') {
                        _orderByGroups();
                      } else if (value == 'clear') {
                        _clearAllGroups();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'distribute',
                        child: ListTile(
                          title: Text('Gruppen gleichmäßig verteilen'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'random',
                        child: ListTile(
                          title: Text('Gruppen zufällig zuweisen'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'order',
                        child: ListTile(
                          title: Text('Nach Gruppen sortieren'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: ListTile(
                          title: Text('Alle Gruppen zurücksetzen'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
          if (isLocked)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.caution.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.caution),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: AppColors.caution, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Turnier gestartet - Teams können nicht mehr bearbeitet werden',
                      style: TextStyle(color: AppColors.caution),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamsList(bool showGroups, bool isLocked, bool isMobile) {
    final activeControllers = _teamControllers
        .where((c) => !c.markedForRemoval && !c.isReserve)
        .toList();
    final reserveControllers = _teamControllers
        .where((c) => !c.markedForRemoval && c.isReserve)
        .toList();

    if (activeControllers.isEmpty &&
        reserveControllers.isEmpty &&
        !_isRoundRobin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text(
              'Wähle oben die Anzahl der Teams',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active team cards
        for (int i = 0; i < activeControllers.length; i++)
          _buildTeamRow(
            _teamControllers.indexOf(activeControllers[i]),
            activeControllers[i],
            showGroups,
            isLocked,
            isMobile,
            displayNumber: i + 1,
          ),

        // Add team button for round-robin
        if (_isRoundRobin && !isLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: _showAddTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Team hinzufügen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TreeColors.rebeccapurple,
                side: BorderSide(
                    color: TreeColors.rebeccapurple.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        // Reserve section
        if (reserveControllers.isNotEmpty) ...[
          _buildReserveDivider(),
          for (int i = 0; i < reserveControllers.length; i++)
            _buildTeamRow(
              _teamControllers.indexOf(reserveControllers[i]),
              reserveControllers[i],
              showGroups,
              isLocked,
              isMobile,
              displayNumber: i + 1,
            ),
        ],
      ],
    );
  }

  /// Visual divider between active tournament teams and the reserve bench.
  Widget _buildReserveDivider() {
    final reserveCount = _teamControllers
        .where((c) => c.isReserve && !c.markedForRemoval)
        .length;
    final spotsAvailable = _targetTeamCount - _activeFilledCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Divider(thickness: 2, color: AppColors.grey400)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.grey400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Ersatzbank ($reserveCount)',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(
                  child: Divider(thickness: 2, color: AppColors.grey400)),
            ],
          ),
          if (spotsAvailable > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Noch $spotsAvailable ${spotsAvailable == 1 ? 'Platz' : 'Plätze'} im Turnier frei \u2013 Teams mit \u2191 hochstufen',
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked,
    bool isMobile, {
    int? displayNumber,
  }) {
    final isReserve = controller.isReserve;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isReserve ? 1 : 2,
      color: isReserve ? AppColors.grey50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isReserve
            ? const BorderSide(color: AppColors.grey300)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isMobile
            ? _buildMobileTeamRow(index, controller, showGroups, isLocked,
                displayNumber: displayNumber)
            : _buildDesktopTeamRow(index, controller, showGroups, isLocked,
                displayNumber: displayNumber),
      ),
    );
  }

  Widget _buildDesktopTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked, {
    int? displayNumber,
  }) {
    final isReserve = controller.isReserve;
    final badgeColor = isReserve ? AppColors.grey500 : TreeColors.rebeccapurple;
    final hasName = controller.nameController.text.isNotEmpty;
    final membersText = controller.membersText;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${displayNumber ?? (index + 1)}',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Team info (read-only, tap to edit)
        Expanded(
          flex: 5,
          child: InkWell(
            onTap: isLocked ? null : () => _showEditTeamDialog(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasName ? AppColors.grey300 : AppColors.grey200,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isReserve ? AppColors.grey50 : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: hasName
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.nameController.text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (membersText.isNotEmpty)
                                Text(
                                  membersText,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          )
                        : const Text(
                            'Leerer Slot – tippen zum Bearbeiten',
                            style: TextStyle(
                              color: AppColors.textDisabled,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  if (!isLocked)
                    const Icon(Icons.edit,
                        size: 16, color: AppColors.textSubtle),
                ],
              ),
            ),
          ),
        ),
        if (showGroups && !isReserve) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Builder(builder: (context) {
              final counts = _groupCounts();
              final groupCount = _numberOfGroups;
              final activeTeams = _teamControllers
                  .where((c) => !c.isReserve && !c.markedForRemoval)
                  .length;
              final idealSize =
                  groupCount > 0 ? (activeTeams / groupCount).ceil() : 0;
              final currentGroup = _clampedGroupIndex(controller.groupIndex);
              return DropdownButtonFormField<int?>(
                value: currentGroup,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Gruppe',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                selectedItemBuilder: (context) => [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('-',
                        style: TextStyle(color: AppColors.textDisabled)),
                  ),
                  ...List.generate(groupCount, (i) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(String.fromCharCode(65 + i)),
                    );
                  }),
                ],
                items: [
                  const DropdownMenuItem(
                    child: Text('-',
                        style: TextStyle(color: AppColors.textDisabled)),
                  ),
                  ...List.generate(groupCount, (i) {
                    final count = counts[i] ?? 0;
                    final isFull = count >= idealSize && currentGroup != i;
                    return DropdownMenuItem(
                      value: i,
                      enabled: !isFull,
                      child: Text(
                        '${String.fromCharCode(65 + i)} ($count/$idealSize)',
                        style: TextStyle(
                          color: isFull ? AppColors.textDisabled : null,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: isLocked
                    ? null
                    : (value) {
                        setState(() {
                          controller.groupIndex = value;
                        });
                      },
              );
            }),
          ),
        ],
        if (!isLocked) ...[
          const SizedBox(width: 8),
          if (isReserve) ...[
            // Reserve team: promote to active
            IconButton(
              onPressed: () => _promoteToActive(index),
              icon: const Icon(Icons.arrow_upward),
              color: FieldColors.springgreen,
              tooltip: 'Ins Turnier hochstufen',
            ),
            // Delete reserve team
            IconButton(
              onPressed: () => _removeTeamEntry(index),
              icon: const Icon(Icons.delete_outline),
              color: GroupPhaseColors.cupred,
              tooltip: 'Entfernen',
            ),
          ] else ...[
            // Active team: move to reserve (bench)
            if (!_isRoundRobin)
              IconButton(
                onPressed: () => _moveToReserve(index),
                icon: const Icon(Icons.arrow_downward),
                color: AppColors.warning,
                tooltip: 'Auf Ersatzbank',
              ),
            if (_isRoundRobin)
              IconButton(
                onPressed: () => _removeTeamEntry(index),
                icon: const Icon(Icons.delete_outline),
                color: GroupPhaseColors.cupred,
                tooltip: 'Team löschen',
              )
            else
              IconButton(
                onPressed: () => _clearTeamFields(index),
                icon: const Icon(Icons.backspace_outlined),
                color: AppColors.warning,
                tooltip: 'Felder leeren',
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildMobileTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked, {
    int? displayNumber,
  }) {
    final isReserve = controller.isReserve;
    final badgeColor = isReserve ? AppColors.grey500 : TreeColors.rebeccapurple;
    final hasName = controller.nameController.text.isNotEmpty;
    final membersText = controller.membersText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '${displayNumber ?? (index + 1)}',
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Team info (read-only, tap to edit)
            Expanded(
              child: InkWell(
                onTap: isLocked ? null : () => _showEditTeamDialog(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: hasName ? AppColors.grey300 : AppColors.grey200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isReserve ? AppColors.grey50 : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: hasName
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    controller.nameController.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (membersText.isNotEmpty)
                                    Text(
                                      membersText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              )
                            : const Text(
                                'Leerer Slot – tippen',
                                style: TextStyle(
                                  color: AppColors.textDisabled,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                      if (!isLocked)
                        const Icon(Icons.edit,
                            size: 14, color: AppColors.textSubtle),
                    ],
                  ),
                ),
              ),
            ),
            if (!isLocked) ...[
              if (isReserve) ...[
                IconButton(
                  onPressed: () => _promoteToActive(index),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  color: FieldColors.springgreen,
                  tooltip: 'Ins Turnier',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: () => _removeTeamEntry(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: GroupPhaseColors.cupred,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ] else ...[
                if (!_isRoundRobin)
                  IconButton(
                    onPressed: () => _moveToReserve(index),
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    color: AppColors.warning,
                    tooltip: 'Auf Ersatzbank',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                if (_isRoundRobin)
                  IconButton(
                    onPressed: () => _removeTeamEntry(index),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: GroupPhaseColors.cupred,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  )
                else
                  IconButton(
                    onPressed: () => _clearTeamFields(index),
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    color: AppColors.warning,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ],
          ],
        ),
        if (showGroups && !isReserve) ...[
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final counts = _groupCounts();
            final groupCount = _numberOfGroups;
            final activeTeams = _teamControllers
                .where((c) => !c.isReserve && !c.markedForRemoval)
                .length;
            final idealSize =
                groupCount > 0 ? (activeTeams / groupCount).ceil() : 0;
            final currentGroup = _clampedGroupIndex(controller.groupIndex);
            return DropdownButtonFormField<int?>(
              value: currentGroup,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              selectedItemBuilder: (context) => [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Keine Gruppe',
                      style: TextStyle(color: AppColors.textDisabled)),
                ),
                ...List.generate(groupCount, (i) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Gruppe ${String.fromCharCode(65 + i)}'),
                  );
                }),
              ],
              items: [
                const DropdownMenuItem(
                  child: Text('Keine Gruppe',
                      style: TextStyle(color: AppColors.textDisabled)),
                ),
                ...List.generate(groupCount, (i) {
                  final count = counts[i] ?? 0;
                  final isFull = count >= idealSize && currentGroup != i;
                  return DropdownMenuItem(
                    value: i,
                    enabled: !isFull,
                    child: Text(
                      'Gruppe ${String.fromCharCode(65 + i)} ($count/$idealSize)',
                      style: TextStyle(
                        color: isFull ? AppColors.textDisabled : null,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: isLocked
                  ? null
                  : (value) {
                      setState(() {
                        controller.groupIndex = value;
                      });
                    },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBottomBar(bool isLocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isLocked)
              IconButton(
                onPressed: _showAddTeamDialog,
                icon: const Icon(Icons.person_add),
                color: TreeColors.rebeccapurple,
                tooltip: 'Team hinzufügen',
              ),
            const Spacer(),
            if (!isLocked)
              SizedBox(
                width: 160,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (_isSaving || _showSaveSuccess) ? null : _saveAllTeams,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUnsavedChanges && !_showSaveSuccess
                        ? AppColors.textDisabled
                        : AppColors.grey300,
                    foregroundColor: AppColors.textOnColored,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnColored,
                                  ),
                                )
                              : _showSaveSuccess
                                  ? const Icon(Icons.check, size: 24)
                                  : const Icon(Icons.save, size: 24),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _showSaveSuccess ? 'Gespeichert' : 'Speichern',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
