import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/utils/colors.dart';

/// Reusable dialog for editing a finished match score.
/// Returns a `{score1: int, score2: int}` map on confirm, or null on cancel.
///
/// Set [isKnockout] to true to show the cascade-reset warning.
class MatchEditDialog extends StatefulWidget {
  final Match match;
  final String team1Name;
  final String team2Name;
  final bool isKnockout;

  const MatchEditDialog({
    super.key,
    required this.match,
    required this.team1Name,
    required this.team2Name,
    this.isKnockout = false,
  });

  /// Convenience helper – call from anywhere that has a [BuildContext].
  static Future<Map<String, int>?> show(
    BuildContext context, {
    required Match match,
    required String team1Name,
    required String team2Name,
    bool isKnockout = false,
  }) {
    return showDialog<Map<String, int>>(
      context: context,
      builder: (_) => MatchEditDialog(
        match: match,
        team1Name: team1Name,
        team2Name: team2Name,
        isKnockout: isKnockout,
      ),
    );
  }

  @override
  State<MatchEditDialog> createState() => _MatchEditDialogState();
}

class _MatchEditDialogState extends State<MatchEditDialog> {
  late TextEditingController _score1Controller;
  late TextEditingController _score2Controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _score1Controller =
        TextEditingController(text: widget.match.score1.toString());
    _score2Controller =
        TextEditingController(text: widget.match.score2.toString());
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ergebnis bearbeiten'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isKnockout) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Das Bearbeiten dieses Spiels setzt alle '
                        'nachfolgenden Spiele zurück.',
                        style:
                            TextStyle(color: AppColors.warning, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Team names and scores in aligned columns
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team 1 column
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.team1Name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _scoreField(_score1Controller),
                    ],
                  ),
                ),
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 24), // Align with team names
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: GroupPhaseColors.cupred,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Team 2 column
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.team2Name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      _scoreField(_score2Controller),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Abbrechen',
            style: TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: GroupPhaseColors.cupred,
            foregroundColor: AppColors.textOnColored,
          ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _scoreField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: GroupPhaseColors.cupred,
      ),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: GroupPhaseColors.steelblue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: GroupPhaseColors.cupred,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        filled: true,
        fillColor: AppColors.grey50,
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Erforderlich' : null,
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'score1': int.parse(_score1Controller.text),
        'score2': int.parse(_score2Controller.text),
      });
    }
  }
}
