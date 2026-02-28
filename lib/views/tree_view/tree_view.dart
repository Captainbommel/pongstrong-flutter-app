import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
import 'package:pongstrong/views/tree_view/bracket_match_node.dart';
import 'package:pongstrong/views/tree_view/bracket_winner_node.dart';
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
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _selectedIndex = 0;
  bool _isExploring = false;
  bool _showTableNumbers = false;
  int _lastBracketCount = 0;

  // Cached graph data to avoid rebuilding on every frame
  final Map<String, _CachedGraph> _graphCache = {};

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

  //TODO: Check if the first round is completely filled otherwise its not ready. Add a method to KnockoutBracket for this.
  /// Checks whether a KnockoutBracket has meaningful data.
  bool _bracketHasData(KnockoutBracket bracket) {
    if (bracket.rounds.isEmpty) return false;
    if (bracket.rounds[0].isEmpty) return false;
    return bracket.rounds[0][0].teamId1.isNotEmpty ||
        bracket.rounds[0][0].teamId2.isNotEmpty;
  }

  /// Checks whether the Super Cup has meaningful data.
  bool _superCupHasData(Super superCup) {
    if (superCup.matches.isEmpty) return false;
    return superCup.matches
        .any((m) => m.teamId1.isNotEmpty || m.teamId2.isNotEmpty);
  }

  /// Builds the list of visible bracket entries based on actual data.
  List<_BracketEntry> _getVisibleBrackets(Knockouts knockouts) {
    final entries = <_BracketEntry>[];
    final brackets = {
      BracketKey.gold: knockouts.champions,
      BracketKey.silver: knockouts.europa,
      BracketKey.bronze: knockouts.conference,
    };

    for (final bracketEntry in brackets.entries) {
      if (_bracketHasData(bracketEntry.value)) {
        entries.add(_BracketEntry(
          key: bracketEntry.key,
          name: knockouts.getBracketName(bracketEntry.key),
          color: _bracketColors[bracketEntry.key]!,
          rounds: bracketEntry.value.rounds,
        ));
      }
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

  /// Ensures that the TabController is initialized and has the correct number of tabs.
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
            //Show TabBar
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
                                    child: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: AppColors.grey500,
                                    ),
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
            //Show Dropdown
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
                          icon: const Icon(
                            Icons.edit,
                            size: 18,
                          ),
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
          if (!isLargeScreen)
            Container(
              color: AppColors.grey100,
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: _buildTableCheckbox(visibleBrackets[_selectedIndex].color),
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
                                    b.key,
                                    b.rounds!,
                                    b.color,
                                  ),
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
                                () => _showTableNumbers = !_showTableNumbers,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: _buildTableCheckbox(
                                  visibleBrackets[_tabController!.index].color,
                                  size: 24,
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

  Widget _buildTableCheckbox(Color activeColor, {double size = 28}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (size >= 28) const SizedBox(width: 7),
        SizedBox(
          height: size,
          width: size,
          child: Checkbox(
            value: _showTableNumbers,
            activeColor: activeColor,
            onChanged: (v) => setState(() => _showTableNumbers = v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() => _showTableNumbers = !_showTableNumbers),
          child: const Text(
            'Tische anzeigen',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTreeWithOverlay(
      Knockouts knockouts, List<_BracketEntry> visibleBrackets) {
    final currentBracket = visibleBrackets[_selectedIndex];
    return Stack(
      children: [
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
    if (rounds.isEmpty || rounds.every((r) => r.isEmpty)) {
      return _noDataPlaceholder;
    }

    final cacheKey = bracketKey.name;
    final matchCount = rounds.fold<int>(0, (sum, round) => sum + round.length);
    var cached = _graphCache[cacheKey];
    if (cached == null || cached.matchCount != matchCount) {
      final graph = Graph()..isTree = true;
      final nodes = <String, Node>{};

      const winnerNodeId = 'winner';
      nodes[winnerNodeId] = Node.Id(winnerNodeId);

      for (int ri = 0; ri < rounds.length; ri++) {
        for (int mi = 0; mi < rounds[ri].length; mi++) {
          nodes['r${ri}_m$mi'] = Node.Id('r${ri}_m$mi');
        }
      }

      graph.addEdge(nodes[winnerNodeId]!, nodes['r${rounds.length - 1}_m0']!);

      for (int ri = 0; ri < rounds.length - 1; ri++) {
        for (int mi = 0; mi < rounds[ri].length; mi++) {
          graph.addEdge(
              nodes['r${ri + 1}_m${mi ~/ 2}']!, nodes['r${ri}_m$mi']!);
        }
      }

      cached = _CachedGraph(
        graph: graph,
        config: _defaultTreeConfig(),
        matchCount: matchCount,
      );
      _graphCache[cacheKey] = cached;
    }

    return _buildGraphView(
      graph: cached.graph,
      config: cached.config,
      color: color,
      nodeBuilder: (nodeId) {
        if (nodeId == 'winner') {
          return BracketWinnerNode(
              finalMatch: rounds.last[0], bracketColor: color);
        }
        final parts = nodeId.split('_');
        final ri = int.parse(parts[0].substring(1));
        final mi = int.parse(parts[1].substring(1));
        final match = rounds[ri][mi];
        return BracketMatchNode(
          match: match,
          borderColor: color,
          showTableNumbers: _showTableNumbers,
          onEdit: (t1, t2) => _onEditKnockoutMatch(context, match, t1, t2),
        );
      },
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
    if (knockouts.superCup.matches.isEmpty) return _noDataPlaceholder;

    final graph = Graph()..isTree = true;

    if (knockouts.superCup.matches.length >= 2) {
      //Two-match layout
      final winnerNode = Node.Id('winner');
      final semiFinalNode = Node.Id('semi_final');
      final finalNode = Node.Id('final');
      graph.addEdge(winnerNode, finalNode);
      graph.addEdge(finalNode, semiFinalNode);

      return _buildGraphView(
        graph: graph,
        config: _defaultTreeConfig(),
        color: TreeColors.hotpink,
        nodeBuilder: (nodeId) {
          final m0 = knockouts.superCup.matches[0];
          final m1 = knockouts.superCup.matches[1];
          return switch (nodeId) {
            'winner' => BracketWinnerNode(
                finalMatch: m1, bracketColor: TreeColors.hotpink),
            'semi_final' => BracketMatchNode(
                match: m0,
                borderColor: TreeColors.hotpink,
                showTableNumbers: _showTableNumbers,
                onEdit: (t1, t2) => _onEditKnockoutMatch(context, m0, t1, t2)),
            'final' => BracketMatchNode(
                match: m1,
                borderColor: TreeColors.hotpink,
                showTableNumbers: _showTableNumbers,
                onEdit: (t1, t2) => _onEditKnockoutMatch(context, m1, t1, t2)),
            _ => const SizedBox.shrink(),
          };
        },
      );
    } else {
      //Single-match layout
      final winnerNode = Node.Id('winner');
      final finalNode = Node.Id('final');
      graph.addEdge(winnerNode, finalNode);

      return _buildGraphView(
        graph: graph,
        config: _defaultTreeConfig(),
        color: TreeColors.hotpink,
        nodeBuilder: (nodeId) {
          final m0 = knockouts.superCup.matches[0];
          return switch (nodeId) {
            'winner' => BracketWinnerNode(
                finalMatch: m0, bracketColor: TreeColors.hotpink),
            'final' => BracketMatchNode(
                match: m0,
                borderColor: TreeColors.hotpink,
                showTableNumbers: _showTableNumbers,
                onEdit: (t1, t2) => _onEditKnockoutMatch(context, m0, t1, t2)),
            _ => const SizedBox.shrink(),
          };
        },
      );
    }
  }

  static const _noDataPlaceholder = Center(
    child: Text(
      'Keine Daten verfügbar',
      style: TextStyle(fontSize: 18, color: AppColors.textSubtle),
    ),
  );

  static BuchheimWalkerConfiguration _defaultTreeConfig() =>
      BuchheimWalkerConfiguration()
        ..siblingSeparation = 25
        ..levelSeparation = 50
        ..subtreeSeparation = 50
        ..orientation = BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT;

  Widget _buildGraphView({
    required Graph graph,
    required BuchheimWalkerConfiguration config,
    required Color color,
    required Widget Function(String nodeId) nodeBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 1.0,
        maxScale: 1.0,
        child: GraphView(
          graph: graph,
          algorithm: BuchheimWalkerAlgorithm(config, TreeEdgeRenderer(config)),
          paint: Paint()
            ..color = color.withAlpha(76)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
          builder: (Node node) => nodeBuilder(node.key?.value as String),
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
