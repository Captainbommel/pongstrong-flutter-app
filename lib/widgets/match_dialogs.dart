//* matches should use an identifier to be able to update the match correctly
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// Shows a bottom sheet dialog to finish a match by entering scores.
///
/// Controllers are managed internally and disposed when the dialog closes.
Future<dynamic> finishMatchDialog(
  BuildContext context, {
  required String team1,
  required String team2,
  required Match match,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return _FinishMatchContent(
        team1: team1,
        team2: team2,
        match: match,
      );
    },
  );
}

/// Stateful content for the finish-match bottom sheet.
///
/// Owns the [TextEditingController]s so they are properly disposed.
class _FinishMatchContent extends StatefulWidget {
  final String team1;
  final String team2;
  final Match match;

  const _FinishMatchContent({
    required this.team1,
    required this.team2,
    required this.match,
  });

  @override
  State<_FinishMatchContent> createState() => _FinishMatchContentState();
}

class _FinishMatchContentState extends State<_FinishMatchContent> {
  final _cups1 = TextEditingController();
  final _cups2 = TextEditingController();

  @override
  void dispose() {
    _cups1.dispose();
    _cups2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLargeScreen
            ? const Border(
                top: BorderSide(color: FieldColors.skyblue, width: 14.0),
                left: BorderSide(color: FieldColors.skyblue, width: 14.0),
                right: BorderSide(color: FieldColors.skyblue, width: 14.0),
              )
            : const Border(
                top: BorderSide(color: FieldColors.skyblue, width: 14.0),
              ),
        borderRadius: isLargeScreen
            ? const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              )
            : BorderRadius.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          const Text(
            'Ergebnis eintragen',
            style: TextStyle(
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        widget.team1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      cupInput(_cups1),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        widget.team2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      cupInput(_cups2),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final authState = Provider.of<AuthState>(context, listen: false);
              if (!authState.isParticipant && !authState.isAdmin) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Keine Berechtigung. Bitte dem Turnier beitreten.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final score1 = int.tryParse(_cups1.text) ?? 0;
              final score2 = int.tryParse(_cups2.text) ?? 0;

              final tournamentData =
                  Provider.of<TournamentDataState>(context, listen: false);
              final success = await tournamentData.finishMatch(
                widget.match.id,
                score1: score1,
                score2: score2,
              );

              if (!context.mounted) return;

              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fehler beim Abschließen des Spiels'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: FieldColors.skyblue, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              overlayColor: FieldColors.skyblue.withAlpha(128),
            ),
            child: const Text(
              'Spiel Abschließen',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class CupsTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // allow empty input
    if (newValue.text.isEmpty) return newValue;

    // allow digits and minus sign
    if (!RegExp(r'^-?[0-9]*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    // only allow integers between -2 and 100
    final int? value = int.tryParse(newValue.text);
    if (value == null || value < -2 || value > 100) {
      return oldValue;
    }

    return newValue;
  }
}

SizedBox cupInput(TextEditingController cups1) {
  return SizedBox(
    width: 100,
    child: TextField(
      controller: cups1,
      keyboardType: TextInputType.number,
      inputFormatters: [CupsTextInputFormatter()],
      textAlign: TextAlign.center,
      cursorColor: FieldColors.skyblue,
      decoration: InputDecoration(
        focusColor: FieldColors.skyblue,
        border: OutlineInputBorder(
          borderSide: const BorderSide(
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: FieldColors.skyblue,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    ),
  );
}

/// Shows a bottom sheet dialog to start a match (move from queue to playing).
Future<dynamic> startMatchDialog(
  BuildContext context, {
  required String team1,
  required String team2,
  required List<String> members1,
  required List<String> members2,
  required Match match,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isLargeScreen = screenWidth > 600;

      Future<void> handleStartMatch() async {
        // Verify user is participant/admin before allowing match start
        final authState = Provider.of<AuthState>(context, listen: false);
        if (!authState.isParticipant && !authState.isAdmin) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Berechtigung. Bitte dem Turnier beitreten.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        final matchId = match.id;
        Logger.debug(
            'Starting match with ID $matchId at table ${match.tableNumber}',
            tag: 'MatchDialog');

        final success = await tournamentData.startMatch(matchId);

        if (!context.mounted) return;

        if (success) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tisch nicht verfügbar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      return Container(
        height: MediaQuery.of(context).size.height / 3,
        decoration: BoxDecoration(
          color: Colors.white,
          border: isLargeScreen
              ? const Border(
                  top: BorderSide(color: FieldColors.skyblue, width: 14.0),
                  left: BorderSide(color: FieldColors.skyblue, width: 14.0),
                  right: BorderSide(color: FieldColors.skyblue, width: 14.0),
                )
              : const Border(
                  top: BorderSide(color: FieldColors.skyblue, width: 14.0),
                ),
          borderRadius: isLargeScreen
              ? const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                )
              : BorderRadius.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            const Text(
              'Match Info:',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      Text('$team1:'),
                      for (final member in members1) Text(member),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      Text('$team2:'),
                      for (final member in members2) Text(member),
                    ],
                  ),
                ),
              ],
            ),
            ElevatedButton(
              // autofocus: true,
              onPressed: handleStartMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: FieldColors.skyblue, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                overlayColor: FieldColors.skyblue.withAlpha(128),
              ),
              child: const Text(
                'Spiel starten',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );
    },
  );
}
