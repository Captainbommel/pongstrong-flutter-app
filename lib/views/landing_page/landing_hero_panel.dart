import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';

/// Hero panel shown on the left (desktop) or top (mobile) of the landing page.
///
/// Displays the app logo, description, and feature highlights.
/// Use [isLarge] to switch between desktop and mobile sizing.
class LandingHeroPanel extends StatelessWidget {
  final bool isLarge;

  const LandingHeroPanel({super.key, required this.isLarge});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _buildLogo(),
        const SizedBox(height: 32),
        _buildDescription(),
        if (isLarge) ...[
          const SizedBox(height: 48),
          _buildFeaturesList(),
        ],
      ],
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment:
          isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_baseball,
              size: isLarge ? 64 : 48,
              color: GroupPhaseColors.cupred,
            ),
            const SizedBox(width: 16),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'PONGSTRONG',
                  style: TextStyle(
                    fontSize: isLarge ? 48 : 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Turnier Manager',
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      'Organisiere und verwalte deine Bierpong-Turniere mit Leichtigkeit. '
      'Verfolge Punkte, verwalte Spielpläne und halte den Wettbewerb am Laufen!',
      style: TextStyle(
        fontSize: isLarge ? 18 : 16,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      textAlign: isLarge ? TextAlign.start : TextAlign.center,
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (icon: Icons.groups, text: 'Gruppenphase verwalten'),
      (icon: Icons.account_tree, text: 'Turnierbaum Ansicht'),
      (icon: Icons.leaderboard, text: 'Live Punkteverfolgung'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GroupPhaseColors.cupred.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature.icon,
                  color: GroupPhaseColors.cupred,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  feature.text,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
