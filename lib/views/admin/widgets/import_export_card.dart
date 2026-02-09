import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'dart:convert';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;

/// Card widget for import/export functionality
class ImportExportCard extends StatelessWidget {
  final VoidCallback? onImportJson;
  final VoidCallback? onExportJson;
  final bool isCompact;

  const ImportExportCard({
    super.key,
    this.onImportJson,
    this.onExportJson,
    this.isCompact = false,
  });

  void _exportTournamentState(BuildContext context) async {
    try {
      // Retrieve the tournament state using Provider
      final tournamentState =
          Provider.of<TournamentDataState>(context, listen: false).toJson();

      // Convert the state to JSON
      final jsonString = jsonEncode(tournamentState);

      // Create a Blob and trigger a download
      final blob = html.Blob([jsonString], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = 'tournament_state.json';
      anchor.click();
      html.Url.revokeObjectUrl(url);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tournament state downloaded as JSON file!')),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export tournament state: $e')),
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
