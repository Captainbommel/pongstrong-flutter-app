import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/services/import_service.dart';
import 'package:pongstrong/shared/tournament_data_state.dart';
import 'package:pongstrong/shared/tournament_selection_state.dart';
import 'package:provider/provider.dart';

/// Utilities for uploading tournament data from JSON to Firestore
class TestDataHelpers {
  /// Upload teams from JSON file
  /// Uses the currently selected tournament ID from TournamentSelectionState
  static Future<void> uploadTeamsFromJson(BuildContext context) async {
    // Get the current tournament ID from selection state
    final selectionState =
        Provider.of<TournamentSelectionState>(context, listen: false);
    final tournamentId = selectionState.selectedTournamentId ??
        FirestoreBase.defaultTournamentId;
    try {
      // Pick JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Teams JSON File',
      );

      if (result == null || result.files.single.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
        return;
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading teams from JSON...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Read and parse JSON
      final bytes = result.files.single.bytes!;
      final jsonString = utf8.decode(bytes);
      final jsonData = json.decode(jsonString);

      // Parse teams and groups from JSON
      final result2 = ImportService.parseTeamsFromJson(jsonData);
      final allTeams = result2.$1;
      final groups = result2.$2;

      debugPrint(
          'Loaded ${allTeams.length} teams from JSON in ${groups.groups.length} groups');

      // Import teams and groups only (without starting the tournament)
      final service = FirestoreService();
      await service.importTeamsAndGroups(
        allTeams,
        groups,
        tournamentId: tournamentId,
      );
      debugPrint('   ✓ Teams and groups imported from JSON for $tournamentId');

      // Load teams from Firestore to update the UI
      final loadedTeams = await service.loadTeams(
        tournamentId: tournamentId,
      );

      // Update the TournamentDataState with just teams (no matches yet)
      if (context.mounted && loadedTeams != null) {
        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        await tournamentData.loadTournamentData(tournamentId);
        debugPrint('✓ Data loaded into app state');
      }

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${allTeams.length} Teams und ${groups.groups.length} Gruppen importiert!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading teams from JSON: $e');
      debugPrint('Stack trace: $stackTrace');

      // Close loading dialog if open
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading JSON: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
