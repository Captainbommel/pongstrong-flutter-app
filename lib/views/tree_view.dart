import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/widgets/match_edit_dialog.dart';
import 'package:provider/provider.dart';

class TreeViewPage extends StatefulWidget {
  final ValueChanged<bool>? onExploreChanged;

  const TreeViewPage({super.key, this.onExploreChanged});

  @override
  TreeViewPageState createState() => TreeViewPageState();
}

class TreeViewPageState extends State<TreeViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  bool _isExploring = false;

  // Cached graph data to avoid rebuilding on every frame
  final Map<String, _CachedGraph> _graphCache = {};

  // Colors for each tournament
  final List<Color> _tournamentColors = [
    TreeColors.rebeccapurple,
    TreeColors.royalblue,
    TreeColors.yellowgreen,
    TreeColors.hotpink,
  ];

  final List<String> _tournamentNames = [
    'Champions League',
    'Europa League',
    'Conference League',
    'Super Cup',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentData = Provider.of<TournamentDataState>(context);
    final knockouts = tournamentData.knockouts;
    final isLargeScreen = MediaQuery.sizeOf(context).width > 940;

    // Check if knockouts are empty (not yet generated)
    final hasKnockouts = knockouts.champions.rounds.isNotEmpty &&
        knockouts.champions.rounds[0].isNotEmpty &&
        (knockouts.champions.rounds[0][0].teamId1.isNotEmpty ||
            knockouts.champions.rounds[0][0].teamId2.isNotEmpty);

    if (!hasKnockouts) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Keine Daten verfügbar',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (isLargeScreen)
            // Desktop: Show TabBar
            Container(
              color: Colors.grey[100],
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                indicatorColor: _tournamentColors[_tabController.index],
                indicatorWeight: 4,
                tabs: [
                  for (final name in _tournamentNames) Tab(text: name),
                ],
              ),
            )
          else
            // Mobile: Show Dropdown
            Container(
              color: Colors.grey[100],
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
                      color: _tournamentColors[_selectedIndex],
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _tournamentColors[_selectedIndex],
                      width: 2,
                    ),
                  ),
                ),
                dropdownColor: Colors.white,
                focusColor: Colors.transparent,
                items: [
                  for (int i = 0; i < _tournamentNames.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(_tournamentNames[i]),
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
          Expanded(
            child: isLargeScreen
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTournamentTree(
                        'Champions League',
                        knockouts.champions.rounds,
                        TreeColors.rebeccapurple,
                      ),
                      _buildTournamentTree(
                        'Europa League',
                        knockouts.europa.rounds,
                        TreeColors.royalblue,
                      ),
                      _buildTournamentTree(
                        'Conference League',
                        knockouts.conference.rounds,
                        TreeColors.yellowgreen,
                      ),
                      _buildSuperCupTree(knockouts),
                    ],
                  )
                : _buildMobileTreeWithOverlay(knockouts),
          ),
        ],
      ),
    );
  }

  void _setExploring(bool value) {
    setState(() => _isExploring = value);
    widget.onExploreChanged?.call(value);
  }

  Widget _buildMobileTreeWithOverlay(Knockouts knockouts) {
    return Stack(
      children: [
        // Tree content (always rendered, interactive only when exploring)
        IgnorePointer(
          ignoring: !_isExploring,
          child: _buildSelectedTournament(knockouts),
        ),
        // Blur overlay when not exploring
        if (!_isExploring) ...[
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                child: Container(
                  color: Colors.white.withAlpha(80),
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
                backgroundColor: _tournamentColors[_selectedIndex],
                foregroundColor: Colors.white,
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
              backgroundColor: Colors.black.withAlpha(150),
              foregroundColor: Colors.white,
              child: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedTournament(Knockouts knockouts) {
    switch (_selectedIndex) {
      case 0:
        return _buildTournamentTree(
          'Champions League',
          knockouts.champions.rounds,
          TreeColors.rebeccapurple,
        );
      case 1:
        return _buildTournamentTree(
          'Europa League',
          knockouts.europa.rounds,
          TreeColors.royalblue,
        );
      case 2:
        return _buildTournamentTree(
          'Conference League',
          knockouts.conference.rounds,
          TreeColors.yellowgreen,
        );
      case 3:
        return _buildSuperCupTree(knockouts);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTournamentTree(
    String title,
    List<List<Match>> rounds,
    Color color,
  ) {
    // Guard: no rounds or all rounds empty → show placeholder
    if (rounds.isEmpty || rounds.every((r) => r.isEmpty)) {
      return Center(
        child: Text(
          'Keine Daten verfügbar',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      );
    }

    // Use cached graph or build a new one
    final cacheKey = title;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isReady ? borderColor : borderColor.withAlpha(76),
            width: isReady ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      color: match.teamId1.isEmpty ? Colors.grey : Colors.black,
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
                      color: match.teamId2.isEmpty ? Colors.grey : Colors.black,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Ergebnis aktualisiert'
                : 'Fehler beim Aktualisieren'),
            backgroundColor:
                success ? FieldColors.springgreen : GroupPhaseColors.cupred,
          ),
        );
      }
    }
  }

  Widget _buildSuperCupTree(Knockouts knockouts) {
    // Guard: no super cup matches → show placeholder
    if (knockouts.superCup.matches.length < 2) {
      return Center(
        child: Text(
          'Keine Daten verfügbar',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
