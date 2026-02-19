import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
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

  /// Returns the allowed team counts for the dropdown based on tournament style
  List<int> get _allowedTeamCounts {
    switch (_style) {
      case TournamentStyle.groupsAndKnockouts:
        return [24]; // locked
      case TournamentStyle.knockoutsOnly:
        return [8, 16, 32, 64]; // powers of 2
      case TournamentStyle.everyoneVsEveryone:
        return List.generate(63, (i) => i + 2); // 2..64
    }
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

    for (final team in widget.adminState.teams) {
      final groupIndex = widget.adminState.getTeamGroupIndex(team.id);
      _teamControllers.add(TeamEditController(
        id: team.id,
        name: team.name,
        member1: team.mem1,
        member2: team.mem2,
        groupIndex: groupIndex >= 0 ? groupIndex : null,
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
      // Grow controller list to fill selected slots
      while (_teamControllers.length < _targetTeamCount) {
        _teamControllers.add(TeamEditController());
      }
      // For KO-only: trim the visible list to targetTeamCount
      if (_isKOOnly && _teamControllers.length > _targetTeamCount) {
        while (_teamControllers.length > _targetTeamCount) {
          final last = _teamControllers.removeLast();
          last.dispose();
        }
      }
    } else {
      // No registered teams yet — seed with admin state count or mode default
      final stateCount = widget.adminState.targetTeamCount;
      if (_isGroupPhase) {
        _targetTeamCount = 24;
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

  /// Update team slot count (for KO-only and Group+KO modes with fixed slots)
  void _updateTargetTeamCount(int count) {
    setState(() {
      _targetTeamCount = count;
      // Grow or shrink the controller list
      while (_teamControllers.length < count) {
        _teamControllers.add(TeamEditController());
      }
      while (_teamControllers.length > count) {
        final last = _teamControllers.removeLast();
        last.dispose();
      }
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

  /// Remove a team entry entirely (for round-robin mode)
  void _removeTeamEntry(int index) {
    setState(() {
      final controller = _teamControllers[index];
      controller.markedForRemoval = true;
      _targetTeamCount =
          _teamControllers.where((c) => !c.markedForRemoval).length;
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
            }
          }
        }
      }

      _teamControllers.removeWhere((c) => c.markedForRemoval);

      await state.loadTeams();
      await state.loadGroups();
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
    if (_hasUnsavedChanges) {
      await _saveAllTeams();
    }

    final success = await widget.adminState.assignGroupsRandomly();
    if (success) {
      for (final controller in _teamControllers) {
        if (controller.id != null) {
          controller.groupIndex =
              widget.adminState.getTeamGroupIndex(controller.id!);
        }
      }
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teams wurden zufällig auf Gruppen verteilt'),
            backgroundColor: FieldColors.springgreen,
          ),
        );
      }
    }
  }

  Future<void> _clearGroups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppen zurücksetzen?'),
        content: const Text('Alle Gruppenzuweisungen werden gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen',
                style: TextStyle(color: GroupPhaseColors.cupred)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.cupred,
              foregroundColor: Colors.white,
            ),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.adminState.clearGroupAssignments();
      for (final controller in _teamControllers) {
        controller.groupIndex = null;
      }
      setState(() {});
    }
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
              foregroundColor: GroupPhaseColors.cupred,
            ),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verwerfen'),
          ),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Speichern & Schließen'),
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
                  primary: GroupPhaseColors.steelblue,
                ),
            inputDecorationTheme: const InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: GroupPhaseColors.steelblue, width: 2),
              ),
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: GroupPhaseColors.steelblue,
              selectionColor: Color(0x404682B4),
              selectionHandleColor: GroupPhaseColors.steelblue,
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Teams & Gruppen'),
              backgroundColor: TreeColors.rebeccapurple,
              foregroundColor: Colors.white,
              actions: [
                if (_hasUnsavedChanges)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Center(
                      child: Text(
                        '• Ungespeichert',
                        style: TextStyle(
                          color: Colors.amber,
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
        .where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty)
        .length;
    final activeCount =
        _teamControllers.where((c) => !c.markedForRemoval).length;
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
        modeColor = GroupPhaseColors.steelblue;
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
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

          if (!isLocked) ...[
            // Teams count row
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
                    size: isMobile ? 20 : 24,
                    color: GroupPhaseColors.steelblue),
                SizedBox(width: isMobile ? 8 : 12),
                Text(
                  'Gruppen:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                SizedBox(
                  width: isMobile ? 55 : 60,
                  child: DropdownButtonFormField<int>(
                    value: 6,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 6 : 8),
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(8, (i) => i + 1).map((count) {
                      final isEnabled = count == 6;
                      return DropdownMenuItem(
                        value: count,
                        enabled: isEnabled,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : null,
                            color: isEnabled ? null : Colors.grey,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: null,
                  ),
                ),
                const SizedBox(width: 12),
                // Show locked 24 teams badge for group+KO
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GroupPhaseColors.steelblue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            GroupPhaseColors.steelblue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock,
                          size: 12, color: GroupPhaseColors.steelblue),
                      SizedBox(width: 4),
                      Text(
                        '24 Teams',
                        style: TextStyle(
                          color: GroupPhaseColors.steelblue,
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: _clearGroups,
                          icon: const Icon(Icons.clear, size: 20),
                          color: GroupPhaseColors.cupred,
                          tooltip: 'Gruppen leeren',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _assignGroupsRandomly,
                          icon: const Icon(Icons.casino, size: 20),
                          color: GroupPhaseColors.steelblue,
                          tooltip: 'Zufällig zuweisen',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _clearGroups,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Leeren'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GroupPhaseColors.cupred,
                            side: const BorderSide(
                                color: GroupPhaseColors.cupred),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _assignGroupsRandomly,
                          icon: const Icon(Icons.casino, size: 18),
                          label: const Text('Zufällig'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GroupPhaseColors.steelblue,
                            foregroundColor: Colors.white,
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
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Turnier gestartet - Teams können nicht mehr bearbeitet werden',
                      style: TextStyle(color: Colors.amber),
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
    final activeControllers =
        _teamControllers.where((c) => !c.markedForRemoval).toList();
    if (activeControllers.isEmpty && !_isRoundRobin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Wähle oben die Anzahl der Teams',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teamControllers.length + (_isRoundRobin && !isLocked ? 1 : 0),
      itemBuilder: (context, index) {
        // "Add Team" button at the end for round-robin
        if (index == _teamControllers.length) {
          return Padding(
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
          );
        }

        final controller = _teamControllers[index];
        if (controller.markedForRemoval) {
          return const SizedBox.shrink();
        }
        return _buildTeamRow(index, controller, showGroups, isLocked, isMobile);
      },
    );
  }

  Widget _buildTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked,
    bool isMobile,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isMobile
            ? _buildMobileTeamRow(index, controller, showGroups, isLocked)
            : _buildDesktopTeamRow(index, controller, showGroups, isLocked),
      ),
    );
  }

  Widget _buildDesktopTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: TreeColors.rebeccapurple,
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
        if (showGroups) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int?>(
              value: controller.groupIndex,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                  child: Text('-', style: TextStyle(color: Colors.grey)),
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
          if (_isRoundRobin) IconButton(
                  onPressed: () => _removeTeamEntry(index),
                  icon: const Icon(Icons.delete_outline),
                  color: GroupPhaseColors.cupred,
                  tooltip: 'Team löschen',
                ) else IconButton(
                  onPressed: () => _clearTeamFields(index),
                  icon: const Icon(Icons.backspace_outlined),
                  color: Colors.orange,
                  tooltip: 'Felder leeren',
                ),
        ],
      ],
    );
  }

  Widget _buildMobileTeamRow(
    int index,
    TeamEditController controller,
    bool showGroups,
    bool isLocked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: TreeColors.rebeccapurple,
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
            if (!isLocked)
              _isRoundRobin
                  ? IconButton(
                      onPressed: () => _removeTeamEntry(index),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: GroupPhaseColors.cupred,
                    )
                  : IconButton(
                      onPressed: () => _clearTeamFields(index),
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      color: Colors.orange,
                    ),
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
        if (showGroups) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: controller.groupIndex,
            decoration: const InputDecoration(
              labelText: 'Gruppe',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(
                child:
                    Text('Keine Gruppe', style: TextStyle(color: Colors.grey)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
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
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichern...' : 'Alle speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasUnsavedChanges
                      ? FieldColors.springgreen
                      : Colors.grey,
                  foregroundColor: Colors.white,
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

/// Controller for a single team's edit fields
class TeamEditController {
  String? id;
  final TextEditingController nameController;
  final TextEditingController member1Controller;
  final TextEditingController member2Controller;
  int? groupIndex;
  bool isNew;
  bool markedForRemoval;

  TeamEditController({
    this.id,
    String name = '',
    String member1 = '',
    String member2 = '',
    this.groupIndex,
    this.isNew = true,
    this.markedForRemoval = false,
  })  : nameController = TextEditingController(text: name),
        member1Controller = TextEditingController(text: member1),
        member2Controller = TextEditingController(text: member2);

  void dispose() {
    nameController.dispose();
    member1Controller.dispose();
    member2Controller.dispose();
  }
}
