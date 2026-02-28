import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Reusable confirmation dialog that returns true/false.
///
/// Used throughout the app for start/reset/phase-change confirmations.
Future<bool?> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String cancelText = 'Abbrechen',
  String confirmText = 'Bestätigen',
  Color confirmColor = GroupPhaseColors.cupred,
  IconData? titleIcon,
  IconData? confirmIcon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: titleIcon != null
          ? Row(
              children: [
                Icon(titleIcon, color: confirmColor),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            )
          : Text(title, style: TextStyle(color: confirmColor)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: content,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText, style: TextStyle(color: confirmColor)),
        ),
        if (confirmIcon != null)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(confirmIcon),
            label: Text(confirmText),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.textOnColored,
            ),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.textOnColored,
            ),
            child: Text(confirmText),
          ),
      ],
    ),
  );
}
