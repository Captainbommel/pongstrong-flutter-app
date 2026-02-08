import 'package:flutter/material.dart';
import 'package:pongstrong/state/app_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/views/admin/admin_panel_page.dart';
import 'package:pongstrong/views/playing_field_view.dart';
import 'package:pongstrong/views/rules_view.dart';
import 'package:pongstrong/views/teams_view.dart';
import 'package:pongstrong/views/tree_view.dart';
import 'package:pongstrong/views/mobile_drawer.dart';
import 'package:pongstrong/widgets/confirmation_dialog.dart';
import 'package:provider/provider.dart';

/// Unified responsive app shell that replaces the separate DesktopApp and
/// MobileApp widgets.
///
/// On large screens: AppBar with text-button navigation + body.
/// On small screens: Drawer-based navigation + PageView with swipe support.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late PageController _pageController;
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Hide swipe hint after 3 seconds (mobile only)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSwipeHint = false);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showBackConfirmationDialog(BuildContext context) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Turnier verlassen?',
      content: const Text('Möchtest du wirklich zurück zur Turnierübersicht?'),
      confirmText: 'Zurück',
    );

    if (confirmed == true && context.mounted) {
      Provider.of<AuthState>(context, listen: false).clearTournamentRole();
      Provider.of<TournamentSelectionState>(context, listen: false)
          .clearSelectedTournament();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 940;

    return isLargeScreen
        ? _buildDesktopShell(context)
        : _buildMobileShell(context);
  }

  // ---------- Desktop Layout ----------

  Widget _buildDesktopShell(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final authState = Provider.of<AuthState>(context);
    final tournamentData = Provider.of<TournamentDataState>(context);

    // If user is not admin but on admin view, redirect to playing field
    if (!authState.isAdmin && appState.currentView == AppView.adminPanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.setView(AppView.playingField);
      });
    }

    // Determine which tabs to show based on tournament style and phase
    final isKnockoutsOnly = tournamentData.tournamentStyle == 'knockoutsOnly';
    final isEveryoneVsEveryone =
        tournamentData.tournamentStyle == 'everyoneVsEveryone';
    final isKnockoutPhase = tournamentData.isKnockoutMode;
    final rulesEnabled = tournamentData.rulesEnabled;
    final hasStarted =
        tournamentData.hasData; // Only show game tabs if tournament has data

    final showGroupPhase = hasStarted &&
        !isKnockoutsOnly; // Show in group+KO and everyoneVsEveryone
    final showTournamentTree = hasStarted &&
        !isEveryoneVsEveryone &&
        (isKnockoutsOnly || isKnockoutPhase);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Zurück zur Übersicht',
          onPressed: () => _showBackConfirmationDialog(context),
        ),
        title: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _navButton(context, 'Spielfeld', AppView.playingField),
                    const SizedBox(width: 8),
                    if (showGroupPhase) ...[
                      _navButton(context, 'Gruppenphase', AppView.groupPhase),
                      const SizedBox(width: 8),
                    ],
                    if (showTournamentTree) ...[
                      _navButton(
                          context, 'Turnierbaum', AppView.tournamentTree),
                      const SizedBox(width: 8),
                    ],
                    if (rulesEnabled) ...[
                      _navButton(context, 'Regeln', AppView.rules),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            // Admin button - only for tournament creator, aligned to the right
            Consumer<AuthState>(
              builder: (context, authState, child) {
                if (!authState.isAdmin) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: TextButton.icon(
                    onPressed: () => appState.setView(AppView.adminPanel),
                    icon: const Icon(Icons.settings,
                        color: GroupPhaseColors.cupred, size: 20),
                    label: const Text(
                      'Turnierverwaltung',
                      style: TextStyle(
                        color: GroupPhaseColors.cupred,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),
      body: _buildBodyForView(appState.currentView),
    );
  }

  Widget _navButton(BuildContext context, String label, AppView view) {
    return TextButton(
      onPressed: () =>
          Provider.of<AppState>(context, listen: false).setView(view),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ---------- Mobile Layout ----------

  Widget _buildMobileShell(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final authState = Provider.of<AuthState>(context);
    final tournamentData = Provider.of<TournamentDataState>(context);
    final selectedTournament =
        Provider.of<TournamentSelectionState>(context).selectedTournamentId;

    final isAdmin = authState.isAdmin;

    // Determine which tabs to show
    final isKnockoutsOnly = tournamentData.tournamentStyle == 'knockoutsOnly';
    final isEveryoneVsEveryone =
        tournamentData.tournamentStyle == 'everyoneVsEveryone';
    final isKnockoutPhase = tournamentData.isKnockoutMode;
    final rulesEnabled = tournamentData.rulesEnabled;
    final hasStarted = tournamentData.hasData;

    final showGroupPhase = hasStarted && !isKnockoutsOnly;
    final showTournamentTree = hasStarted &&
        !isEveryoneVsEveryone &&
        (isKnockoutsOnly || isKnockoutPhase);

    // Build page list dynamically
    final pages = <Widget>[
      _buildPageWithHint(const PlayingFieldView(), showHint: true),
      if (showGroupPhase) const SingleChildScrollView(child: TeamsView()),
      if (showTournamentTree) const TreeViewPage(),
      if (rulesEnabled) const SingleChildScrollView(child: RulesView()),
      if (isAdmin) const AdminPanelPage(),
    ];

    final pageCount = pages.length;

    // Sync PageView with state changes from drawer
    final targetView = appState.currentView;
    // If non-admin is somehow on the admin view, redirect to playing field
    final effectiveView = (!isAdmin && targetView == AppView.adminPanel)
        ? AppView.playingField
        : targetView;
    final currentPage = AppState.pageIndexFromView(effectiveView);

    if (_pageController.hasClients &&
        _pageController.page?.round() != currentPage) {
      _pageController.jumpToPage(currentPage.clamp(0, pageCount - 1));
    }

    return Scaffold(
      key: appState.scaffoldKey,
      drawer: const MobileDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        title: Text(selectedTournament ?? 'BMT-Cup'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => appState.setViewFromPageIndex(index),
        children: pages,
      ),
    );
  }

  Widget _buildPageWithHint(Widget content, {bool showHint = false}) {
    if (!showHint || !_showSwipeHint) {
      return content;
    }

    return Stack(
      children: [
        content,
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _showSwipeHint ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(153),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Wischen zum Navigieren',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Shared ----------

  Widget _buildBodyForView(AppView view) {
    switch (view) {
      case AppView.playingField:
        return const PlayingFieldView();
      case AppView.groupPhase:
        return const TeamsView();
      case AppView.tournamentTree:
        return const TreeViewPage();
      case AppView.rules:
        return const RulesView();
      case AppView.adminPanel:
        return const AdminPanelPage();
    }
  }
}
