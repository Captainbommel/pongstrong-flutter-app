import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/utils/colors.dart';

/// Displays the tournament rules loaded from the bundled asset file.
///
/// Uses a [StatefulWidget] to cache the [Future] so that the asset is only
/// loaded once, not on every rebuild.
class RulesView extends StatefulWidget {
  const RulesView({super.key});

  @override
  State<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends State<RulesView> {
  late final Future<String> _rulesFuture;

  @override
  void initState() {
    super.initState();
    _rulesFuture = rootBundle.loadString('rules.txt');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return ColoredBox(
      color: FieldColors.skyblue,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textOnColored,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: GroupPhaseColors.cupred,
                  width: isMobile ? 4 : 7,
                ),
              ),
              child: FutureBuilder<String>(
                future: _rulesFuture,
                builder: (context, snapshot) => Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 25.0),
                  child: Text(
                    snapshot.data ?? 'Laden...',
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
