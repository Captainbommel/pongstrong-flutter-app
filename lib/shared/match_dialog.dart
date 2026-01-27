//* matches should use an identifier to be able to update the match correctly
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:provider/provider.dart';

Future<dynamic> finnishMatchDialog(
  BuildContext context,
  String team1,
  String team2,
  TextEditingController cups1,
  TextEditingController cups2,
  Match match,
) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
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
                          team1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                        cupInput(cups1),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Column(
                      children: [
                        Text(
                          team2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                        cupInput(cups2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update match with scores and mark as done
                match.score1 = int.tryParse(cups1.text) ?? 0;
                match.score2 = int.tryParse(cups2.text) ?? 0;
                match.done = true;

                // Remove match from playing queue through TournamentDataState
                final tournamentData =
                    Provider.of<TournamentDataState>(context, listen: false);
                final success = await tournamentData.finishMatch(match.id);

                if (!context.mounted) return;

                if (!success) {
                  // Show error if unable to finish match
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fehler beim Abschließen des Spiels'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close the dialog
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
    },
  );
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
            color: Colors.black,
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

Future<dynamic> startMatchDialog(
  BuildContext context,
  String team1,
  String team2,
  List<String> members1,
  List<String> members2,
  Match match,
) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isLargeScreen = screenWidth > 600;

      Future<void> handleStartMatch() async {
        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        final matchId = match.id;
        debugPrint('Starting match with ID $matchId at table ${match.tischNr}');

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
                      for (var member in members1) Text(member),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      Text('$team2:'),
                      for (var member in members2) Text(member),
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
