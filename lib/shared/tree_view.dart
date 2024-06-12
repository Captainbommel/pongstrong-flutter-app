import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class TreeViewPage extends StatefulWidget {
  const TreeViewPage({super.key});

  @override
  TreeViewPageState createState() => TreeViewPageState();
}

class TreeViewPageState extends State<TreeViewPage> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.01,
        maxScale: 5.6,
        child: GraphView(
          graph: graph,
          algorithm:
              BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
          paint: Paint()
            ..color = Colors.black
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            var a = node.key?.value as int;
            return treeNode(a);
          },
        ),
      ),
    );
  }

  Random r = Random();

  Widget treeNode(int a) {
    return InkWell(
      onTap: () {},
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: Column(
          children: [
            Text(a == 0 ? '' : 'Schwifty'),
            Text(a == 0 ? 'Champios League' : '$a'),
            Text(a == 0 ? '' : 'Buzz Brauer'),
          ],
        ),
      ),
    );
  }

  final Graph graph = Graph()..isTree = true;
  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  @override
  void initState() {
    //? add colors for every team
    super.initState();
    final node81 = Node.Id(81);
    final node82 = Node.Id(82);
    final node83 = Node.Id(83);
    final node84 = Node.Id(84);
    final node85 = Node.Id(85);
    final node86 = Node.Id(86);
    final node87 = Node.Id(87);
    final node88 = Node.Id(88);
    final node41 = Node.Id(41);
    final node42 = Node.Id(42);
    final node43 = Node.Id(43);
    final node44 = Node.Id(44);
    final node21 = Node.Id(21);
    final node22 = Node.Id(22);
    final node11 = Node.Id(11);
    final title = Node.Id(0);

    graph.addEdge(node11, node21);
    graph.addEdge(node11, node22);
    graph.addEdge(node22, node43);
    graph.addEdge(node22, node44);
    graph.addEdge(node21, node41);
    graph.addEdge(node21, node42);
    graph.addEdge(node44, node88);
    graph.addEdge(node44, node87);
    graph.addEdge(node43, node86);
    graph.addEdge(node43, node85);
    graph.addEdge(node42, node83);
    graph.addEdge(node42, node84);
    graph.addEdge(node41, node81);
    graph.addEdge(node41, node82);
    graph.addNode(title);

    builder
      ..siblingSeparation = (80)
      ..levelSeparation = (80)
      ..subtreeSeparation = (80)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }
}
