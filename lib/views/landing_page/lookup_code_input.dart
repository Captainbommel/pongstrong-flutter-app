import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/join_code.dart';
import 'package:pongstrong/utils/text_formatters.dart';

/// A text field + button row for joining a tournament by code.
///
/// Validates and looks up the entered code, then calls [onTournamentSelected]
/// with the resolved tournament ID on success.
class LookupCodeInput extends StatefulWidget {
  final void Function(String tournamentId) onTournamentSelected;

  const LookupCodeInput({super.key, required this.onTournamentSelected});

  @override
  State<LookupCodeInput> createState() => _LookupCodeInputState();
}

class _LookupCodeInputState extends State<LookupCodeInput> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _codeController = TextEditingController();
  String? _codeError;
  bool _isLookingUpCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: JoinCode.codeLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            cursorColor: GroupPhaseColors.steelblue,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: AppColors.textDisabled.withAlpha(100),
              ),
              counterText: '',
              errorText: _codeError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: GroupPhaseColors.steelblue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 2),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
            onSubmitted: (_) => _lookupCode(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _isLookingUpCode ? null : _lookupCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.steelblue,
              foregroundColor: AppColors.textOnColored,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _isLookingUpCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textOnColored),
                    ),
                  )
                : const Text(
                    'Beitreten',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _lookupCode() async {
    final code = JoinCode.normalise(_codeController.text);
    if (!JoinCode.isValid(code)) {
      setState(
          () => _codeError = 'Bitte gib einen gültigen 4-stelligen Code ein');
      return;
    }

    setState(() {
      _codeError = null;
      _isLookingUpCode = true;
    });

    final tournamentId = await _firestoreService.findTournamentByCode(code);

    if (!mounted) return;

    if (tournamentId == null) {
      setState(() {
        _isLookingUpCode = false;
        _codeError = 'Kein Turnier mit diesem Code gefunden';
      });
      return;
    }

    setState(() => _isLookingUpCode = false);
    widget.onTournamentSelected(tournamentId);
  }
}
