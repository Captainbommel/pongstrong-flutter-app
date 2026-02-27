import 'package:flutter/material.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/input_decoration_helpers.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';

/// Login dialog for returning tournament creators
class LoginDialog extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginDialog({super.key, this.onLoginSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  final _confirmPasswordController = TextEditingController();
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = Provider.of<AuthState>(context, listen: false);

    if (_isRegisterMode) {
      final success = await authState.createAccount(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
          SnackBarHelper.showSuccess(context, 'Konto erfolgreich erstellt!');
        } else {
          SnackBarHelper.showError(
              context, authState.error ?? 'Registrierung fehlgeschlagen');
        }
      }
    } else {
      final success = await authState.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
          SnackBarHelper.showSuccess(context, 'Erfolgreich angemeldet!');
        } else {
          SnackBarHelper.showError(
              context, authState.error ?? 'Anmeldung fehlgeschlagen');
        }
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      SnackBarHelper.showWarning(context, 'Bitte gib deine E-Mail ein');
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    final success =
        await authState.sendPasswordReset(_emailController.text.trim());

    if (mounted) {
      if (success) {
        SnackBarHelper.showSuccess(
            context, 'Passwort-Reset E-Mail wurde gesendet');
      } else {
        SnackBarHelper.showError(
            context, authState.error ?? 'Fehler beim Senden der E-Mail');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 400;
    final authState = Provider.of<AuthState>(context);

    return Dialog(
      insetPadding: isWide
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                    color: GroupPhaseColors.cupred.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isRegisterMode ? Icons.person_add : Icons.login,
                    color: GroupPhaseColors.cupred,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRegisterMode
                            ? 'Konto erstellen'
                            : 'Veranstalter Login',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegisterMode
                            ? 'Erstelle ein neues Konto'
                            : 'Zugang zu deinen Turnieren',
                        style: const TextStyle(color: AppColors.textDisabled),
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
            // Form
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    cursorColor: GroupPhaseColors.cupred,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte gib eine E-Mail ein';
                      }
                      if (!value.contains('@')) {
                        return 'Bitte gib eine gültige E-Mail ein';
                      }
                      return null;
                    },
                    decoration: cupredInputDecoration(
                      label: 'E-Mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    cursorColor: GroupPhaseColors.cupred,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte gib ein Passwort ein';
                      }
                      if (_isRegisterMode && value.length < 6) {
                        return 'Passwort muss mindestens 6 Zeichen lang sein';
                      }
                      return null;
                    },
                    decoration: cupredInputDecoration(
                      label: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      cursorColor: GroupPhaseColors.cupred,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwörter stimmen nicht überein';
                        }
                        return null;
                      },
                      decoration: cupredInputDecoration(
                        label: 'Passwort bestätigen',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isRegisterMode) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: GroupPhaseColors.steelblue,
                  ),
                  child: const Text('Passwort vergessen?'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupPhaseColors.cupred,
                  foregroundColor: AppColors.textOnColored,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnColored,
                        ),
                      )
                    : Text(
                        _isRegisterMode ? 'Registrieren' : 'Anmelden',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRegisterMode = !_isRegisterMode;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.steelblue,
              ),
              child: Text(_isRegisterMode
                  ? 'Bereits ein Konto? Anmelden'
                  : 'Noch kein Konto? Registrieren'),
            ),
          ],
        ),
      ),
    );
  }
}
