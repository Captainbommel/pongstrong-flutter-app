import 'package:pongstrong/views/admin/team_edit_controller.dart';

/// Lightweight immutable snapshot of a [TeamEditController]'s data.
///
/// Used to diff the current UI state against a previously saved state so that
/// only the teams that actually changed are written back to the database.
class TeamSnapshot {
  final String? id;
  final String name;
  final List<String> members;
  final int? groupIndex;
  final bool isReserve;

  const TeamSnapshot({
    required this.id,
    required this.name,
    required this.members,
    required this.groupIndex,
    required this.isReserve,
  });

  /// Capture the current state of a [TeamEditController].
  factory TeamSnapshot.fromController(TeamEditController c) {
    return TeamSnapshot(
      id: c.id,
      name: c.nameController.text.trim(),
      members: c.memberValues,
      groupIndex: c.groupIndex,
      isReserve: c.isReserve,
    );
  }

  /// Whether the team data (name, members, group, reserve) matches [other].
  bool dataEquals(TeamSnapshot other) =>
      name == other.name &&
      groupIndex == other.groupIndex &&
      isReserve == other.isReserve &&
      listEquals(members, other.members);

  /// Element-wise equality check for two string lists.
  static bool listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
