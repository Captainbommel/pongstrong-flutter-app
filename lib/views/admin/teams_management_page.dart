import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/views/admin/team_edit_controller.dart';
import 'package:pongstrong/views/admin/team_form_dialog.dart';
import 'package:pongstrong/views/admin/team_row_widget.dart';
import 'package:pongstrong/views/admin/team_snapshot.dart';
import 'package:provider/provider.dart';

/// A dedicated page for managing teams and group assignments.
/// Provides inline editing for better UX.
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
  Map<String, TeamSnapshot> _originalSnapshots = {};

  /// Set of controller refs that existed as empty/new slots at snapshot time.
  Set<TeamEditController> _originalNewControllers = {};
  int _originalTargetTeamCount = 0;
  int _originalNumberOfGroups = 0;

  /// Original order of existing team IDs (active first, reserve last).
  List<String> _originalTeamOrder = [];

  // ─── Computed properties ──────────────────────────────────

  TournamentStyle get _style => widget.adminState.tournamentStyle;
  bool get _isGroupPhase => _style == TournamentStyle.groupsAndKnockouts;
  bool get _isKOOnly => _style == TournamentStyle.knockoutsOnly;
  bool get _isRoundRobin => _style == TournamentStyle.everyoneVsEveryone;

  int get _activeFilledCount => _teamControllers
      .where((c) =>
          !c.isReserve &&
          !c.markedForRemoval &&
          c.nameController.text.isNotEmpty)
      .length;

  List<int> get _allowedTeamCounts {
    switch (_style) {
      case TournamentStyle.groupsAndKnockouts:
        return [_numberOfGroups * 4];
      case TournamentStyle.knockoutsOnly:
        return [8, 16, 32, 64];
      case TournamentStyle.everyoneVsEveryone:
        return List.generate(63, (i) => i + 2);
    }
  }

  int? _clampedGroupIndex(int? index) {
    if (index == null || index < 0 || index >= _numberOfGroups) return null;
    return index;
  }

  Map<int, int> _groupCounts() {
    final counts = <int, int>{};
    for (final c in _teamControllers) {
      if (!c.isReserve && !c.markedForRemoval && c.groupIndex != null) {
        counts[c.groupIndex!] = (counts[c.groupIndex!] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ─── Change tracking ──────────────────────────────────────

  bool get _hasUnsavedChanges {
    if (_targetTeamCount != _originalTargetTeamCount) return true;
    if (_numberOfGroups != _originalNumberOfGroups) return true;

    final currentExistingIds = _teamControllers
        .where((c) => !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toSet();
    for (final origId in _originalSnapshots.keys) {
      if (!currentExistingIds.contains(origId)) return true;
    }

    for (final c in _teamControllers) {
      if (c.markedForRemoval) continue;
      if (c.id == null && !_originalNewControllers.contains(c)) {
        if (c.nameController.text.trim().isNotEmpty) return true;
      }
    }

    final currentOrder = _teamControllers
        .where((c) => !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toList();
    if (!TeamSnapshot.listEquals(currentOrder, _originalTeamOrder)) return true;

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

  // ─── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _saveSuccessTimer?.cancel();
    for (final controller in _teamControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ─── Controller initialization ────────────────────────────

  void _initializeControllers({
    int? preserveTargetCount,
    int? preserveGroupCount,
    Map<String, int?>? preserveGroupIndices,
  }) {
    for (final controller in _teamControllers) {
      controller.dispose();
    }
    _teamControllers.clear();
    _numberOfGroups = preserveGroupCount ?? widget.adminState.numberOfGroups;

    final maxGroupIndex = _numberOfGroups - 1;
    for (final team in widget.adminState.teams) {
      int? groupIndex;
      if (preserveGroupIndices != null &&
          preserveGroupIndices.containsKey(team.id)) {
        groupIndex = preserveGroupIndices[team.id];
      } else {
        final stateIndex = widget.adminState.getTeamGroupIndex(team.id);
        groupIndex = stateIndex >= 0 ? stateIndex : null;
      }
      if (groupIndex != null && groupIndex > maxGroupIndex) groupIndex = null;
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
      _initTargetCountForExistingTeams(preserveTargetCount);
      _applyReserveMarking(usePersistedIds: true);
    } else {
      _initTargetCountForEmpty();
    }
    _takeSnapshots();
  }

  void _initTargetCountForExistingTeams(int? preserveTargetCount) {
    final stateCount = widget.adminState.targetTeamCount;
    final validKo = [8, 16, 32, 64];
    if (preserveTargetCount != null &&
        (_isKOOnly
            ? validKo.contains(preserveTargetCount)
            : preserveTargetCount >= 2)) {
      _targetTeamCount = preserveTargetCount;
    } else if (_isGroupPhase) {
      _targetTeamCount = _numberOfGroups * 4;
    } else if (_isKOOnly && validKo.contains(stateCount)) {
      _targetTeamCount = stateCount;
    } else if (_isRoundRobin && stateCount >= 2) {
      _targetTeamCount = stateCount;
    } else {
      _targetTeamCount = _teamControllers.length;
      if (_isKOOnly && !validKo.contains(_targetTeamCount)) {
        _targetTeamCount = [64, 32, 16, 8].firstWhere(
          (v) => v <= _teamControllers.length,
          orElse: () => 8,
        );
      }
    }
  }

  void _initTargetCountForEmpty() {
    final stateCount = widget.adminState.targetTeamCount;
    if (_isGroupPhase) {
      _targetTeamCount = _numberOfGroups * 4;
    } else if (_isKOOnly) {
      _targetTeamCount = [8, 16, 32, 64].contains(stateCount) ? stateCount : 8;
    } else {
      _targetTeamCount = 8;
    }
    if (!_isRoundRobin) {
      for (int i = 0; i < _targetTeamCount; i++) {
        _teamControllers.add(TeamEditController());
      }
    }
  }

  // ─── Reserve marking ──────────────────────────────────────

  void _applyReserveMarking({bool usePersistedIds = false}) {
    if (_isRoundRobin) {
      for (final c in _teamControllers) {
        c.isReserve = false;
      }
      return;
    }

    final persistedReserveIds = widget.adminState.reserveTeamIds;
    final hasMatchingReserveIds = usePersistedIds &&
        persistedReserveIds.isNotEmpty &&
        _teamControllers
            .any((c) => c.id != null && persistedReserveIds.contains(c.id));

    if (hasMatchingReserveIds) {
      _applyPersistedReserves(persistedReserveIds);
    } else {
      _applyPositionalReserves();
    }

    if (_isGroupPhase) {
      final maxIndex = _numberOfGroups - 1;
      for (final c in _teamControllers) {
        if (!c.isReserve && c.groupIndex != null && c.groupIndex! > maxIndex) {
          c.groupIndex = null;
        }
      }
    }
  }

  void _applyPersistedReserves(Set<String> persistedReserveIds) {
    for (final c in _teamControllers) {
      if (c.markedForRemoval) continue;
      c.isReserve = c.id != null && persistedReserveIds.contains(c.id);
      if (c.isReserve && _isGroupPhase) c.groupIndex = null;
    }
    final activeCount = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .length;
    for (int i = activeCount; i < _targetTeamCount; i++) {
      _teamControllers.add(TeamEditController());
    }
  }

  void _applyPositionalReserves() {
    final filledCount = _teamControllers
        .where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty)
        .length;

    if (filledCount <= _targetTeamCount) {
      for (final c in _teamControllers) {
        c.isReserve = false;
      }
      final nonRemoved =
          _teamControllers.where((c) => !c.markedForRemoval).length;
      if (nonRemoved > _targetTeamCount) {
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
      while (_teamControllers.where((c) => !c.markedForRemoval).length <
          _targetTeamCount) {
        _teamControllers.add(TeamEditController());
      }
    } else {
      int activeCount = 0;
      for (final c in _teamControllers) {
        if (c.markedForRemoval) continue;
        if (activeCount < _targetTeamCount) {
          c.isReserve = false;
          activeCount++;
        } else {
          c.isReserve = true;
        }
      }
    }
  }

  // ─── Team actions ─────────────────────────────────────────

  void _moveToReserve(int index) {
    setState(() {
      _teamControllers[index]
        ..isReserve = true
        ..groupIndex = null;
    });
  }

  void _promoteToActive(int index) {
    final controller = _teamControllers[index];
    final activeCount = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .length;

    if (activeCount >= _targetTeamCount) {
      final emptySlotIndex = _teamControllers.indexWhere((c) =>
          !c.isReserve &&
          !c.markedForRemoval &&
          c.nameController.text.isEmpty &&
          c.id == null);

      if (emptySlotIndex >= 0) {
        setState(() {
          _teamControllers.removeAt(emptySlotIndex).dispose();
          controller.isReserve = false;
        });
        return;
      }

      SnackBarHelper.showWarning(context,
          'Kein Platz im Turnier. Verschiebe zuerst ein Team auf die Ersatzbank.');
      return;
    }

    setState(() => controller.isReserve = false);
  }

  void _updateTargetTeamCount(int count) {
    setState(() {
      _targetTeamCount = count;
      _applyReserveMarking();
    });
  }

  void _removeTeamEntry(int index) {
    setState(() {
      _teamControllers[index].markedForRemoval = true;
      if (_isRoundRobin) {
        _targetTeamCount =
            _teamControllers.where((c) => !c.markedForRemoval).length;
      }
    });
  }

  void _clearTeamFields(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.nameController.clear();
      for (final mc in controller.memberControllers) {
        mc.clear();
      }
      while (controller.canRemoveMember) {
        controller.removeMemberField();
      }
      controller.groupIndex = null;
    });
  }

  // ─── Dialogs ──────────────────────────────────────────────

  Future<void> _showAddTeamDialog() async {
    final result = await TeamFormDialog.show(
      context,
      title: 'Team hinzufügen',
      confirmLabel: 'Hinzufügen',
    );
    if (result == null || result.name.isEmpty) {
      if (result != null && mounted) {
        SnackBarHelper.showWarning(context, 'Teamname darf nicht leer sein.');
      }
      return;
    }

    setState(() {
      if (_isRoundRobin) {
        _teamControllers.add(TeamEditController(
          name: result.name,
          members: result.members,
        ));
        _targetTeamCount =
            _teamControllers.where((c) => !c.markedForRemoval).length;
      } else {
        _fillEmptySlotOrBench(result);
      }
    });
  }

  void _fillEmptySlotOrBench(TeamFormResult result) {
    final emptySlotIndex = _teamControllers.indexWhere((c) =>
        !c.isReserve &&
        !c.markedForRemoval &&
        c.nameController.text.isEmpty &&
        c.id == null);

    if (emptySlotIndex >= 0) {
      final slot = _teamControllers[emptySlotIndex];
      slot.nameController.text = result.name;
      for (int i = 0; i < slot.memberControllers.length; i++) {
        slot.memberControllers[i].text =
            i < result.members.length ? result.members[i] : '';
      }
      for (int i = slot.memberControllers.length;
          i < result.members.length;
          i++) {
        if (result.members[i].isNotEmpty) {
          slot.addMemberField();
          slot.memberControllers.last.text = result.members[i];
        }
      }
    } else {
      _teamControllers.add(TeamEditController(
        name: result.name,
        members: result.members,
        isReserve: true,
      ));
    }
  }

  Future<void> _showEditTeamDialog(int index) async {
    final controller = _teamControllers[index];
    final result = await TeamFormDialog.show(
      context,
      title: 'Team bearbeiten',
      confirmLabel: 'Übernehmen',
      initialName: controller.nameController.text,
      initialMembers: controller.memberControllers.map((c) => c.text).toList(),
    );
    if (result == null) return;

    setState(() {
      controller.nameController.text = result.name;
      while (controller.memberControllers.length > result.members.length) {
        controller.removeMemberField();
      }
      while (controller.memberControllers.length < result.members.length) {
        controller.addMemberField();
      }
      for (int i = 0; i < result.members.length; i++) {
        controller.memberControllers[i].text = result.members[i];
      }
    });
  }

  // ─── Save ─────────────────────────────────────────────────

  Future<void> _saveAllTeams() async {
    setState(() => _isSaving = true);

    try {
      final state = widget.adminState;
      final existingTeamIds = state.teams.map((t) => t.id).toSet();

      if (_isGroupPhase && state.numberOfGroups != _numberOfGroups) {
        state.setNumberOfGroups(_numberOfGroups);
      }

      for (final controller in _teamControllers) {
        if (controller.markedForRemoval) {
          if (controller.id != null &&
              existingTeamIds.contains(controller.id)) {
            await state.deleteTeam(controller.id!);
          }
          continue;
        }
        if (controller.nameController.text.trim().isEmpty) continue;
        await _saveTeamController(state, controller);
      }

      await _persistPostSaveState(state);

      if (mounted) {
        setState(() => _showSaveSuccess = true);
        _saveSuccessTimer?.cancel();
        _saveSuccessTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSaveSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Fehler beim Speichern: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTeamController(
    AdminPanelState state,
    TeamEditController controller,
  ) async {
    final currentSnap = TeamSnapshot.fromController(controller);

    if (controller.isNew || controller.id == null) {
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
      final original = _originalSnapshots[controller.id!];
      if (original != null && currentSnap.dataEquals(original)) return;

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

    if (state.tournamentStyle == TournamentStyle.groupsAndKnockouts &&
        controller.id != null) {
      await _saveGroupAssignment(state, controller, currentSnap);
    }
  }

  Future<void> _saveGroupAssignment(
    AdminPanelState state,
    TeamEditController controller,
    TeamSnapshot currentSnap,
  ) async {
    if (controller.isReserve) {
      final currentGroupIndex = state.getTeamGroupIndex(controller.id!);
      if (currentGroupIndex >= 0) {
        await state.removeTeamFromGroup(controller.id!);
      }
    } else {
      final original = _originalSnapshots[controller.id!];
      if (original == null || currentSnap.groupIndex != original.groupIndex) {
        if (controller.groupIndex != null) {
          await state.assignTeamToGroup(controller.id!, controller.groupIndex!);
        } else {
          final currentGroupIndex = state.getTeamGroupIndex(controller.id!);
          if (currentGroupIndex >= 0) {
            await state.removeTeamFromGroup(controller.id!);
          }
        }
      }
    }
  }

  Future<void> _persistPostSaveState(AdminPanelState state) async {
    final activeIds = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toList();

    _teamControllers.removeWhere((c) => c.markedForRemoval);

    final preservedGroupCount = _numberOfGroups;
    await state.loadTeams();
    await state.loadGroups();
    if (state.numberOfGroups != preservedGroupCount) {
      state.setNumberOfGroups(preservedGroupCount);
    }
    if (activeIds.isNotEmpty) await state.reorderTeams(activeIds);

    final reserveIds = _teamControllers
        .where((c) => c.isReserve && !c.markedForRemoval && c.id != null)
        .map((c) => c.id!)
        .toSet();
    await state.saveReserveTeamIds(reserveIds);
    state.setTargetTeamCount(_targetTeamCount);
    if (_targetTeamCount != _originalTargetTeamCount) {
      await state.saveTargetTeamCount(_targetTeamCount);
    }

    final preservedGroupIndices = <String, int?>{};
    for (final c in _teamControllers) {
      if (c.id != null) preservedGroupIndices[c.id!] = c.groupIndex;
    }
    _initializeControllers(
      preserveTargetCount: _targetTeamCount,
      preserveGroupCount: _numberOfGroups,
      preserveGroupIndices: preservedGroupIndices,
    );
  }

  // ─── Group operations ─────────────────────────────────────

  void _assignGroupsRandomly() {
    final active = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList()
      ..shuffle(Random());
    for (int i = 0; i < active.length; i++) {
      active[i].groupIndex = i % _numberOfGroups;
    }
    for (final c in _teamControllers) {
      if (c.isReserve) c.groupIndex = null;
    }
    setState(() {});
  }

  void _distributeGroupsEvenly() {
    final active = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList();
    final baseSize = active.length ~/ _numberOfGroups;
    final remainder = active.length % _numberOfGroups;
    int index = 0;
    for (int g = 0; g < _numberOfGroups; g++) {
      final size = baseSize + (g < remainder ? 1 : 0);
      for (int t = 0; t < size; t++) {
        active[index++].groupIndex = g;
      }
    }
    for (final c in _teamControllers) {
      if (c.isReserve) c.groupIndex = null;
    }
    setState(() {});
  }

  void _orderByGroups() {
    final active = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .toList()
      ..sort((a, b) => (a.groupIndex ?? 999).compareTo(b.groupIndex ?? 999));
    final reserve = _teamControllers
        .where((c) => c.isReserve || c.markedForRemoval)
        .toList();
    _teamControllers
      ..clear()
      ..addAll(active)
      ..addAll(reserve);
    setState(() {});
  }

  void _clearAllGroups() {
    for (final c in _teamControllers) {
      c.groupIndex = null;
    }
    setState(() {});
  }

  // ─── Navigation guard ─────────────────────────────────────

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

  // ─── Build ────────────────────────────────────────────────

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
    final filledCount = _activeFilledCount;
    final activeCount = _teamControllers
        .where((c) => !c.markedForRemoval && !c.isReserve)
        .length;
    final allowed = _allowedTeamCounts;
    final isDropdownEnabled =
        !isLocked && (_isKOOnly || _isRoundRobin) && !_isGroupPhase;

    final (modeLabel, modeIcon, modeColor) = switch (_style) {
      TournamentStyle.groupsAndKnockouts => (
          'Gruppenphase + K.O.',
          Icons.grid_view,
          AppColors.accent
        ),
      TournamentStyle.knockoutsOnly => (
          'Nur K.O.-Phase',
          Icons.account_tree,
          TreeColors.rebeccapurple
        ),
      TournamentStyle.everyoneVsEveryone => (
          'Jeder gegen Jeden',
          Icons.sync_alt,
          FieldColors.springgreen
        ),
    };

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeBadge(modeLabel, modeIcon, modeColor),
          const SizedBox(height: 12),
          if (!isLocked && !showGroups) ...[
            _buildTeamCountRow(
              filledCount: filledCount,
              activeCount: activeCount,
              allowed: allowed,
              isDropdownEnabled: isDropdownEnabled,
              isMobile: isMobile,
            ),
            if (!isMobile) const SizedBox(height: 16),
          ],
          if (showGroups) _buildGroupsRow(isLocked, isMobile),
          if (isLocked) _buildLockedBanner(),
        ],
      ),
    );
  }

  Widget _buildModeBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTeamCountRow({
    required int filledCount,
    required int activeCount,
    required List<int> allowed,
    required bool isDropdownEnabled,
    required bool isMobile,
  }) {
    return Row(
      children: [
        Icon(Icons.groups,
            size: isMobile ? 20 : 24, color: TreeColors.rebeccapurple),
        SizedBox(width: isMobile ? 8 : 12),
        Text(
          _isRoundRobin ? 'Teams:' : 'Anzahl Teams:',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
        ),
        SizedBox(width: isMobile ? 8 : 12),
        if (!_isRoundRobin)
          SizedBox(
            width: isMobile ? 70 : 80,
            child: DropdownButtonFormField<int>(
              value: allowed.contains(_targetTeamCount)
                  ? _targetTeamCount
                  : allowed.first,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
                border: const OutlineInputBorder(),
              ),
              items: allowed
                  .map((count) => DropdownMenuItem(
                      value: count,
                      child: Text('$count',
                          style: TextStyle(fontSize: isMobile ? 14 : null))))
                  .toList(),
              onChanged: isDropdownEnabled
                  ? (value) {
                      if (value != null) _updateTargetTeamCount(value);
                    }
                  : null,
            ),
          )
        else
          Text(
            '$activeCount',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: TreeColors.rebeccapurple,
            ),
          ),
        const Spacer(),
        _buildCountBadge(filledCount, TreeColors.rebeccapurple, isMobile),
      ],
    );
  }

  Widget _buildCountBadge(int filledCount, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Text(
        _isRoundRobin
            ? '$filledCount Teams'
            : '$filledCount / $_targetTeamCount ausgefüllt',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: isMobile ? 12 : null,
        ),
      ),
    );
  }

  Widget _buildGroupsRow(bool isLocked, bool isMobile) {
    return Row(
      children: [
        SizedBox(width: isMobile ? 8 : 12),
        Text('Gruppen:',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
        SizedBox(width: isMobile ? 8 : 12),
        SizedBox(
          width: isMobile ? 65 : 70,
          child: DropdownButtonFormField<int>(
            value: _numberOfGroups,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12, vertical: isMobile ? 6 : 8),
              border: const OutlineInputBorder(),
            ),
            items: List.generate(
                9,
                (i) => DropdownMenuItem(
                    value: i + 2,
                    child: Text('${i + 2}',
                        style: TextStyle(fontSize: isMobile ? 14 : null)))),
            onChanged: isLocked
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _numberOfGroups = val);
                      _updateTargetTeamCount(val * 4);
                    }
                  },
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 12, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                '${_numberOfGroups * 4} Teams',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (!isLocked) _buildGroupOptionsMenu(),
      ],
    );
  }

  Widget _buildGroupOptionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Gruppenoptionen',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onSelected: (value) {
        switch (value) {
          case 'distribute':
            _distributeGroupsEvenly();
          case 'random':
            _assignGroupsRandomly();
          case 'order':
            _orderByGroups();
          case 'clear':
            _clearAllGroups();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'distribute',
            child: ListTile(
                title: Text('Gruppen gleichmäßig verteilen'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        PopupMenuItem(
            value: 'random',
            child: ListTile(
                title: Text('Gruppen zufällig zuweisen'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        PopupMenuItem(
            value: 'order',
            child: ListTile(
                title: Text('Nach Gruppen sortieren'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        PopupMenuDivider(),
        PopupMenuItem(
            value: 'clear',
            child: ListTile(
                title: Text('Alle Gruppen zurücksetzen'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
      ],
    );
  }

  Widget _buildLockedBanner() {
    return Container(
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
            Text('Wähle oben die Anzahl der Teams',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 18)),
          ],
        ),
      );
    }

    final counts = _groupCounts();
    final activeTeamCount = _teamControllers
        .where((c) => !c.isReserve && !c.markedForRemoval)
        .length;

    Widget buildRow(TeamEditController c, int displayNum) {
      final idx = _teamControllers.indexOf(c);
      return TeamRowWidget(
        index: idx,
        controller: c,
        showGroups: showGroups,
        isLocked: isLocked,
        isMobile: isMobile,
        isRoundRobin: _isRoundRobin,
        displayNumber: displayNum,
        numberOfGroups: _numberOfGroups,
        groupCounts: counts,
        activeTeamCount: activeTeamCount,
        clampGroupIndex: _clampedGroupIndex,
        onEdit: () => _showEditTeamDialog(idx),
        onMoveToReserve: _moveToReserve,
        onPromoteToActive: _promoteToActive,
        onRemove: _removeTeamEntry,
        onClear: _clearTeamFields,
        onGroupChanged: (i, g) =>
            setState(() => _teamControllers[i].groupIndex = g),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < activeControllers.length; i++)
          buildRow(activeControllers[i], i + 1),
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
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (reserveControllers.isNotEmpty) ...[
          _buildReserveDivider(),
          for (int i = 0; i < reserveControllers.length; i++)
            buildRow(reserveControllers[i], i + 1),
        ],
      ],
    );
  }

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
                style:
                    const TextStyle(color: AppColors.textSubtle, fontSize: 12),
              ),
            ),
        ],
      ),
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
              offset: Offset(0, -2)),
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
                        horizontal: 16, vertical: 12),
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
                              : Icon(
                                  _showSaveSuccess ? Icons.check : Icons.save,
                                  size: 24),
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
