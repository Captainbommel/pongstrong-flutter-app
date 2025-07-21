import 'package:flutter/material.dart';
import 'package:pongstrong/shared/colors.dart';
import 'package:pongstrong/shared/field_view.dart';
import 'package:pongstrong/shared/test_objects.dart';

class PlayingField extends StatelessWidget {
  const PlayingField({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: FieldView(
                      'Laufende Spiele',
                      FieldColors.tomato,
                      FieldColors.tomato.withAlpha(128),
                      false,
                      Wrap(
                          alignment: WrapAlignment.center,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          children: runningMatches),
                    ),
                  ),
                  Expanded(
                    child: FieldView(
                      'Nächste Spiele',
                      FieldColors.springgreen,
                      FieldColors.springgreen.withAlpha(128),
                      false,
                      Wrap(
                          alignment: WrapAlignment.center,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          children: upcomingMatches),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FieldView(
                'Aktuelle Tabelle',
                FieldColors.skyblue,
                FieldColors.skyblue.withAlpha(128),
                false,
                Wrap(
                  children: tables,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
