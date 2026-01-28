import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

//TODO: resposiveness needs to be improved

/// Landing page content that adapts to mobile and desktop layouts
class LandingPage extends StatefulWidget {
  final bool isDesktop;

  const LandingPage({super.key, required this.isDesktop});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late Future<List<String>> _tournamentsFuture;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingTournament = false;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _firestoreService.listTournaments();
  }

  Future<void> _onTournamentSelected(String tournamentId) async {
    if (!mounted) return;

    setState(() => _isLoadingTournament = true);

    final success =
        await Provider.of<TournamentDataState>(context, listen: false)
            .loadTournamentData(tournamentId);

    if (mounted) {
      if (success) {
        Provider.of<TournamentSelectionState>(context, listen: false)
            .setSelectedTournament(tournamentId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load tournament data'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingTournament = false);
      }
    }
  }

  void _showCreateTournamentDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateTournamentDialog(),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const LoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: widget.isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - Hero section
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FieldColors.backgroundblue,
                  FieldColors.skyblue.withAlpha(180),
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(isLarge: true),
                    const SizedBox(height: 32),
                    _buildDescription(isLarge: true),
                    const SizedBox(height: 48),
                    _buildFeaturesList(),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Right side - Actions
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLoginButton(isLarge: true),
                    const SizedBox(height: 48),
                    _buildTournamentSelection(isLarge: true),
                    const SizedBox(height: 32),
                    _buildCreateTournamentButton(isLarge: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FieldColors.backgroundblue,
                  FieldColors.skyblue.withAlpha(180),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildLoginButton(isLarge: false),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLogo(isLarge: false),
                  const SizedBox(height: 24),
                  _buildDescription(isLarge: false),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Actions section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTournamentSelection(isLarge: false),
                const SizedBox(height: 24),
                _buildCreateTournamentButton(isLarge: false),
                const SizedBox(height: 32),
                _buildFeaturesList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo({required bool isLarge}) {
    return Column(
      crossAxisAlignment:
          isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_baseball,
              size: isLarge ? 64 : 48,
              color: GroupPhaseColors.cupred,
            ),
            const SizedBox(width: 16),
            Text(
              'PONGSTRONG',
              style: TextStyle(
                fontSize: isLarge ? 48 : 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Turnier Manager',
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            color: Colors.black54,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription({required bool isLarge}) {
    return Text(
      'Organisiere und verwalte deine Bierpong-Turniere mit Leichtigkeit. '
      'Verfolge Punkte, verwalte Spielpläne und halte den Wettbewerb am Laufen!',
      style: TextStyle(
        fontSize: isLarge ? 18 : 16,
        color: Colors.black87,
        height: 1.5,
      ),
      textAlign: isLarge ? TextAlign.start : TextAlign.center,
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.groups, 'text': 'Gruppenphase verwalten'},
      {'icon': Icons.account_tree, 'text': 'Turnierbaum Ansicht'},
      {'icon': Icons.leaderboard, 'text': 'Live Punkteverfolgung'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.cupred.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: GroupPhaseColors.cupred,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                feature['text'] as String,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoginButton({required bool isLarge}) {
    if (isLarge) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _showLoginDialog,
          icon: const Icon(Icons.login),
          label: const Text('Veranstalter Login'),
          style: OutlinedButton.styleFrom(
            foregroundColor: GroupPhaseColors.cupred,
            side: const BorderSide(color: GroupPhaseColors.cupred),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      );
    } else {
      return TextButton.icon(
        onPressed: _showLoginDialog,
        icon: const Icon(Icons.login, size: 20),
        label: const Text('Login'),
        style: TextButton.styleFrom(
          foregroundColor: GroupPhaseColors.cupred,
        ),
      );
    }
  }

  Widget _buildTournamentSelection({required bool isLarge}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: GroupPhaseColors.steelblue,
                size: isLarge ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Turnier beitreten',
                style: TextStyle(
                  fontSize: isLarge ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Wähle ein bestehendes Turnier um Punkte und Spielpläne zu sehen:',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildTournamentList(),
        ],
      ),
    );
  }

  Widget _buildTournamentList() {
    return FutureBuilder<List<String>>(
      future: _tournamentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading tournaments: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Keine Turniere verfügbar. Erstelle eines um loszulegen!',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          );
        }

        if (_isLoadingTournament) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Turnier wird geladen...'),
                ],
              ),
            ),
          );
        }

        return Column(
          children: tournaments.map((tournamentId) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _onTournamentSelected(tournamentId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GroupPhaseColors.steelblue.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.sports_esports,
                            color: GroupPhaseColors.steelblue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tournamentId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tippen zum Beitreten',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCreateTournamentButton({required bool isLarge}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showCreateTournamentDialog,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Neues Turnier erstellen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: GroupPhaseColors.cupred,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: 32,
            vertical: isLarge ? 20 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Dialog for creating a new tournament (visual mockup)
class CreateTournamentDialog extends StatefulWidget {
  const CreateTournamentDialog({super.key});

  @override
  State<CreateTournamentDialog> createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<CreateTournamentDialog> {
  int _currentStep = 0;
  final _tournamentNameController = TextEditingController();
  String _selectedFormat = 'groups_knockout';
  int _numberOfTeams = 8;
  int _numberOfTables = 2;
  bool _obscurePassword = true;

  // Custom input decoration with red focus color
  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GroupPhaseColors.cupred, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
    );
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 500;

    return Dialog(
      child: Container(
        width: isWide ? 500 : double.infinity,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  _buildStepIndicator(1, 'Einstellungen'),
                  _buildStepConnector(1),
                  _buildStepIndicator(2, 'Anmelden'),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStepContent(),
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
                  if (_currentStep < 2)
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
                      onPressed: () {
                        // TODO: Implement actual tournament creation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Turniererstellung wird später implementiert'),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildSettingsStep();
      case 2:
        return _buildLoginStep();
      default:
        return const SizedBox();
    }
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
          decoration: _buildInputDecoration(
            labelText: 'Turniername',
            hintText: 'z.B. BMT-Cup 2026',
            prefixIcon: Icons.emoji_events,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Turnierformat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildFormatOption(
          'groups_knockout',
          'Gruppenphase + K.O.-Runde',
          'Teams spielen in Gruppen, die Besten kommen in die K.O.-Runde',
          Icons.grid_view,
        ),
        _buildFormatOption(
          'knockout_only',
          'Nur K.O.-Runde',
          'Einfaches Ausscheidungsturnier',
          Icons.account_tree,
        ),
        _buildFormatOption(
          'round_robin',
          'Jeder gegen Jeden',
          'Jedes Team spielt gegen jedes andere Team',
          Icons.loop,
        ),
      ],
    );
  }

  Widget _buildFormatOption(
    String value,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedFormat == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: isSelected
            ? GroupPhaseColors.cupred.withAlpha(20)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedFormat = value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected ? GroupPhaseColors.cupred : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? GroupPhaseColors.cupred
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? GroupPhaseColors.cupred
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: GroupPhaseColors.cupred),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Turnier Einstellungen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Anzahl der Teams',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _numberOfTeams > 4
                    ? () => setState(() => _numberOfTeams--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: GroupPhaseColors.cupred,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_numberOfTeams',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _numberOfTeams < 32
                    ? () => setState(() => _numberOfTeams++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: GroupPhaseColors.cupred,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Anzahl der Tische',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _numberOfTables > 1
                    ? () => setState(() => _numberOfTables--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: GroupPhaseColors.cupred,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_numberOfTables',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _numberOfTables < 10
                    ? () => setState(() => _numberOfTables++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: GroupPhaseColors.cupred,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Anmelden zum Erstellen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Melde dich an um dein Turnier zu speichern und zu verwalten',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        TextField(
          cursorColor: GroupPhaseColors.cupred,
          decoration: _buildInputDecoration(
            labelText: 'E-Mail',
            prefixIcon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          obscureText: _obscurePassword,
          cursorColor: GroupPhaseColors.cupred,
          decoration: _buildInputDecoration(
            labelText: 'Passwort',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () {
              // TODO: Implement create account
            },
            style: TextButton.styleFrom(
              foregroundColor: GroupPhaseColors.steelblue,
            ),
            child: const Text('Noch kein Konto? Registrieren'),
          ),
        ),
      ],
    );
  }
}

/// Login dialog for returning tournament creators
class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _obscurePassword = true;

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: GroupPhaseColors.cupred, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
    );
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
                    color: GroupPhaseColors.cupred.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.login,
                    color: GroupPhaseColors.cupred,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Veranstalter Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Zugang zu deinen Turnieren',
                        style: TextStyle(color: Colors.grey),
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
            TextField(
              cursorColor: GroupPhaseColors.cupred,
              decoration: _buildInputDecoration(
                labelText: 'E-Mail',
                prefixIcon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: _obscurePassword,
              cursorColor: GroupPhaseColors.cupred,
              decoration: _buildInputDecoration(
                labelText: 'Passwort',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement forgot password
                },
                style: TextButton.styleFrom(
                  foregroundColor: GroupPhaseColors.steelblue,
                ),
                child: const Text('Passwort vergessen?'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement login
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Login wird später implementiert'),
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GroupPhaseColors.cupred,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Anmelden',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // TODO: Navigate to sign up
              },
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.steelblue,
              ),
              child: const Text('Noch kein Konto? Registrieren'),
            ),
          ],
        ),
      ),
    );
  }
}
