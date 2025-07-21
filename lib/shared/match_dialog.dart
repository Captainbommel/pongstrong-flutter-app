//* matches should use an identifier to be able to update the match correctly
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/shared/colors.dart';

Future<dynamic> finnishMatchDialog(
  BuildContext context,
  String team1,
  String team2,
  TextEditingController cups1,
  TextEditingController cups2,
) {
  //TODO: change appearance of finnishMatchDialog based on screen size
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        height: MediaQuery.of(context).size.height / 3,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: FieldColors.skyblue, width: 14.0),
          ),
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
              onPressed: () {
                //TODO: implement finish match logic
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

SizedBox cupInput(TextEditingController cups1) {
  return SizedBox(
    width: 100,
    child: TextField(
      controller: cups1,
      keyboardType: TextInputType.number,
      //TODO: add a custom input formatter fitting for rules of the given game
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
) {
  //TODO: change appearance of startMatchDialog based on screen size
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        height: MediaQuery.of(context).size.height / 3,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: FieldColors.skyblue, width: 14.0),
          ),
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
              onPressed: () {
                //TODO: implement start match logic
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
