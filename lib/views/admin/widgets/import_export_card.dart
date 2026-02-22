import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/services/import_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/file_download.dart' as file_download;
import 'package:pongstrong/views/admin/admin_panel_state.dart';
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

  /// Callback triggered when the user wants to import teams (JSON).
  final VoidCallback? onImportTeamsJson;

  /// Callback triggered when the user wants to import a full snapshot.
  final VoidCallback? onImportSnapshot;

  final bool isCompact;

  /// Legacy alias so existing call-sites keep working.
  VoidCallback? get onImportJson => onImportTeams;

  const ImportExportCard({
    super.key,
    this.onImportTeams,
    this.onImportTeamsJson,
    this.onImportSnapshot,
    this.isCompact = false,
  });

  Future<void> _exportTournamentState(BuildContext context) async {
    try {
      final tournamentState =
          Provider.of<TournamentDataState>(context, listen: false).toJson();

      // Augment with numberOfTables and groups from AdminPanelState
      try {
        final adminState = Provider.of<AdminPanelState>(context, listen: false);
        tournamentState['numberOfTables'] = adminState.numberOfTables;
        if (adminState.groups.groups.isNotEmpty) {
          tournamentState['groups'] = adminState.groups.toJson();
        }
      } catch (_) {
        // AdminPanelState may not be in the widget tree – export without
      }

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
            SizedBox(
              width: double.infinity,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'import_teams':
                      onImportTeams?.call();
                    case 'import_teams_json':
                      onImportTeamsJson?.call();
                    case 'import_snapshot':
                      onImportSnapshot?.call();
                    case 'export_teams':
                      _exportTeamsCsv(context);
                    case 'export_snapshot':
                      _exportTournamentState(context);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'import_teams',
                    child: ListTile(
                      title: Text('Teams importieren (CSV)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import_teams_json',
                    child: ListTile(
                      title: Text('Teams importieren (JSON)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import_snapshot',
                    child: ListTile(
                      title: Text('Snapshot importieren (JSON)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'export_teams',
                    child: ListTile(
                      title: Text('Teams exportieren (CSV)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export_snapshot',
                    child: ListTile(
                      title: Text('Snapshot exportieren (JSON)'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Typ wählen'),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
