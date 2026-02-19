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
        if (confirmIcon != null) ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icon(confirmIcon),
                label: Text(confirmText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                ),
              ) else ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(confirmText),
              ),
      ],
    ),
  );
}

/// Reusable warning/info banner used in dialogs
class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const InfoBanner({
    super.key,
    required this.text,
    required this.color,
    this.icon = Icons.warning_amber,
  });

  factory InfoBanner.warning(String text) => InfoBanner(
        text: text,
        color: Colors.amber,
      );

  factory InfoBanner.error(String text) => InfoBanner(
        text: text,
        color: GroupPhaseColors.cupred,
        icon: Icons.warning,
      );

  factory InfoBanner.info(String text) => InfoBanner(
        text: text,
        color: Colors.blue,
        icon: Icons.info_outline,
      );

  factory InfoBanner.success(String text) => InfoBanner(
        text: text,
        color: FieldColors.springgreen,
        icon: Icons.security,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
