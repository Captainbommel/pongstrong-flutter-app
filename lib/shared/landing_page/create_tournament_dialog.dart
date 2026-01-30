import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/shared/auth_state.dart';
import 'package:pongstrong/shared/colors.dart';
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
  bool _isLoginMode = false;

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
    // Validate current step
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

  Future<void> _createTournament() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    // Validate account fields
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

    // Now create the tournament
    final tournamentId = await _firestoreService.createTournament(
      tournamentName: _tournamentNameController.text.trim(),
      creatorId: authState.userId!,
      creatorEmail: authState.userEmail!,
      password: _passwordController.text,
    );

    if (mounted) {
      if (tournamentId != null) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnier "$tournamentId" wurde erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Ein Turnier mit diesem Namen existiert bereits';
        });
      }
    }
  }

  Future<void> _createTournamentAsLoggedInUser(AuthState authState) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final tournamentId = await _firestoreService.createTournament(
      tournamentName: _tournamentNameController.text.trim(),
      creatorId: authState.userId!,
      creatorEmail: authState.userEmail!,
      password: _passwordController.text,
    );

    if (mounted) {
      if (tournamentId != null) {
        Navigator.pop(context);
        widget.onTournamentCreated(tournamentId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Turnier "$tournamentId" wurde erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Ein Turnier mit diesem Namen existiert bereits';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;
    final authState = Provider.of<AuthState>(context);

    // If user is already logged in, we can skip the account step
    final isAlreadyLoggedIn = authState.isEmailUser;

    return Dialog(
      child: Container(
        width: isWide ? 500 : double.infinity,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: GroupPhaseColors.cupred,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Neues Turnier erstellen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(20),
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Zurück'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GroupPhaseColors.cupred,
                        side: const BorderSide(color: GroupPhaseColors.cupred),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    )
                  else
                    const SizedBox(),
                  if (_currentStep == 0)
                    ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Weiter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GroupPhaseColors.cupred,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : isAlreadyLoggedIn
                              ? () => _createTournamentAsLoggedInUser(authState)
                              : _createTournament,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Turnier erstellen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
              color: isActive ? GroupPhaseColors.cupred : Colors.grey.shade300,
              border: isCurrent
                  ? Border.all(color: GroupPhaseColors.cupred, width: 2)
                  : null,
            ),
            child: Center(
              child: isActive && !isCurrent
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey,
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
              color: isActive ? Colors.black87 : Colors.grey,
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
      color: isActive ? GroupPhaseColors.cupred : Colors.grey.shade300,
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tournamentNameController,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Turniername',
            hintText: 'z.B. BMT-Cup 2026',
            prefixIcon: const Icon(Icons.emoji_events),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Turnier-Passwort',
            hintText: 'Passwort für andere Spieler',
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
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dieses Passwort teilst du mit allen Spielern, damit sie dem Turnier beitreten können.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
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
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
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
              _buildSummaryItem('Passwort', '••••••'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nach dem Erstellen wirst du automatisch dem Turnier beitreten.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isLoginMode ? 'Anmelden' : 'Konto erstellen',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isLoginMode = !_isLoginMode;
                _error = null;
              }),
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.steelblue,
              ),
              child: Text(_isLoginMode
                  ? 'Neues Konto erstellen'
                  : 'Ich habe bereits ein Konto'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginMode
              ? 'Melde dich mit deinem bestehenden Konto an'
              : 'Erstelle ein Konto um dein Turnier zu verwalten',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          cursorColor: GroupPhaseColors.cupred,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-Mail',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _accountPasswordController,
          obscureText: _obscureAccountPassword,
          cursorColor: GroupPhaseColors.cupred,
          decoration: InputDecoration(
            labelText: 'Passwort',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: () => setState(
                  () => _obscureAccountPassword = !_obscureAccountPassword),
              icon: Icon(
                _obscureAccountPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: GroupPhaseColors.cupred, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
          ),
        ),
        if (!_isLoginMode) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            cursorColor: GroupPhaseColors.cupred,
            decoration: InputDecoration(
              labelText: 'Passwort bestätigen',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: GroupPhaseColors.cupred, width: 2),
              ),
              floatingLabelStyle:
                  const TextStyle(color: GroupPhaseColors.cupred),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Zusammenfassung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSummaryItem(
                  'Turniername', _tournamentNameController.text.trim()),
              _buildSummaryItem('Turnier-Passwort', '••••••'),
            ],
          ),
        ),
      ],
    );
  }
}
