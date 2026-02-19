import 'package:flutter/material.dart';
import 'package:pongstrong/services/import_service.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:pongstrong/widgets/confirmation_dialog.dart';
import 'package:provider/provider.dart';

/// Shared admin panel dialog methods.
///
/// Extracted from the old DesktopAdminPanel and MobileAdminPanel to
/// eliminate duplication. Both panels had nearly identical dialog logic.
class AdminPanelDialogs {
  /// Verifies the user is an admin before performing an action.
  /// Returns false and shows a snackbar if not authorized.
  static bool _verifyAdmin(BuildContext context) {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (!authState.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Berechtigung für diese Aktion.'),
          backgroundColor: GroupPhaseColors.cupred,
        ),
      );
      return false;
    }
    return true;
  }

  /// Show tournament start confirmation
  static Future<void> showStartConfirmation(
    BuildContext context,
    AdminPanelState state,
  ) async {
    if (!_verifyAdmin(context)) return;
    final validationMessage = state.startValidationMessage;
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: GroupPhaseColors.cupred,
        ),
      );
      return;
    }

    String successMessage;
    switch (state.tournamentStyle) {
      case TournamentStyle.groupsAndKnockouts:
        successMessage =
            'Turnier gestartet! Gruppenphase-Spiele wurden generiert.';
      case TournamentStyle.knockoutsOnly:
        successMessage = 'Turnier gestartet! K.O.-Bracket wurde erstellt.';
      case TournamentStyle.everyoneVsEveryone:
        successMessage =
            'Turnier gestartet! Alle Rundenspiele wurden generiert.';
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Turnier starten?',
      confirmText: 'Turnier starten',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registriert: ${state.totalTeams} Teams'),
          const SizedBox(height: 8),
          Text('Turniermodus: ${state.styleDisplayName}'),
          const SizedBox(height: 16),
          const InfoBanner(
            text:
                'Nach dem Start können keine neuen Teams mehr hinzugefügt werden und der Turniermodus kann nicht mehr geändert werden.',
            color: Colors.amber,
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await state.startTournament();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? successMessage
                : state.errorMessage ?? 'Fehler beim Starten des Turniers'),
            backgroundColor:
                success ? FieldColors.springgreen : GroupPhaseColors.cupred,
          ),
        );
        if (success) {
          final tournamentData =
              Provider.of<TournamentDataState>(context, listen: false);
          await tournamentData.loadTournamentData(state.currentTournamentId);
        }
      }
    }
  }

  /// Show phase advance confirmation
  static Future<void> showPhaseAdvanceConfirmation(
    BuildContext context,
    AdminPanelState state,
  ) async {
    if (!_verifyAdmin(context)) return;

    if (state.currentPhase != TournamentPhase.groupPhase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phasenwechsel ist nur von der Gruppenphase möglich.'),
          backgroundColor: GroupPhaseColors.cupred,
        ),
      );
      return;
    }

    final bool hasRemainingMatches = state.remainingMatches > 0;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Zur nächsten Phase wechseln?',
      titleIcon: Icons.skip_next,
      confirmText: 'Zur K.O.-Phase',
      confirmIcon: Icons.skip_next,
      confirmColor: TreeColors.rebeccapurple,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Du wechselst von der aktuellen Phase zur K.O.-Phase.'),
          const SizedBox(height: 16),
          if (hasRemainingMatches)
            InfoBanner(
              text:
                  'Achtung: ${state.remainingMatches} Spiel(e) wurden noch nicht eingetragen!',
              color: Colors.orange,
            )
          else
            const InfoBanner(
              text: 'Alle Spiele der aktuellen Phase wurden eingetragen.',
              color: Colors.blue,
              icon: Icons.info_outline,
            ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await state.advancePhase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Phase erfolgreich gewechselt!'
                : state.errorMessage ?? 'Fehler beim Phasenwechsel'),
            backgroundColor:
                success ? FieldColors.springgreen : GroupPhaseColors.cupred,
          ),
        );
        if (success) {
          final tournamentData =
              Provider.of<TournamentDataState>(context, listen: false);
          await tournamentData.loadTournamentData(state.currentTournamentId);
        }
      }
    }
  }

  /// Show reset tournament confirmation
  static Future<void> showResetConfirmation(
    BuildContext context,
    AdminPanelState state, {
    VoidCallback? onResetComplete,
  }) async {
    if (!_verifyAdmin(context)) return;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Turnier zurücksetzen?',
      titleIcon: Icons.restart_alt,
      confirmText: 'Zurücksetzen',
      confirmIcon: Icons.restart_alt,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Möchtest du das Turnier wirklich zurücksetzen?'),
          SizedBox(height: 16),
          InfoBanner(
            text:
                'Alle Spielergebnisse und der Turnierfortschritt werden gelöscht. Teams bleiben erhalten.',
            color: GroupPhaseColors.cupred,
            icon: Icons.warning,
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await state.resetTournament();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Turnier wurde zurückgesetzt'
                : state.errorMessage ?? 'Fehler beim Zurücksetzen'),
            backgroundColor:
                success ? FieldColors.springgreen : GroupPhaseColors.cupred,
          ),
        );
        if (success) {
          onResetComplete?.call();
          final tournamentData =
              Provider.of<TournamentDataState>(context, listen: false);
          await tournamentData.loadTournamentData(state.currentTournamentId);
        }
      }
    }
  }

  /// Show revert to group phase confirmation
  static Future<void> showRevertToGroupPhaseConfirmation(
    BuildContext context,
    AdminPanelState state, {
    VoidCallback? onRevertComplete,
  }) async {
    if (!_verifyAdmin(context)) return;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Zurück zur Gruppenphase?',
      titleIcon: Icons.undo,
      confirmText: 'Zurücksetzen',
      confirmIcon: Icons.undo,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Möchtest du wirklich zur Gruppenphase zurückkehren?'),
          SizedBox(height: 16),
          InfoBanner(
            text:
                'Alle K.O.-Bäume werden gelöscht. Nicht abgeschlossene Gruppenspiele werden wieder in die Warteschlange eingereiht.',
            color: GroupPhaseColors.cupred,
            icon: Icons.warning,
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await state.revertToGroupPhase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Zurück zur Gruppenphase'
                : state.errorMessage ?? 'Fehler beim Zurücksetzen'),
            backgroundColor:
                success ? FieldColors.springgreen : GroupPhaseColors.cupred,
          ),
        );
        if (success) {
          onRevertComplete?.call();
          final tournamentData =
              Provider.of<TournamentDataState>(context, listen: false);
          await tournamentData.loadTournamentData(state.currentTournamentId);
        }
      }
    }
  }

  /// Show export dialog
  static Future<void> showExportDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: GroupPhaseColors.steelblue),
            SizedBox(width: 8),
            Text('JSON Export'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Folgende Daten werden exportiert:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _exportItem('Teams und Gruppen'),
              _exportItem('Spielergebnisse'),
              _exportItem('Turnierstatus'),
              _exportItem('Turniermodus'),
              _exportItem('Spielreihenfolge'),
              const SizedBox(height: 16),
              InfoBanner.success(
                'Die exportierte Datei kann jederzeit importiert werden, um das Turnier wiederherzustellen.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Abbrechen',
              style: TextStyle(color: GroupPhaseColors.steelblue),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('JSON Export wird heruntergeladen...')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportieren'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupPhaseColors.steelblue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle JSON team import
  static Future<void> handleImportTeams(BuildContext context) async {
    if (!_verifyAdmin(context)) return;
    await ImportService.uploadTeamsFromJson(context);
  }

  static Widget _exportItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: FieldColors.springgreen, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
