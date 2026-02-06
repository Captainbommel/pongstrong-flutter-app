import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/app_logger.dart';

class ImportService {
  /// Parse teams from JSON data
  /// Expected JSON format (nested array of groups):
  /// [
  ///   [
  ///     {"name": "Thunder", "mem1": "Alice", "mem2": "Bob"},
  ///     {"name": "Lightning", "mem1": "Charlie", "mem2": "Diana"},
  ///     ...
  ///   ],
  ///   [next group],
  ///   ...
  /// ]
  /// OR alternative format with teams and groups objects:
  /// {
  ///   "teams": [...],
  ///   "groups": [["team_id1", ...], ...]
  /// }
  static (List<Team>, Groups) parseTeamsFromJson(dynamic jsonData) {
    final allTeams = <Team>[];
    final groupTeamIds = <List<String>>[];

    // Check if it's the nested array format (array of groups)
    if (jsonData is List) {
      for (int groupIndex = 0; groupIndex < jsonData.length; groupIndex++) {
        final group = jsonData[groupIndex] as List;
        final groupIds = <String>[];

        for (int teamIndex = 0; teamIndex < group.length; teamIndex++) {
          final teamJson = group[teamIndex] as Map<String, dynamic>;
          final teamId = 'team_${groupIndex}_$teamIndex';

          final team = Team(
            id: teamId,
            name: teamJson['name'] as String,
            mem1: teamJson['mem1'] as String? ?? '',
            mem2: teamJson['mem2'] as String? ?? '',
          );
          allTeams.add(team);
          groupIds.add(teamId);
        }
        groupTeamIds.add(groupIds);
      }
    } else if (jsonData is Map<String, dynamic>) {
      // Handle the alternative format with separate teams and groups
      final teamsList = jsonData['teams'] as List;

      for (var teamJson in teamsList) {
        final team = Team(
          id: teamJson['id'] as String,
          name: teamJson['name'] as String,
          mem1: teamJson['mem1'] as String? ?? '',
          mem2: teamJson['mem2'] as String? ?? '',
        );
        allTeams.add(team);
      }

      final groupsList = (jsonData['groups'] as List)
          .map((group) => (group as List).map((id) => id.toString()).toList())
          .toList();
      groupTeamIds.addAll(groupsList);
    }

    final groups = Groups(groups: groupTeamIds);
    return (allTeams, groups);
  }

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

      Logger.info(
          'Loaded ${allTeams.length} teams from JSON in ${groups.groups.length} groups',
          tag: 'ImportService');

      // Import teams and groups only (without starting the tournament)
      final service = FirestoreService();
      await service.importTeamsAndGroups(
        allTeams,
        groups,
        tournamentId: tournamentId,
      );
      Logger.info('Teams and groups imported from JSON for $tournamentId',
          tag: 'ImportService');

      // Load teams from Firestore to update the UI
      final loadedTeams = await service.loadTeams(
        tournamentId: tournamentId,
      );

      // Update the TournamentDataState with just teams (no matches yet)
      if (context.mounted && loadedTeams != null) {
        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        await tournamentData.loadTournamentData(tournamentId);
        Logger.info('Data loaded into app state', tag: 'ImportService');
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
    } catch (e) {
      Logger.error('Error loading teams from JSON',
          tag: 'ImportService', error: e);

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
