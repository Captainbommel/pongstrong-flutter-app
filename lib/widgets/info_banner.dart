import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

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
        color: AppColors.caution,
      );

  factory InfoBanner.error(String text) => InfoBanner(
        text: text,
        color: GroupPhaseColors.cupred,
        icon: Icons.warning,
      );

  factory InfoBanner.info(String text) => InfoBanner(
        text: text,
        color: AppColors.info,
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
