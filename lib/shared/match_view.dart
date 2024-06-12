import 'package:flutter/material.dart';

class MatchView extends StatelessWidget {
  final String team1;
  final String team2;
  final String table;
  final Color tableColor;
  final bool clickable;
  final bool expandHorizontally;
  final void Function()? onTap;

  const MatchView(
    this.team1,
    this.team2,
    this.table,
    this.tableColor,
    this.clickable, {
    this.expandHorizontally = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (clickable) {
      return _matchButton(onTap);
    } else {
      return Opacity(opacity: 0.5, child: _matchButton(null));
    }
  }

  Container _matchButton(void Function()? onTap) {
    return Container(
      width: expandHorizontally ? 500 : 200,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 2,
          ),
        ],
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        //? add an effect to the button
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0.85, 0),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tableColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    table,
                    style: const TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(-0.3, 0),
              child: Text(
                'Vs',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: tableColor.withOpacity(0.4),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(-0.6, 0),
              child: SizedBox(
                width: 116,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        team1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        team2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
