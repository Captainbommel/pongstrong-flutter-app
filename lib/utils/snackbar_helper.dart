import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Centralised snack-bar helper so every call site gets a consistent
/// floating style, automatic clearing of the previous snack-bar, and
/// an optional background colour.
class SnackBarHelper {
  SnackBarHelper._(); // prevent instantiation

  /// Show a floating [SnackBar] with the given [message].
  ///
  /// Any currently visible snack-bar is dismissed first so messages
  /// never stack up behind one another.
  static void showMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: backgroundColor,
        content: Text(message),
      ),
    );
  }

  /// Convenience: green success snack-bar.
  static void showSuccess(BuildContext context, String message) {
    showMessage(context, message, backgroundColor: AppColors.success);
  }

  /// Convenience: red error snack-bar.
  static void showError(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 4),
    );
  }

  /// Convenience: orange/amber warning snack-bar.
  static void showWarning(BuildContext context, String message) {
    showMessage(context, message, backgroundColor: AppColors.warning);
  }
}
