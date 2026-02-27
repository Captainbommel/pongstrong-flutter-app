import 'package:flutter/material.dart';
import 'package:pongstrong/models/team.dart';

/// Controller for a single team's edit fields in the teams management page.
///
/// Holds [TextEditingController]s for team name and a dynamic list of member
/// name controllers (2 by default, up to [Team.maxMembers]).
class TeamEditController {
  String? id;
  final TextEditingController nameController;
  final List<TextEditingController> memberControllers;
  int? groupIndex;
  bool isNew;
  bool markedForRemoval;
  bool isReserve;

  TeamEditController({
    this.id,
    String name = '',
    List<String>? members,
    this.groupIndex,
    this.isNew = true,
    this.markedForRemoval = false,
    this.isReserve = false,
  })  : nameController = TextEditingController(text: name),
        memberControllers = _buildMemberControllers(members);

  /// Builds the initial member controllers list.
  /// Always starts with at least [Team.defaultMemberCount] entries.
  static List<TextEditingController> _buildMemberControllers(
      List<String>? members) {
    final list = <TextEditingController>[];
    final count = (members?.length ?? 0) < Team.defaultMemberCount
        ? Team.defaultMemberCount
        : members!.length;
    for (int i = 0; i < count; i++) {
      list.add(TextEditingController(
        text: (members != null && i < members.length) ? members[i] : '',
      ));
    }
    return list;
  }

  /// Returns member values as a list, trimming trailing empty entries.
  List<String> get memberValues =>
      memberControllers.map((c) => c.text.trim()).toList();

  /// Returns a display string of non-empty member names joined by ' & '.
  String get membersText => memberControllers
      .map((c) => c.text)
      .where((s) => s.isNotEmpty)
      .join(' & ');

  /// Whether another member field can be added.
  bool get canAddMember => memberControllers.length < Team.maxMembers;

  /// Whether a member field can be removed (keeps minimum [Team.defaultMemberCount]).
  bool get canRemoveMember =>
      memberControllers.length > Team.defaultMemberCount;

  /// Adds a new empty member controller. Returns true if successful.
  bool addMemberField() {
    if (!canAddMember) return false;
    memberControllers.add(TextEditingController());
    return true;
  }

  /// Removes the last member controller. Returns true if successful.
  bool removeMemberField() {
    if (!canRemoveMember) return false;
    memberControllers.removeLast().dispose();
    return true;
  }

  void dispose() {
    nameController.dispose();
    for (final c in memberControllers) {
      c.dispose();
    }
  }
}
