import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/shared/colors.dart';

/// Dialog for entering tournament password
class TournamentPasswordDialog extends StatefulWidget {
  final String tournamentId;
  final VoidCallback onSuccess;

  const TournamentPasswordDialog({
    super.key,
    required this.tournamentId,
    required this.onSuccess,
  });

  @override
  State<TournamentPasswordDialog> createState() =>
      _TournamentPasswordDialogState();
}

class _TournamentPasswordDialogState extends State<TournamentPasswordDialog> {
  final _passwordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Bitte Passwort eingeben');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isValid = await _firestoreService.verifyTournamentPassword(
      widget.tournamentId,
      _passwordController.text,
    );

    if (mounted) {
      if (isValid) {
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Falsches Passwort';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;

    return Dialog(
      child: Container(
        width: isWide ? 400 : double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GroupPhaseColors.steelblue.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: GroupPhaseColors.steelblue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Turnier beitreten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.tournamentId,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Password field
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: GroupPhaseColors.cupred,
              onSubmitted: (_) => _verifyPassword(),
              decoration: InputDecoration(
                labelText: 'Turnier-Passwort',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: GroupPhaseColors.cupred, width: 2),
                ),
                floatingLabelStyle:
                    const TextStyle(color: GroupPhaseColors.cupred),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupPhaseColors.cupred,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Beitreten',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
