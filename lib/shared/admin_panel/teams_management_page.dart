import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pongstrong/shared/admin_panel/admin_panel_state.dart';
import 'package:pongstrong/shared/colors.dart';

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
  int _targetTeamCount = 8;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Clear existing controllers
    for (var controller in _teamControllers) {
      controller.dispose();
    }
    _teamControllers.clear();

    // Create controllers for existing teams
    for (var team in widget.adminState.teams) {
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

    // Update target count to match existing teams
    if (_teamControllers.isNotEmpty) {
      _targetTeamCount = _teamControllers.length;
    }

    _hasUnsavedChanges = false;
  }

  void _setTeamCount(int count) {
    setState(() {
      _targetTeamCount = count;

      // Add new empty slots if needed
      while (_teamControllers.length < count) {
        _teamControllers.add(TeamEditController(
          id: null,
          name: '',
          member1: '',
          member2: '',
          groupIndex: null,
          isNew: true,
        ));
      }

      // Mark for removal if we have too many (but keep them visible until save)
      for (int i = 0; i < _teamControllers.length; i++) {
        _teamControllers[i].markedForRemoval = i >= count;
      }

      _hasUnsavedChanges = true;
    });
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveAllTeams() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final state = widget.adminState;

      // Get current team IDs for comparison
      final existingTeamIds = state.teams.map((t) => t.id).toSet();

      // Process each controller
      for (int i = 0; i < _teamControllers.length; i++) {
        final controller = _teamControllers[i];

        if (controller.markedForRemoval) {
          // Delete team if it exists in Firebase
          if (controller.id != null &&
              existingTeamIds.contains(controller.id)) {
            await state.deleteTeam(controller.id!);
          }
          continue;
        }

        // Skip empty entries
        if (controller.nameController.text.trim().isEmpty) {
          continue;
        }

        if (controller.isNew || controller.id == null) {
          // Add new team
          final success = await state.addTeam(
            name: controller.nameController.text.trim(),
            member1: controller.member1Controller.text.trim(),
            member2: controller.member2Controller.text.trim(),
          );

          if (success && state.teams.isNotEmpty) {
            // Update controller with the new team's ID
            controller.id = state.teams.last.id;
            controller.isNew = false;
          }
        } else {
          // Update existing team
          await state.updateTeam(
            teamId: controller.id!,
            name: controller.nameController.text.trim(),
            member1: controller.member1Controller.text.trim(),
            member2: controller.member2Controller.text.trim(),
          );
        }

        // Handle group assignment
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

      // Remove controllers marked for removal
      _teamControllers.removeWhere((c) => c.markedForRemoval);

      // Refresh controllers from state
      await state.loadTeams();
      await state.loadGroups();
      _initializeControllers();

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
    // First save any unsaved changes
    if (_hasUnsavedChanges) {
      await _saveAllTeams();
    }

    final success = await widget.adminState.assignGroupsRandomly();
    if (success) {
      // Update controllers with new group assignments
      for (var controller in _teamControllers) {
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
            child: const Text('Abbrechen'),
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
      // Update controllers
      for (var controller in _teamControllers) {
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
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Verwerfen',
              style: TextStyle(color: GroupPhaseColors.cupred),
            ),
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
              backgroundColor: FieldColors.springgreen,
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
    for (var controller in _teamControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGroupPhase =
        widget.adminState.tournamentStyle == TournamentStyle.groupsAndKnockouts;
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
                // Top controls
                _buildTopControls(isLocked, isGroupPhase, isMobile),

                // Teams list
                Expanded(
                  child: _buildTeamsList(isGroupPhase, isLocked, isMobile),
                ),

                // Bottom save bar
                _buildBottomBar(isLocked),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(bool isLocked, bool isGroupPhase, bool isMobile) {
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
          // Team count selector
          if (!isLocked) ...[
            if (isMobile)
              // Mobile: Compact two-row layout
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups,
                          size: 20, color: TreeColors.rebeccapurple),
                      const SizedBox(width: 8),
                      Text(
                        'Teams:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: DropdownButtonFormField<int>(
                          value: _targetTeamCount,
                          isDense: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(32, (i) => i + 2).map((count) {
                            return DropdownMenuItem(
                              value: count,
                              child: Text('$count',
                                  style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) _setTeamCount(value);
                          },
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              TreeColors.rebeccapurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_teamControllers.where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty).length}/$_targetTeamCount',
                          style: const TextStyle(
                            color: TreeColors.rebeccapurple,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              )
            else
              // Desktop: Single row layout
              Row(
                children: [
                  const Icon(Icons.groups, color: TreeColors.rebeccapurple),
                  const SizedBox(width: 12),
                  const Text(
                    'Anzahl Teams:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<int>(
                      value: _targetTeamCount,
                      isDense: true,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(32, (i) => i + 2).map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) _setTeamCount(value);
                      },
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TreeColors.rebeccapurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_teamControllers.where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty).length} / $_targetTeamCount ausgefüllt',
                      style: const TextStyle(
                        color: TreeColors.rebeccapurple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            if (!isMobile) const SizedBox(height: 16),
          ],

          // Group controls (only if group phase selected)
          if (isGroupPhase) ...[
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
                    value: 6, // Fixed to 6 - only implemented group mode
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 6 : 8),
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(8, (i) => i + 1).map((count) {
                      final isEnabled = count == 6; // Only 6 groups implemented
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
                    onChanged: null, // Disabled - only 6 groups is implemented
                  ),
                ),
                const Spacer(),
                if (!isLocked) ...[
                  if (isMobile)
                    // Mobile: Icon-only buttons
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
                    // Desktop: Full buttons
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

  Widget _buildTeamsList(bool isGroupPhase, bool isLocked, bool isMobile) {
    if (_teamControllers.isEmpty) {
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
      itemCount: _teamControllers.length,
      itemBuilder: (context, index) {
        final controller = _teamControllers[index];
        if (controller.markedForRemoval) {
          return const SizedBox.shrink();
        }
        return _buildTeamRow(
            index, controller, isGroupPhase, isLocked, isMobile);
      },
    );
  }

  Widget _buildTeamRow(
    int index,
    TeamEditController controller,
    bool isGroupPhase,
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
            ? _buildMobileTeamRow(index, controller, isGroupPhase, isLocked)
            : _buildDesktopTeamRow(index, controller, isGroupPhase, isLocked),
      ),
    );
  }

  Widget _buildDesktopTeamRow(
    int index,
    TeamEditController controller,
    bool isGroupPhase,
    bool isLocked,
  ) {
    return Row(
      children: [
        // Index badge
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

        // Team name
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

        // Member 1
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

        // Member 2
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

        // Group selector (if group phase)
        if (isGroupPhase) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int?>(
              value: controller.groupIndex,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
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

        // Delete button
        if (!isLocked) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                controller.markedForRemoval = true;
                _hasUnsavedChanges = true;
              });
            },
            icon: const Icon(Icons.delete_outline),
            color: GroupPhaseColors.cupred,
            tooltip: 'Team entfernen',
          ),
        ],
      ],
    );
  }

  Widget _buildMobileTeamRow(
    int index,
    TeamEditController controller,
    bool isGroupPhase,
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
              IconButton(
                onPressed: () {
                  setState(() {
                    controller.markedForRemoval = true;
                    _hasUnsavedChanges = true;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                color: GroupPhaseColors.cupred,
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
        if (isGroupPhase) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: controller.groupIndex,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Gruppe',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
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
            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_teamControllers.where((c) => !c.markedForRemoval && c.nameController.text.isNotEmpty).length} Teams',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.adminState.tournamentStyle ==
                      TournamentStyle.groupsAndKnockouts)
                    Text(
                      '${_teamControllers.where((c) => !c.markedForRemoval && c.groupIndex != null).length} mit Gruppe',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Save button
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
    required this.id,
    required String name,
    required String member1,
    required String member2,
    required this.groupIndex,
    required this.isNew,
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
