import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/input_decoration_helpers.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:provider/provider.dart';

/// Dialog for creating a new tournament
class CreateTournamentDialog extends StatefulWidget {
  final Function(String tournamentId) onTournamentCreated;

  const CreateTournamentDialog({
    super.key,
    required this.onTournamentCreated,
  });

  @override
  State<CreateTournamentDialog> createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<CreateTournamentDialog> {
  int _currentStep = 0;
  final _tournamentNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _obscurePassword = true;
  bool _obscureAccountPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _error;
  bool _isLoginMode = true;

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _accountPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_tournamentNameController.text.trim().isEmpty) {
        setState(() => _error = 'Bitte gib einen Turniernamen ein');
        return;
      }
      if (_passwordController.text.isEmpty) {
        setState(() => _error = 'Bitte gib ein Turnier-Passwort ein');
        return;
      }
    }

    setState(() {
      _error = null;
      _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _error = null;
        _currentStep--;
      });
    }
  }

  // ─── Shared UI helpers ───

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      cursorColor: GroupPhaseColors.cupred,
      decoration: cupredInputDecoration(
        label: label,
        hint: hint,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: AppColors.info)),
          ),
        ],
      ),
    );
  }

  /// Shared logic: create the tournament on Firestore and handle result.
  Future<void> _submitTournament(String creatorId) async {
    final tournamentId = await _firestoreService.createTournament(
      tournamentName: _tournamentNameController.text.trim(),
      creatorId: creatorId,
      password: _passwordController.text,
    );

    if (mounted) {
      if (tournamentId != null) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
        SnackBarHelper.showSuccess(
            context, 'Turnier "$tournamentId" wurde erstellt!');
      } else {
        setState(() {
          _isLoading = false;
          _error =
              'Turnier konnte nicht erstellt werden. Möglicherweise existiert bereits ein Turnier mit diesem Namen.';
        });
      }
    }
  }

  Future<void> _createTournament() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Bitte gib eine E-Mail ein');
      return;
    }
    if (_accountPasswordController.text.isEmpty) {
      setState(() => _error = 'Bitte gib ein Passwort ein');
      return;
    }

    if (!_isLoginMode) {
      if (_accountPasswordController.text != _confirmPasswordController.text) {
        setState(() => _error = 'Passwörter stimmen nicht überein');
        return;
      }
      if (_accountPasswordController.text.length < 6) {
        setState(() => _error = 'Passwort muss mindestens 6 Zeichen lang sein');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    bool authSuccess;
    if (_isLoginMode) {
      authSuccess = await authState.signInWithEmail(
        _emailController.text.trim(),
        _accountPasswordController.text,
      );
    } else {
      authSuccess = await authState.createAccount(
        _emailController.text.trim(),
        _accountPasswordController.text,
      );
    }

    if (!authSuccess) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = authState.error ?? 'Authentifizierung fehlgeschlagen';
        });
      }
      return;
    }

    await _submitTournament(authState.userId!);
  }

  Future<void> _createTournamentAsLoggedInUser(AuthState authState) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _submitTournament(authState.userId!);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 400;
    final isVerySmall = !isWide;
    final authState = Provider.of<AuthState>(context);

    final isAlreadyLoggedIn = authState.isEmailUser;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: GroupPhaseColors.cupred,
          selectionColor: GroupPhaseColors.cupred.withAlpha(80),
          selectionHandleColor: GroupPhaseColors.cupred,
        ),
      ),
      child: Dialog(
        insetPadding: isWide
            ? const EdgeInsets.symmetric(horizontal: 40, vertical: 24)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: isWide ? 500 : double.infinity,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: GroupPhaseColors.cupred,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle,
                        color: AppColors.textOnColored),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Neues Turnier erstellen',
                        style: TextStyle(
                          color: AppColors.textOnColored,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppColors.textOnColored),
                    ),
                  ],
                ),
              ),
              // Step indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildStepIndicator(0, 'Details'),
                    _buildStepConnector(0),
                    _buildStepIndicator(
                        1, isAlreadyLoggedIn ? 'Bestätigen' : 'Konto'),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _currentStep == 0
                      ? _buildDetailsStep()
                      : isAlreadyLoggedIn
                          ? _buildConfirmStep(authState)
                          : _buildAccountStep(),
                ),
              ),
              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.grey200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _previousStep,
                        style: TextButton.styleFrom(
                          foregroundColor: GroupPhaseColors.cupred,
                        ),
                        child: const Text('Zurück'),
                      )
                    else
                      const SizedBox(),
                    if (_currentStep == 0)
                      TextButton(
                        onPressed: _nextStep,
                        style: TextButton.styleFrom(
                          foregroundColor: GroupPhaseColors.cupred,
                        ),
                        child: const Text('Weiter'),
                      )
                    else
                      _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    GroupPhaseColors.cupred),
                              ),
                            )
                          : TextButton(
                              onPressed: isAlreadyLoggedIn
                                  ? () =>
                                      _createTournamentAsLoggedInUser(authState)
                                  : _createTournament,
                              style: TextButton.styleFrom(
                                foregroundColor: GroupPhaseColors.cupred,
                              ),
                              child: Text(
                                isVerySmall ? 'Erstellen' : 'Turnier erstellen',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? GroupPhaseColors.cupred : AppColors.grey300,
              border: isCurrent
                  ? Border.all(color: GroupPhaseColors.cupred, width: 2)
                  : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? const Icon(Icons.check,
                      color: AppColors.textOnColored, size: 18)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive
                            ? AppColors.textOnColored
                            : AppColors.textDisabled,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.textPrimary : AppColors.textDisabled,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isActive = _currentStep > step;

    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? GroupPhaseColors.cupred : AppColors.grey300,
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tournamentNameController,
          cursorColor: GroupPhaseColors.cupred,
          decoration: cupredInputDecoration(
            label: 'Turniername',
            hint: 'z.B. BMT-Cup 2026',
            prefixIcon: const Icon(Icons.emoji_events),
          ),
        ),
        const SizedBox(height: 20),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Turnier-Passwort',
          hint: 'Passwort für andere Spieler',
          obscure: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 12),
        _buildInfoBox(
          'Dieses Passwort teilst du mit allen Spielern, damit sie dem Turnier beitreten können.',
        ),
        const SizedBox(height: 12),
        _buildInfoBox(
          'Dein Turnier erhält zusätzlich einen Beitrittscode, mit dem Spieler das Turnier finden können.',
        ),
      ],
    );
  }

  Widget _buildConfirmStep(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier erstellen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.successBorder),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Bereit zum Erstellen!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryItem(
                  'Turniername', _tournamentNameController.text.trim()),
              _buildSummaryItem('Ersteller', authState.userEmail ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoBox(
          'Nach dem Erstellen wirst du automatisch dem Turnier beitreten.',
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDisabled)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text(
                'Turnier:',
                style: TextStyle(color: AppColors.textDisabled),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _tournamentNameController.text.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isLoginMode ? 'Anmelden' : 'Konto erstellen',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginMode
              ? 'Melde dich mit deinem bestehenden Konto an'
              : 'Erstelle ein Konto um dein Turnier zu verwalten',
          style: const TextStyle(color: AppColors.textDisabled),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          cursorColor: GroupPhaseColors.cupred,
          keyboardType: TextInputType.emailAddress,
          decoration: cupredInputDecoration(
            label: 'E-Mail',
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _accountPasswordController,
          label: 'Passwort',
          obscure: _obscureAccountPassword,
          onToggle: () => setState(
              () => _obscureAccountPassword = !_obscureAccountPassword),
        ),
        if (!_isLoginMode) ...[
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Passwort bestätigen',
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              _isLoginMode = !_isLoginMode;
              _error = null;
            }),
            style: TextButton.styleFrom(
              foregroundColor: GroupPhaseColors.steelblue,
            ),
            child: Text(
              _isLoginMode
                  ? 'Neues Konto erstellen'
                  : 'Ich habe bereits ein Konto',
            ),
          ),
        ),
      ],
    );
  }
}
