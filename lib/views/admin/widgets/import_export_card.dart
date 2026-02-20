import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/services/import_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/file_download.dart' as file_download;
import 'package:provider/provider.dart';

/// Card widget for import/export functionality.
///
/// Supports:
/// - **Team import** from CSV files (with or without groups).
/// - **Snapshot import** from a JSON file to restore an entire tournament.
/// - **Snapshot export** as JSON to create a freeze-frame of the tournament.
/// - **Team CSV export** for easy editing in spreadsheet software.
///
/// Export uses a conditional import so that `dart:js_interop` / `package:web`
/// are only loaded on the web — native platforms get a safe stub.
class ImportExportCard extends StatelessWidget {
  /// Callback triggered when the user wants to import teams (CSV).
  final VoidCallback? onImportTeams;

  /// Callback triggered when the user wants to import a full snapshot.
  final VoidCallback? onImportSnapshot;

  final bool isCompact;

  /// Legacy alias so existing call-sites keep working.
  VoidCallback? get onImportJson => onImportTeams;

  const ImportExportCard({
    super.key,
    this.onImportTeams,
    this.onImportSnapshot,
    this.isCompact = false,
  });

  Future<void> _exportTournamentState(BuildContext context) async {
    try {
      final tournamentState =
          Provider.of<TournamentDataState>(context, listen: false).toJson();
      final jsonString = jsonEncode(tournamentState);

      await file_download.downloadFile(jsonString, 'tournament_state.json');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Turnierstatus als JSON-Datei heruntergeladen!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Export: $e')),
      );
    }
  }

  Future<void> _exportTeamsCsv(BuildContext context) async {
    try {
      final state = Provider.of<TournamentDataState>(context, listen: false);
      final teams = state.teams;

      // Try to load groups from Firestore for a grouped export.
      String csvContent;
      try {
        final service = FirestoreService();
        final groups =
            await service.loadGroups(tournamentId: state.currentTournamentId);
        if (groups != null && groups.groups.isNotEmpty) {
          csvContent = ImportService.exportTeamsToCsv(teams, groups);
        } else {
          csvContent = ImportService.exportTeamsFlatToCsv(teams);
        }
      } catch (_) {
        csvContent = ImportService.exportTeamsFlatToCsv(teams);
      }

      await file_download.downloadFile(csvContent, 'teams.csv');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teams als CSV-Datei heruntergeladen!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim CSV-Export: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, color: TableColors.turquoise),
                const SizedBox(width: 8),
                Text(
                  'Import / Export',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),

            // ── Import section ──
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Import',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textDisabled),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImportTeams,
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Teams (CSV)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TableColors.turquoise,
                      foregroundColor: AppColors.textOnColored,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImportSnapshot,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Snapshot (JSON)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GroupPhaseColors.steelblue,
                      foregroundColor: AppColors.textOnColored,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Export section ──
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Export',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textDisabled),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportTeamsCsv(context),
                    label: const Text('Teams'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TableColors.turquoise,
                      foregroundColor: AppColors.textOnColored,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportTournamentState(context),
                    label: const Text('Snapshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GroupPhaseColors.steelblue,
                      foregroundColor: AppColors.textOnColored,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
