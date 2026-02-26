import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/widgets/match_edit_dialog.dart';
import 'package:provider/provider.dart';

/// Describes one visible bracket tab.
class _BracketEntry {
  final BracketKey key;
  final String name;
  final Color color;
  final List<List<Match>>? rounds; // null for super cup
  final bool isSuperCup;

  const _BracketEntry({
    required this.key,
    required this.name,
    required this.color,
    this.rounds,
    this.isSuperCup = false,
  });
}

class TreeViewPage extends StatefulWidget {
  final ValueChanged<bool>? onExploreChanged;

  const TreeViewPage({super.key, this.onExploreChanged});

  @override
  TreeViewPageState createState() => TreeViewPageState();
}

class TreeViewPageState extends State<TreeViewPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedIndex = 0;
  bool _isExploring = false;
  bool _showTableNumbers = false;
  int _lastBracketCount = 0;

  // Cached graph data to avoid rebuilding on every frame
  final Map<String, _CachedGraph> _graphCache = {};

  // Colors for each bracket key
  static const Map<BracketKey, Color> _bracketColors = {
    BracketKey.gold: TreeColors.rebeccapurple,
    BracketKey.silver: TreeColors.royalblue,
    BracketKey.bronze: TreeColors.bronze,
    BracketKey.extra: TreeColors.hotpink,
  };

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Checks whether a KnockoutBracket has meaningful data.
  bool _bracketHasData(KnockoutBracket bracket) {
    if (bracket.rounds.isEmpty) return false;
    if (bracket.rounds[0].isEmpty) return false;
    return bracket.rounds[0][0].teamId1.isNotEmpty ||
        bracket.rounds[0][0].teamId2.isNotEmpty;
  }

  /// Checks whether the Super Cup has meaningful data.
  bool _superCupHasData(Super superCup) {
    if (superCup.matches.length < 2) return false;
    return superCup.matches[0].teamId1.isNotEmpty ||
        superCup.matches[0].teamId2.isNotEmpty ||
        superCup.matches[1].teamId1.isNotEmpty ||
        superCup.matches[1].teamId2.isNotEmpty;
  }

  /// Builds the list of visible bracket entries based on actual data.
  List<_BracketEntry> _getVisibleBrackets(Knockouts knockouts) {
    final entries = <_BracketEntry>[];

    // Champions is always shown if it has data
    if (_bracketHasData(knockouts.champions)) {
      entries.add(_BracketEntry(
        key: BracketKey.gold,
        name: knockouts.getBracketName(BracketKey.gold),
        color: _bracketColors[BracketKey.gold]!,
        rounds: knockouts.champions.rounds,
      ));
    }

    if (_bracketHasData(knockouts.europa)) {
      entries.add(_BracketEntry(
        key: BracketKey.silver,
        name: knockouts.getBracketName(BracketKey.silver),
        color: _bracketColors[BracketKey.silver]!,
        rounds: knockouts.europa.rounds,
      ));
    }

    if (_bracketHasData(knockouts.conference)) {
      entries.add(_BracketEntry(
        key: BracketKey.bronze,
        name: knockouts.getBracketName(BracketKey.bronze),
        color: _bracketColors[BracketKey.bronze]!,
        rounds: knockouts.conference.rounds,
      ));
    }

    if (_superCupHasData(knockouts.superCup)) {
      entries.add(_BracketEntry(
        key: BracketKey.extra,
        name: knockouts.getBracketName(BracketKey.extra),
        color: _bracketColors[BracketKey.extra]!,
        isSuperCup: true,
      ));
    }

    return entries;
  }

  void _ensureTabController(int count) {
    if (_tabController == null || _lastBracketCount != count) {
      _tabController?.dispose();
      _selectedIndex = _selectedIndex.clamp(0, (count - 1).clamp(0, count));
      _tabController = TabController(
        length: count,
        vsync: this,
        initialIndex: _selectedIndex,
      );
      _tabController!.addListener(() {
        if (_tabController!.index != _selectedIndex) {
          setState(() => _selectedIndex = _tabController!.index);
        }
      });
      _lastBracketCount = count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentData = Provider.of<TournamentDataState>(context);
    final knockouts = tournamentData.knockouts;
    final isAdmin = Provider.of<AuthState>(context).isAdmin;
    final isLargeScreen = MediaQuery.sizeOf(context).width > 940;

    final visibleBrackets = _getVisibleBrackets(knockouts);

    if (visibleBrackets.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Keine Daten verfügbar',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    _ensureTabController(visibleBrackets.length);
    // Clamp in case brackets shrunk
    if (_selectedIndex >= visibleBrackets.length) {
      _selectedIndex = visibleBrackets.length - 1;
    }

    return Scaffold(
      body: Column(
        children: [
          if (isLargeScreen)
            // Desktop: Show TabBar
            ColoredBox(
              color: AppColors.grey100,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.shadow,
                      indicatorColor:
                          visibleBrackets[_tabController!.index].color,
                      indicatorWeight: 4,
                      tabs: [
                        for (final b in visibleBrackets)
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(b.name),
                                if (isAdmin) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showRenameDialog(
                                        b.key, b.name, b.color),
                                    child: const Icon(Icons.edit,
                                        size: 14, color: AppColors.grey500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            // Mobile: Show Dropdown
            Container(
              color: AppColors.grey100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<int>(
                value: _selectedIndex,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: visibleBrackets[_selectedIndex].color,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: visibleBrackets[_selectedIndex].color,
                      width: 2,
                    ),
                  ),
                  suffixIcon: isAdmin
                      ? IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showRenameDialog(
                            visibleBrackets[_selectedIndex].key,
                            visibleBrackets[_selectedIndex].name,
                            visibleBrackets[_selectedIndex].color,
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 72),
                ),
                dropdownColor: AppColors.surface,
                focusColor: AppColors.transparent,
                items: [
                  for (int i = 0; i < visibleBrackets.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(visibleBrackets[i].name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedIndex = value;
                    });
                  }
                },
              ),
            ),
          // Table numbers toggle (mobile)
          if (!isLargeScreen)
            Container(
              color: AppColors.grey100,
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 7),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: Checkbox(
                      value: _showTableNumbers,
                      activeColor: visibleBrackets[_selectedIndex].color,
                      onChanged: (v) {
                        setState(() => _showTableNumbers = v ?? false);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showTableNumbers = !_showTableNumbers),
                    child: const Text(
                      'Tische anzeigen',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLargeScreen
                ? Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: [
                          for (final b in visibleBrackets)
                            b.isSuperCup
                                ? _buildSuperCupTree(knockouts)
                                : _buildTournamentTree(
                                    b.key, b.rounds!, b.color),
                        ],
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.surface,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: visibleBrackets[_tabController!.index]
                                    .color
                                    .withAlpha(120),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(
                                  () => _showTableNumbers = !_showTableNumbers),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _showTableNumbers,
                                        activeColor: visibleBrackets[
                                                _tabController!.index]
                                            .color,
                                        onChanged: (v) => setState(() =>
                                            _showTableNumbers = v ?? false),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Tische anzeigen',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildMobileTreeWithOverlay(knockouts, visibleBrackets),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
      BracketKey bracketKey, String currentName, Color bracketColor) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: bracketColor,
            selectionColor: bracketColor.withValues(alpha: 0.3),
            selectionHandleColor: bracketColor,
          ),
        ),
        child: AlertDialog(
          title: Text(
            'Liga umbenennen',
            style: TextStyle(color: bracketColor),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: bracketColor,
            decoration: InputDecoration(
              hintText: 'Neuer Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: bracketColor,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Abbrechen',
                style: TextStyle(color: bracketColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: bracketColor,
                foregroundColor: AppColors.textOnColored,
              ),
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      if (mounted) {
        final success =
            await Provider.of<TournamentDataState>(context, listen: false)
                .updateBracketName(bracketKey, newName);
        if (mounted) {
          if (success) {
            SnackBarHelper.showSuccess(context, 'Name geändert');
          } else {
            SnackBarHelper.showError(context, 'Fehler beim Umbenennen');
          }
        }
      }
    }
  }

  void _setExploring(bool value) {
    setState(() => _isExploring = value);
    widget.onExploreChanged?.call(value);
  }

  Widget _buildMobileTreeWithOverlay(
      Knockouts knockouts, List<_BracketEntry> visibleBrackets) {
    final currentBracket = visibleBrackets[_selectedIndex];
    return Stack(
      children: [
        // Tree content (always rendered, interactive only when exploring)
        IgnorePointer(
          ignoring: !_isExploring,
          child: currentBracket.isSuperCup
              ? _buildSuperCupTree(knockouts)
              : _buildTournamentTree(
                  currentBracket.key,
                  currentBracket.rounds!,
                  currentBracket.color,
                ),
        ),
        // Blur overlay when not exploring
        if (!_isExploring) ...[
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: Container(
                  color: AppColors.surface.withAlpha(80),
                ),
              ),
            ),
          ),
          // "Explore" button centered
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _setExploring(true),
              icon: const Icon(Icons.zoom_in),
              label: const Text('Erkunden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentBracket.color,
                foregroundColor: AppColors.textOnColored,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        // "Back" button when exploring
        if (_isExploring)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () => _setExploring(false),
              backgroundColor: AppColors.shadow.withAlpha(150),
              foregroundColor: AppColors.textOnColored,
              child: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }

  Widget _buildTournamentTree(
    BracketKey bracketKey,
    List<List<Match>> rounds,
    Color color,
  ) {
    // Guard: no rounds or all rounds empty → show placeholder
    if (rounds.isEmpty || rounds.every((r) => r.isEmpty)) {
      return const Center(
        child: Text(
          'Keine Daten verfügbar',
          style: TextStyle(fontSize: 18, color: AppColors.textSubtle),
        ),
      );
    }

    // Use cached graph or build a new one
    final cacheKey = bracketKey.name;
    final matchCount = rounds.fold<int>(0, (sum, round) => sum + round.length);
    var cached = _graphCache[cacheKey];
    if (cached == null || cached.matchCount != matchCount) {
      final graph = Graph()..isTree = true;
      final nodes = <String, Node>{};

      for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
        for (int matchIndex = 0;
            matchIndex < rounds[roundIndex].length;
            matchIndex++) {
          final matchId = 'r${roundIndex}_m$matchIndex';
          nodes[matchId] = Node.Id(matchId);
        }
      }

      for (int roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
        for (int matchIndex = 0;
            matchIndex < rounds[roundIndex].length;
            matchIndex++) {
          final currentMatch = 'r${roundIndex}_m$matchIndex';
          final nextMatch = 'r${roundIndex + 1}_m${matchIndex ~/ 2}';
          graph.addEdge(nodes[nextMatch]!, nodes[currentMatch]!);
        }
      }

      final builder = BuchheimWalkerConfiguration()
        ..siblingSeparation = 25
        ..levelSeparation = 50
        ..subtreeSeparation = 50
        ..orientation = BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT;

      cached =
          _CachedGraph(graph: graph, config: builder, matchCount: matchCount);
      _graphCache[cacheKey] = cached;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 1.0,
        maxScale: 1.0,
        child: GraphView(
          graph: cached.graph,
          algorithm: BuchheimWalkerAlgorithm(
              cached.config, TreeEdgeRenderer(cached.config)),
          paint: Paint()
            ..color = color.withAlpha(76)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final nodeId = node.key?.value as String;

            final parts = nodeId.split('_');
            final roundIndex = int.parse(parts[0].substring(1));
            final matchIndex = int.parse(parts[1].substring(1));
            final match = rounds[roundIndex][matchIndex];

            return _buildMatchNode(match, color);
          },
        ),
      ),
    );
  }

  Widget _buildMatchNode(Match match, Color borderColor) {
    // Access the team data from the provider
    final tournamentData =
        Provider.of<TournamentDataState>(context, listen: false);
    final isAdmin = Provider.of<AuthState>(context, listen: false).isAdmin;

    // Get team names or fallback to IDs
    String getTeamName(String teamId) {
      if (teamId.isEmpty) return '';
      final team = tournamentData.getTeam(teamId);
      return team?.name ?? teamId;
    }

    // Determine if match is ready (both teams are assigned)
    final bool isReady = match.teamId1.isNotEmpty && match.teamId2.isNotEmpty;
    final bool canEdit = isAdmin && match.done;

    return InkWell(
      onTap: canEdit
          ? () => _onEditKnockoutMatch(
                context,
                match,
                getTeamName(match.teamId1),
                getTeamName(match.teamId2),
              )
          : null,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isReady ? borderColor : borderColor.withAlpha(76),
            width: isReady ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showTableNumbers && match.tableNumber > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: TableColors.forIndex(match.tableNumber - 1)
                            .withAlpha(38),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: TableColors.forIndex(match.tableNumber - 1),
                        ),
                      ),
                      child: Text(
                        'Tisch ${match.tableNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: TableColors.forIndex(match.tableNumber - 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    getTeamName(match.teamId1),
                    textAlign: match.done ? TextAlign.start : TextAlign.center,
                    style: TextStyle(
                      fontWeight:
                          match.done && match.getWinnerId() == match.teamId1
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color: match.teamId1.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.shadow,
                    ),
                  ),
                ),
                if (match.done) Text('${match.score1}'),
              ],
            ),
            const Divider(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    getTeamName(match.teamId2),
                    textAlign: match.done ? TextAlign.start : TextAlign.center,
                    style: TextStyle(
                      fontWeight:
                          match.done && match.getWinnerId() == match.teamId2
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color: match.teamId2.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.shadow,
                    ),
                  ),
                ),
                if (match.done) Text('${match.score2}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEditKnockoutMatch(
    BuildContext context,
    Match match,
    String team1Name,
    String team2Name,
  ) async {
    final result = await MatchEditDialog.show(
      context,
      match: match,
      team1Name: team1Name,
      team2Name: team2Name,
      isKnockout: true,
    );
    if (result != null && context.mounted) {
      final tournamentData =
          Provider.of<TournamentDataState>(context, listen: false);
      final success = await tournamentData.editMatchScore(
        match.id,
        result['score1']!,
        result['score2']!,
        -1,
        isKnockout: true,
      );
      if (context.mounted) {
        if (success) {
          SnackBarHelper.showSuccess(context, 'Ergebnis aktualisiert');
        } else {
          SnackBarHelper.showError(context, 'Fehler beim Aktualisieren');
        }
      }
    }
  }

  Widget _buildSuperCupTree(Knockouts knockouts) {
    // Guard: no super cup matches → show placeholder
    if (knockouts.superCup.matches.length < 2) {
      return const Center(
        child: Text(
          'Keine Daten verfügbar',
          style: TextStyle(fontSize: 18, color: AppColors.textSubtle),
        ),
      );
    }

    final graph = Graph()..isTree = true;
    final builder = BuchheimWalkerConfiguration();

    final semiFinalNode = Node.Id('semi_final');
    final finalNode = Node.Id('final');

    graph.addEdge(finalNode, semiFinalNode);

    builder
      ..siblingSeparation = 25
      ..levelSeparation = 50
      ..subtreeSeparation = 50
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 1.0,
        maxScale: 1.0,
        child: GraphView(
          graph: graph,
          algorithm:
              BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
          paint: Paint()
            ..color = TreeColors.hotpink.withAlpha(76)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            if (node.key?.value == 'semi_final') {
              return _buildMatchNode(
                  knockouts.superCup.matches[0], TreeColors.hotpink);
            } else if (node.key?.value == 'final') {
              return _buildMatchNode(
                  knockouts.superCup.matches[1], TreeColors.hotpink);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _CachedGraph {
  final Graph graph;
  final BuchheimWalkerConfiguration config;
  final int matchCount;

  _CachedGraph({
    required this.graph,
    required this.config,
    required this.matchCount,
  });
}
