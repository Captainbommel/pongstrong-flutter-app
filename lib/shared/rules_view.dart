import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/shared/colors.dart';

Future<String> _loadRules() async {
  final rules = await rootBundle.loadString('rules.txt');
  return rules;
}

class RulesView extends StatelessWidget {
  const RulesView({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      color: FieldColors.skyblue,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: GroupPhaseColors.cupred,
                  width: isMobile ? 4 : 7,
                ),
              ),
              child: FutureBuilder(
                future: _loadRules(),
                builder: (context, snapshot) => Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 25.0),
                  child: Text(
                    snapshot.data ?? 'loading...',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 16,
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
