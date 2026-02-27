import 'package:flutter/material.dart';
import 'package:pongstrong/models/team.dart';
import 'package:pongstrong/utils/colors.dart';

/// Result from [TeamFormDialog] when the user confirms.
class TeamFormResult {
  final String name;
  final List<String> members;

  const TeamFormResult({required this.name, required this.members});
}

/// A reusable dialog for adding or editing a team's name and members.
///
/// Returns a [TeamFormResult] on confirmation, or `null` if cancelled.
class TeamFormDialog extends StatefulWidget {
  /// Dialog title (e.g. 'Team hinzufügen' or 'Team bearbeiten').
  final String title;

  /// Confirm button label.
  final String confirmLabel;

  /// Initial team name (empty for a new team).
  final String initialName;

  /// Initial member names.
  final List<String> initialMembers;

  const TeamFormDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
    this.initialMembers = const [],
  });

  /// Shows the dialog and returns the result.
  static Future<TeamFormResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialName = '',
    List<String> initialMembers = const [],
  }) {
    return showDialog<TeamFormResult>(
      context: context,
      builder: (_) => TeamFormDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialName: initialName,
        initialMembers: initialMembers,
      ),
    );
  }

  @override
  State<TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<TeamFormDialog> {
  late final TextEditingController _nameController;
  late final List<TextEditingController> _memberControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);

    final memberCount = widget.initialMembers.length < Team.defaultMemberCount
        ? Team.defaultMemberCount
        : widget.initialMembers.length;
    _memberControllers = List.generate(memberCount, (i) {
      final text =
          i < widget.initialMembers.length ? widget.initialMembers[i] : '';
      return TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Teamname *',
                border: OutlineInputBorder(),
              ),
            ),
            for (int i = 0; i < _memberControllers.length; i++) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _memberControllers[i],
                decoration: InputDecoration(
                  labelText: 'Spieler ${i + 1}',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (_memberControllers.length > Team.defaultMemberCount)
                  IconButton(
                    onPressed: () => setState(() {
                      _memberControllers.last.dispose();
                      _memberControllers.removeLast();
                    }),
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                const Spacer(),
                if (_memberControllers.length < Team.maxMembers)
                  IconButton(
                    onPressed: () => setState(() {
                      _memberControllers.add(TextEditingController());
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(TeamFormResult(
              name: _nameController.text.trim(),
              members: _memberControllers.map((c) => c.text.trim()).toList(),
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: TreeColors.rebeccapurple,
            foregroundColor: AppColors.textOnColored,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
