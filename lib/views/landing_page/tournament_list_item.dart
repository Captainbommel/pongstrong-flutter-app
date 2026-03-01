import 'package:flutter/material.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// A single tournament entry in the "Deine Turniere" list.
class TournamentListItem extends StatelessWidget {
  final String tournamentId;
  final Future<List<bool>> Function(String, AuthState) getMeta;
  final void Function(String) onTap;

  const TournamentListItem({
    super.key,
    required this.tournamentId,
    required this.getMeta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        return FutureBuilder<List<bool>>(
          future: getMeta(tournamentId, authState),
          builder: (context, snapshot) {
            final isCreator = snapshot.data?[0] ?? false;
            final hasPassword = snapshot.data?[1] ?? true;

            final (subtitleText, trailingIcon) = isCreator
                ? ('Tippen zum Öffnen', Icons.arrow_forward_ios)
                : hasPassword
                    ? ('Tippen für Passwort-Eingabe', Icons.lock_outline)
                    : ('Tippen zum Beitreten', Icons.arrow_forward_ios);

            final accentColor = isCreator
                ? GroupPhaseColors.cupred
                : GroupPhaseColors.steelblue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onTap(tournamentId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCreator
                            ? GroupPhaseColors.cupred.withAlpha(100)
                            : AppColors.grey300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.sports_esports, color: accentColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tournamentId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCreator
                                      ? GroupPhaseColors.cupred
                                      : AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          trailingIcon,
                          size: 16,
                          color: AppColors.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
