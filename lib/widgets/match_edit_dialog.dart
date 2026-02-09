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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Das Bearbeiten dieses Spiels setzt alle '
                        'nachfolgenden Spiele zurück.',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Team names row
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.team1Name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    widget.team2Name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Score inputs row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  child: _scoreField(_score1Controller),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: _scoreField(_score2Controller),
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
            foregroundColor: Colors.white,
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
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
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
