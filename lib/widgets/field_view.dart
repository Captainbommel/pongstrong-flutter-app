import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// A themed card section used across the playing field views.
///
/// Wraps [child] in a styled card with a [title] header and gradient
/// background from [primaryColor] / [secondaryColor].
class FieldView extends StatelessWidget {
  final String title;
  final Color primaryColor;
  final Color secondaryColor;
  final Widget child;
  final bool smallScreen;

  const FieldView({
    required this.title,
    required this.primaryColor,
    required this.secondaryColor,
    required this.smallScreen,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: const BorderSide(width: 4),
      ),
      color: primaryColor,
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
                      color: AppColors.textSecondary,
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
                color: secondaryColor,
                child: child,
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Card(
                  color: secondaryColor,
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
