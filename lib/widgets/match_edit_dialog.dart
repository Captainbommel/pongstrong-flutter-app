import 'package:flutter/material.dart';
import 'package:pongstrong/models/match/match.dart';
import 'package:pongstrong/models/match/scoring.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/playing_field/match_dialogs.dart';
import 'package:pongstrong/widgets/info_banner.dart';

/// Dialog for editing a match score.
///
/// Shows two score input fields with team names and validates scores using
/// [isValid]. In knockout mode, warns that editing resets subsequent matches.
///
/// Returns `{'score1': int, 'score2': int}` on confirm, or `null` on dismiss.
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
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _score1Controller =
        TextEditingController(text: widget.match.score1.toString());
    _score2Controller =
        TextEditingController(text: widget.match.score2.toString());
    _score1Controller.addListener(_clearValidationError);
    _score2Controller.addListener(_clearValidationError);
  }

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  @override
  void dispose() {
    _score1Controller.removeListener(_clearValidationError);
    _score2Controller.removeListener(_clearValidationError);
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
              const InfoBanner(
                text: 'Das Bearbeiten dieses Spiels setzt alle '
                    'nachfolgenden Spiele zurück.',
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
            ],
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _validationError!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            _scoreRow(),
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

  Widget _scoreRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _teamColumn(widget.team1Name, _score1Controller),
        _scoreSeparator(),
        _teamColumn(widget.team2Name, _score2Controller),
      ],
    );
  }

  Widget _teamColumn(String teamName, TextEditingController controller) {
    return Expanded(
      child: Column(
        children: [
          Text(
            teamName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _scoreField(controller),
        ],
      ),
    );
  }

  Widget _scoreSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 36),
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
    );
  }

  Widget _scoreField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [CupsTextInputFormatter()],
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
      validator: (value) {
        if (value == null || value.isEmpty) return 'Erforderlich';
        if (int.tryParse(value) == null) return 'Ungültige Zahl';
        return null;
      },
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final score1 = int.parse(_score1Controller.text);
      final score2 = int.parse(_score2Controller.text);

      if (!isValid(score1, score2)) {
        setState(() {
          _validationError = 'Ungültiges Ergebnis. Bitte gültiges '
              'Spielergebnis eingeben.';
        });
        return;
      }

      Navigator.of(context).pop({
        'score1': score1,
        'score2': score2,
      });
    }
  }
}
