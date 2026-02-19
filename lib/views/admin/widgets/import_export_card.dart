import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/utils/file_download.dart' as file_download;
import 'package:provider/provider.dart';

/// Card widget for import/export functionality.
///
/// Export uses a conditional import so that `dart:js_interop` / `package:web`
/// are only loaded on the web — native platforms get a safe stub.
class ImportExportCard extends StatelessWidget {
  final VoidCallback? onImportJson;
  final bool isCompact;

  const ImportExportCard({
    super.key,
    this.onImportJson,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Turnierfortschritt speichern oder wiederherstellen',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onImportJson,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('JSON Import'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TableColors.turquoise,
                      foregroundColor: Colors.white,
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
                    icon: const Icon(Icons.download),
                    label: const Text('JSON Export'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GroupPhaseColors.steelblue,
                      foregroundColor: Colors.white,
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
