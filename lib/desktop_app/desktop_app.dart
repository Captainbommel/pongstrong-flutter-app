import 'package:flutter/material.dart';
import 'package:pongstrong/desktop_app/desktop_app_state.dart';
import 'package:pongstrong/desktop_app/test_helpers.dart';
import 'package:pongstrong/shared/tree_view.dart';
import 'package:pongstrong/desktop_app/playingfield_view.dart';
import 'package:pongstrong/shared/rules_view.dart';
import 'package:provider/provider.dart';

const String turnamentName = 'BMT-Cup';

const navbarStyle = TextStyle(
  color: Colors.black,
  fontSize: 20,
  decoration: TextDecoration.underline,
);

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black,
        elevation: 10,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            //? Highlight selected page
            TextButton(
              onPressed: () {
                Provider.of<DesktopAppState>(context, listen: false)
                    .setAppState(DesktopAppView.playingfield)!();
              },
              child: const Text('Spielfeld', style: navbarStyle),
            ),
            TextButton(
              onPressed: () {
                Provider.of<DesktopAppState>(context, listen: false)
                    .setAppState(DesktopAppView.tournamentTree)!();
              },
              child: const Text('Turnierbaum', style: navbarStyle),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Teams', style: navbarStyle),
            ),
            TextButton(
              onPressed: () {
                Provider.of<DesktopAppState>(context, listen: false)
                    .setAppState(DesktopAppView.rules)!();
              },
              child: const Text('Regeln', style: navbarStyle),
            ),
            TextButton(
              onPressed: () => TestDataHelpers.uploadTeamsFromJson(context),
              child: const Text('Load Teams', style: navbarStyle),
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),
      body: () {
        switch (Provider.of<DesktopAppState>(context).state) {
          case DesktopAppView.playingfield:
            return const PlayingField();
          case DesktopAppView.rules:
            return const RulesView();
          case DesktopAppView.tournamentTree:
            return const TreeViewPage();
          default:
            return const Placeholder();
        }
      }(),
    );
  }
}
