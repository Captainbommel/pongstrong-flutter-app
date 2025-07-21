import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/shared/colors.dart';

Future<String> _loadRules() async {
  final rules = await rootBundle.loadString('rules.txt');
  return rules;
}

//TODO: Formatierung für mobile anpassen

class RulesView extends StatelessWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FieldColors.skyblue,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: GroupPhaseColors.cupred,
                  width: 7,
                ),
              ),
              child: FutureBuilder(
                future: _loadRules(),
                builder: (context, snapshot) => Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Text(
                    snapshot.data ?? 'loading...',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
