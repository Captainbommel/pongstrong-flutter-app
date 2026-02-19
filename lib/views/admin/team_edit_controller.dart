import 'package:flutter/material.dart';

/// Controller for a single team's edit fields in the teams management page.
///
/// Holds [TextEditingController]s for team name and both member names,
/// along with metadata like group assignment and edit state tracking.
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
