import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Reusable error banner widget for displaying error messages.
///
/// Used in admin panel pages and other contexts that show errors.
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GroupPhaseColors.cupred),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: GroupPhaseColors.cupred),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
