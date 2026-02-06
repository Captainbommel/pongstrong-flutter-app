import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:provider/provider.dart';

class TreeViewPage extends StatefulWidget {
  const TreeViewPage({super.key});

  @override
  TreeViewPageState createState() => TreeViewPageState();
}

class TreeViewPageState extends State<TreeViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Colors for each tournament
  final List<Color> _tournamentColors = [
    TreeColors.rebeccapurple,
    TreeColors.royalblue,
    TreeColors.yellowgreen,
    TreeColors.hotpink,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update indicator color
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

    // Check if knockouts are empty (not yet generated)
    final hasKnockouts = knockouts.champions.rounds.isNotEmpty &&
        knockouts.champions.rounds[0].isNotEmpty &&
        (knockouts.champions.rounds[0][0].teamId1.isNotEmpty ||
            knockouts.champions.rounds[0][0].teamId2.isNotEmpty);

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              indicatorColor: _tournamentColors[_tabController.index],
              indicatorWeight: 4,
              tabs: const [
                Tab(text: 'Champions League'),
                Tab(text: 'Europa League'),
                Tab(text: 'Conference League'),
                Tab(text: 'Super Cup'),
              ],
            ),
          ),
          Expanded(
            child: hasKnockouts
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
                : const Center(
                    child: Text(
                      'Keine Daten verfügbar',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentTree(
    String title,
    List<List<Match>> rounds,
    Color color,
  ) {
    final graph = Graph()..isTree = true;
    final builder = BuchheimWalkerConfiguration();

    // Build graph from rounds (bottom-up: final to first round)
    final nodes = <String, Node>{};

    // Create all nodes
    for (int roundIndex = 0; roundIndex < rounds.length; roundIndex++) {
      for (int matchIndex = 0;
          matchIndex < rounds[roundIndex].length;
          matchIndex++) {
        final matchId = 'r${roundIndex}_m$matchIndex';
        nodes[matchId] = Node.Id(matchId);
      }
    }

    // Add edges (connect matches from current round to next round)
    for (int roundIndex = 0; roundIndex < rounds.length - 1; roundIndex++) {
      for (int matchIndex = 0;
          matchIndex < rounds[roundIndex].length;
          matchIndex++) {
        final currentMatch = 'r${roundIndex}_m$matchIndex';
        final nextMatch = 'r${roundIndex + 1}_m${matchIndex ~/ 2}';
        graph.addEdge(nodes[nextMatch]!, nodes[currentMatch]!);
      }
    }

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

    // Get team names or fallback to IDs
    String getTeamName(String teamId) {
      if (teamId.isEmpty) return '';
      final team = tournamentData.getTeam(teamId);
      return team?.name ?? teamId;
    }

    // Determine if match is ready (both teams are assigned)
    final bool isReady = match.teamId1.isNotEmpty && match.teamId2.isNotEmpty;

    return InkWell(
      onTap: () {},
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

  Widget _buildSuperCupTree(Knockouts knockouts) {
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
