import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Shared [InputDecoration] factory used across landing-page dialogs.
///
/// Provides the standard cup-red focused-border styling so that
/// `login_dialog`, `tournament_password_dialog`, and
/// `create_tournament_dialog` share a single definition.
InputDecoration cupredInputDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: GroupPhaseColors.cupred, width: 2),
    ),
    floatingLabelStyle: const TextStyle(color: GroupPhaseColors.cupred),
  );
}
