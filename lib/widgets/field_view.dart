import 'package:flutter/material.dart';

class FieldView extends StatelessWidget {
  final String title;
  final Color color1;
  final Color color2;
  final Widget child;
  final bool smallScreen;

  const FieldView(
    this.title,
    this.color1,
    this.color2,
    this.smallScreen,
    this.child, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: const BorderSide(width: 4),
      ),
      color: color1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (smallScreen)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Card(
                color: color2,
                child: child,
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Card(
                  color: color2,
                  child: SingleChildScrollView(
                    child: child,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
