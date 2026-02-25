import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/views/admin/team_edit_controller.dart';
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
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  TournamentStyle get _style => widget.adminState.tournamentStyle;
  bool get _isGroupPhase => _style == TournamentStyle.groupsAndKnockouts;
  bool get _isKOOnly => _style == TournamentStyle.knockoutsOnly;
  bool get _isRoundRobin => _style == TournamentStyle.everyoneVsEveryone;

  /// Whether any team is marked as reserve (on the bench)
  bool get _hasReserveTeams =>
      !_isRoundRobin &&
      _teamControllers.any((c) => c.isReserve && !c.markedForRemoval);

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
        return [widget.adminState.numberOfGroups * 4];
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
    if (index < 0 || index >= widget.adminState.numberOfGroups) return null;
    return index;
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers({int? preserveTargetCount}) {
    for (final controller in _teamControllers) {
      controller.dispose();
    }
    _teamControllers.clear();

    final maxGroupIndex = widget.adminState.numberOfGroups - 1;
    for (final team in widget.adminState.teams) {
      final groupIndex = widget.adminState.getTeamGroupIndex(team.id);
      _teamControllers.add(TeamEditController(
        id: team.id,
        name: team.name,
        member1: team.member1,
        member2: team.member2,
        // Clamp: ignore stale group indices that exceed current group count
        groupIndex:
            groupIndex >= 0 && groupIndex <= maxGroupIndex ? groupIndex : null,
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
        _targetTeamCount = widget.adminState.numberOfGroups * 4;
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
      // On initial load (no preserveTargetCount), use persisted reserve IDs
      // from Firestore so the bench survives page reloads.
      _applyReserveMarking(usePersistedIds: preserveTargetCount == null);
    } else {
      // No registered teams yet — seed with admin state count or mode default
      final stateCount = widget.adminState.targetTeamCount;
      if (_isGroupPhase) {
        _targetTeamCount = widget.adminState.numberOfGroups * 4;
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

    // Sync the selected count into admin state (deferred to avoid
    // notifyListeners during build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.adminState.setTargetTeamCount(_targetTeamCount);
    });

    _hasUnsavedChanges = false;
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
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
    if (usePersistedIds && persistedReserveIds.isNotEmpty) {
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
            if (_isGroupPhase) c.groupIndex = null;
          }
        }
      }
    }

    // Clamp stale group indices that exceed the current number of groups
    // (e.g. after switching from 10 → 9 groups)
    if (_isGroupPhase) {
      final maxIndex = widget.adminState.numberOfGroups - 1;
      for (final c in _teamControllers) {
        if (c.groupIndex != null && c.groupIndex! > maxIndex) {
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
      _hasUnsavedChanges = true;
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
          _hasUnsavedChanges = true;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kein Platz im Turnier. Verschiebe zuerst ein Team auf die Ersatzbank.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      controller.isReserve = false;
      _hasUnsavedChanges = true;
    });
  }

  /// Update team slot count (for KO-only and Group+KO modes with fixed slots)
  void _updateTargetTeamCount(int count) {
    setState(() {
      _targetTeamCount = count;
      // Re-categorize controllers as active/reserve based on the new count
      _applyReserveMarking();
      _hasUnsavedChanges = true;
    });
    // Sync with admin state so startTournament knows the selected count
    widget.adminState.setTargetTeamCount(count);
  }

  /// Add a single new team entry (for round-robin mode)
  void _addTeamEntry() {
    setState(() {
      _teamControllers.add(TeamEditController());
      _targetTeamCount =
          _teamControllers.where((c) => !c.markedForRemoval).length;
      _hasUnsavedChanges = true;
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
      _hasUnsavedChanges = true;
    });
  }

  /// Clear team fields but keep the slot (for group+KO and KO-only modes)
  void _clearTeamFields(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.nameController.clear();
      controller.member1Controller.clear();
      controller.member2Controller.clear();
      controller.groupIndex = null;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveAllTeams() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final state = widget.adminState;
      final existingTeamIds = state.teams.map((t) => t.id).toSet();

      for (int i = 0; i < _teamControllers.length; i++) {
        final controller = _teamControllers[i];

        if (controller.markedForRemoval) {
          if (controller.id != null &&
              existingTeamIds.contains(controller.id)) {
            await state.deleteTeam(controller.id!);
          }
          continue;
        }

        if (controller.nameController.text.trim().isEmpty) {
          continue;
        }

        if (controller.isNew || controller.id == null) {
          final success = await state.addTeam(
            name: controller.nameController.text.trim(),
            member1: controller.member1Controller.text.trim(),
            member2: controller.member2Controller.text.trim(),
          );

          if (success && state.teams.isNotEmpty) {
            controller.id = state.teams.last.id;
            controller.isNew = false;
          }
        } else {
          await state.updateTeam(
            teamId: controller.id!,
            name: controller.nameController.text.trim(),
            member1: controller.member1Controller.text.trim(),
            member2: controller.member2Controller.text.trim(),
          );
        }

        if (state.tournamentStyle == TournamentStyle.groupsAndKnockouts &&
            controller.id != null) {
          final currentGroupIndex = state.getTeamGroupIndex(controller.id!);
          if (controller.groupIndex != currentGroupIndex) {
            if (controller.groupIndex != null) {
              await state.assignTeamToGroup(
                  controller.id!, controller.groupIndex!);
            } else if (currentGroupIndex >= 0) {
              // Reserve team still in a group — remove it so it won't
              // count toward the group phase when starting the tournament.
              await state.removeTeamFromGroup(controller.id!);
            }
          }
        }
      }

      // Capture active team IDs before cleanup for reorder
      final activeIds = _teamControllers
          .where((c) => !c.isReserve && !c.markedForRemoval && c.id != null)
          .map((c) => c.id!)
          .toSet();

      _teamControllers.removeWhere((c) => c.markedForRemoval);

      // Preserve group count before reload (loadGroups may override from Firebase)
      final preservedGroupCount = state.numberOfGroups;
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
      await state.saveTargetTeamCount(_targetTeamCount);

      _initializeControllers(preserveTargetCount: _targetTeamCount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teams erfolgreich gespeichert'),
            backgroundColor: FieldColors.springgreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: GroupPhaseColors.cupred,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
    }
  }

  Future<void> _assignGroupsRandomly() async {
    final groupCount = widget.adminState.numberOfGroups;
    // Collect all non-reserve, non-removed controllers (includes unsaved new ones)
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
    setState(() {
      _hasUnsavedChanges = true;
    });
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
                Icon(Icons.grid_view,
                    size: isMobile ? 20 : 24, color: AppColors.accent),
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
                    value: widget.adminState.numberOfGroups,
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
                              widget.adminState.setNumberOfGroups(val);
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
                        '${widget.adminState.numberOfGroups * 4} Teams',
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
                  if (isMobile)
                    IconButton(
                      onPressed: _assignGroupsRandomly,
                      icon: const Icon(Icons.casino, size: 20),
                      color: AppColors.caution,
                      tooltip: 'Gruppen würfeln',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    )
                  else
                    ElevatedButton(
                      onPressed: _assignGroupsRandomly,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caution,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: const Text('Gruppen würfeln'),
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
              onPressed: _addTeamEntry,
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
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller.nameController,
            enabled: !isLocked,
            decoration: const InputDecoration(
              labelText: 'Teamname',
              hintText: 'z.B. Die Ballkünstler',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controller.member1Controller,
            enabled: !isLocked,
            decoration: const InputDecoration(
              labelText: 'Spieler 1',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controller.member2Controller,
            enabled: !isLocked,
            decoration: const InputDecoration(
              labelText: 'Spieler 2',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _onFieldChanged(),
          ),
        ),
        if (showGroups && !isReserve) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int?>(
              value: _clampedGroupIndex(controller.groupIndex),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                  child: Text('-',
                      style: TextStyle(color: AppColors.textDisabled)),
                ),
                ...List.generate(widget.adminState.numberOfGroups, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text('Gruppe ${String.fromCharCode(65 + i)}'),
                  );
                }),
              ],
              onChanged: isLocked
                  ? null
                  : (value) {
                      setState(() {
                        controller.groupIndex = value;
                        _hasUnsavedChanges = true;
                      });
                    },
            ),
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
            // Active team: optionally move to reserve
            if (_hasReserveTeams)
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
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller.nameController,
                enabled: !isLocked,
                decoration: const InputDecoration(
                  labelText: 'Teamname',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
            if (!isLocked) ...[
              if (isReserve) ...[
                IconButton(
                  onPressed: () => _promoteToActive(index),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  color: FieldColors.springgreen,
                  tooltip: 'Ins Turnier',
                ),
                IconButton(
                  onPressed: () => _removeTeamEntry(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: GroupPhaseColors.cupred,
                ),
              ] else ...[
                if (_hasReserveTeams)
                  IconButton(
                    onPressed: () => _moveToReserve(index),
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    color: AppColors.warning,
                    tooltip: 'Auf Ersatzbank',
                  ),
                if (_isRoundRobin)
                  IconButton(
                    onPressed: () => _removeTeamEntry(index),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: GroupPhaseColors.cupred,
                  )
                else
                  IconButton(
                    onPressed: () => _clearTeamFields(index),
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    color: AppColors.warning,
                  ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.member1Controller,
                enabled: !isLocked,
                decoration: const InputDecoration(
                  labelText: 'Spieler 1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller.member2Controller,
                enabled: !isLocked,
                decoration: const InputDecoration(
                  labelText: 'Spieler 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => _onFieldChanged(),
              ),
            ),
          ],
        ),
        if (showGroups && !isReserve) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _clampedGroupIndex(controller.groupIndex),
            decoration: const InputDecoration(
              labelText: 'Gruppe',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(
                child: Text('Keine Gruppe',
                    style: TextStyle(color: AppColors.textDisabled)),
              ),
              ...List.generate(widget.adminState.numberOfGroups, (i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text('Gruppe ${String.fromCharCode(65 + i)}'),
                );
              }),
            ],
            onChanged: isLocked
                ? null
                : (value) {
                    setState(() {
                      controller.groupIndex = value;
                      _hasUnsavedChanges = true;
                    });
                  },
          ),
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
            const Spacer(),
            if (!isLocked)
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAllTeams,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnColored,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichern...' : 'Alle speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasUnsavedChanges
                      ? FieldColors.springgreen
                      : AppColors.textDisabled,
                  foregroundColor: AppColors.textOnColored,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
