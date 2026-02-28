import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/teams_management/team_edit_controller.dart';

/// Callback signatures for team row actions.
typedef TeamRowCallback = void Function(int index);

/// A unified team row widget used for both desktop and mobile layouts.
///
/// Renders the team's number badge, name/members info area,
/// an optional group dropdown, and action buttons.
class TeamRowWidget extends StatelessWidget {
  final int index;
  final TeamEditController controller;
  final bool showGroups;
  final bool isLocked;
  final bool isMobile;
  final bool isRoundRobin;
  final int? displayNumber;
  final int numberOfGroups;
  final Map<int, int> groupCounts;
  final int activeTeamCount;
  final int? Function(int?) clampGroupIndex;
  final VoidCallback onEdit;
  final TeamRowCallback onMoveToReserve;
  final TeamRowCallback onPromoteToActive;
  final TeamRowCallback onRemove;
  final TeamRowCallback onClear;
  final void Function(int index, int? groupIndex) onGroupChanged;

  const TeamRowWidget({
    super.key,
    required this.index,
    required this.controller,
    required this.showGroups,
    required this.isLocked,
    required this.isMobile,
    required this.isRoundRobin,
    this.displayNumber,
    required this.numberOfGroups,
    required this.groupCounts,
    required this.activeTeamCount,
    required this.clampGroupIndex,
    required this.onEdit,
    required this.onMoveToReserve,
    required this.onPromoteToActive,
    required this.onRemove,
    required this.onClear,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
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
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final isReserve = controller.isReserve;
    final hasName = controller.nameController.text.isNotEmpty;

    return Row(
      children: [
        _buildBadge(size: 36),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: _buildTeamInfo(hasName, isReserve)),
        if (showGroups && !isReserve) ...[
          const SizedBox(width: 12),
          SizedBox(width: 140, child: _buildGroupDropdown(compact: true)),
        ],
        if (!isLocked) ...[
          const SizedBox(width: 8),
          ..._buildActionButtons(isReserve, compact: false),
        ],
      ],
    );
  }

  Widget _buildMobileLayout() {
    final isReserve = controller.isReserve;
    final hasName = controller.nameController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildBadge(size: 32, fontSize: 14),
            const SizedBox(width: 8),
            Expanded(child: _buildTeamInfo(hasName, isReserve)),
            if (!isLocked)
              ..._buildActionButtons(isReserve, iconSize: 20, compact: true),
          ],
        ),
        if (showGroups && !isReserve) ...[
          const SizedBox(height: 8),
          _buildGroupDropdown(compact: false),
        ],
      ],
    );
  }

  Widget _buildBadge({required double size, double? fontSize}) {
    final isReserve = controller.isReserve;
    final color = isReserve ? AppColors.grey500 : TreeColors.rebeccapurple;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size < 36 ? 6 : 8),
      ),
      child: Center(
        child: Text(
          '${displayNumber ?? (index + 1)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamInfo(bool hasName, bool isReserve) {
    final membersText = controller.membersText;
    return InkWell(
      onTap: isLocked ? null : onEdit,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 8 : 10,
        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (membersText.isNotEmpty)
                          Text(
                            membersText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    )
                  : Text(
                      isMobile
                          ? 'Leerer Slot – tippen'
                          : 'Leerer Slot – tippen zum Bearbeiten',
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
            ),
            if (!isLocked)
              Icon(Icons.edit,
                  size: isMobile ? 14 : 16, color: AppColors.textSubtle),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown({required bool compact}) {
    final groupCount = numberOfGroups;
    final idealSize =
        groupCount > 0 ? (activeTeamCount / groupCount).ceil() : 0;
    final currentGroup = clampGroupIndex(controller.groupIndex);

    final noGroupLabel = compact ? '-' : 'Keine Gruppe';
    String groupLabel(int i) => compact
        ? String.fromCharCode(65 + i)
        : 'Gruppe ${String.fromCharCode(65 + i)}';

    return DropdownButtonFormField<int?>(
      value: currentGroup,
      isExpanded: !compact,
      decoration: InputDecoration(
        labelText: 'Gruppe',
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: 12,
        ),
      ),
      selectedItemBuilder: (context) => [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(noGroupLabel,
              style: const TextStyle(color: AppColors.textDisabled)),
        ),
        ...List.generate(
            groupCount,
            (i) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(groupLabel(i)),
                )),
      ],
      items: [
        DropdownMenuItem(
          child: Text(noGroupLabel,
              style: const TextStyle(color: AppColors.textDisabled)),
        ),
        ...List.generate(groupCount, (i) {
          final count = groupCounts[i] ?? 0;
          final isFull = count >= idealSize && currentGroup != i;
          return DropdownMenuItem(
            value: i,
            enabled: !isFull,
            child: Text(
              '${groupLabel(i)} ($count/$idealSize)',
              style: TextStyle(
                color: isFull ? AppColors.textDisabled : null,
              ),
            ),
          );
        }),
      ],
      onChanged: isLocked ? null : (value) => onGroupChanged(index, value),
    );
  }

  List<Widget> _buildActionButtons(
    bool isReserve, {
    double? iconSize,
    required bool compact,
  }) {
    final constraints =
        compact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null;
    final padding = compact ? EdgeInsets.zero : null;

    if (isReserve) {
      return [
        IconButton(
          onPressed: () => onPromoteToActive(index),
          icon: Icon(Icons.arrow_upward, size: iconSize),
          color: FieldColors.springgreen,
          tooltip: compact ? 'Ins Turnier' : 'Ins Turnier hochstufen',
          padding: padding,
          constraints: constraints,
        ),
        IconButton(
          onPressed: () => onRemove(index),
          icon: Icon(Icons.delete_outline, size: iconSize),
          color: GroupPhaseColors.cupred,
          tooltip: 'Entfernen',
          padding: padding,
          constraints: constraints,
        ),
      ];
    }

    return [
      if (!isRoundRobin)
        IconButton(
          onPressed: () => onMoveToReserve(index),
          icon: Icon(Icons.arrow_downward, size: iconSize),
          color: AppColors.warning,
          tooltip: 'Auf Ersatzbank',
          padding: padding,
          constraints: constraints,
        ),
      if (isRoundRobin)
        IconButton(
          onPressed: () => onRemove(index),
          icon: Icon(Icons.delete_outline, size: iconSize),
          color: GroupPhaseColors.cupred,
          tooltip: 'Team löschen',
          padding: padding,
          constraints: constraints,
        )
      else
        IconButton(
          onPressed: () => onClear(index),
          icon: Icon(Icons.backspace_outlined, size: iconSize),
          color: AppColors.warning,
          tooltip: 'Felder leeren',
          padding: padding,
          constraints: constraints,
        ),
    ];
  }
}
