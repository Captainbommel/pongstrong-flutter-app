// Barrel export for landing page components

import 'package:flutter/material.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/utils/colors.dart';

class LoggedInUserInfo extends StatelessWidget {
  const LoggedInUserInfo({
    super.key,
    required this.authState,
    required this.isLarge,
  });

  final AuthState authState;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GroupPhaseColors.cupred.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GroupPhaseColors.cupred.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GroupPhaseColors.cupred,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: AppColors.textOnColored),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eingeloggt als',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  Text(
                    authState.userEmail ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => authState.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Abmelden'),
              style: TextButton.styleFrom(
                foregroundColor: GroupPhaseColors.cupred,
              ),
            ),
          ],
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(200),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person,
                    size: 18, color: GroupPhaseColors.cupred),
                const SizedBox(width: 8),
                Text(
                  authState.userEmail?.split('@')[0] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => authState.signOut(),
                  child: const Icon(Icons.logout,
                      size: 18, color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}
