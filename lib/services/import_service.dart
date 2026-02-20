import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/admin/admin_panel_state.dart';
import 'package:provider/provider.dart';

/// Handles importing and exporting tournament data via JSON files.
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
            member1: teamJson['mem1'] as String? ?? '',
            member2: teamJson['mem2'] as String? ?? '',
          );
          allTeams.add(team);
          groupIds.add(teamId);
        }
        groupTeamIds.add(groupIds);
      }
    } else if (jsonData is Map<String, dynamic>) {
      // Handle the alternative format with separate teams and groups
      final teamsList = jsonData['teams'] as List;

      for (final teamJson in teamsList) {
        final teamMap = teamJson as Map<String, dynamic>;
        final team = Team(
          id: teamMap['id'] as String,
          name: teamMap['name'] as String,
          member1: teamMap['mem1'] as String? ?? '',
          member2: teamMap['mem2'] as String? ?? '',
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

  /// Parse teams from a flat JSON array (no groups) for round-robin / KO-only
  /// Expected JSON format:
  /// [
  ///   {"name": "Thunder", "mem1": "Alice", "mem2": "Bob"},
  ///   ...
  /// ]
  /// OR: { "teams": [...] }
  static List<Team> parseTeamsFlatFromJson(dynamic jsonData) {
    final allTeams = <Team>[];

    if (jsonData is List) {
      // Check if first element is also a list (group format) -> flatten
      if (jsonData.isNotEmpty && jsonData[0] is List) {
        // Flatten group format
        int idx = 0;
        for (final group in jsonData) {
          for (final teamJson in (group as List)) {
            final map = teamJson as Map<String, dynamic>;
            allTeams.add(Team(
              id: 'team_$idx',
              name: map['name'] as String,
              member1: map['mem1'] as String? ?? '',
              member2: map['mem2'] as String? ?? '',
            ));
            idx++;
          }
        }
      } else {
        // Flat list of teams
        for (int i = 0; i < jsonData.length; i++) {
          final teamJson = jsonData[i] as Map<String, dynamic>;
          allTeams.add(Team(
            id: teamJson['id'] as String? ?? 'team_$i',
            name: teamJson['name'] as String,
            member1: teamJson['mem1'] as String? ?? '',
            member2: teamJson['mem2'] as String? ?? '',
          ));
        }
      }
    } else if (jsonData is Map<String, dynamic>) {
      final teamsList = jsonData['teams'] as List;
      for (int i = 0; i < teamsList.length; i++) {
        final teamJson = teamsList[i] as Map<String, dynamic>;
        allTeams.add(Team(
          id: teamJson['id'] as String? ?? 'team_$i',
          name: teamJson['name'] as String,
          member1: teamJson['mem1'] as String? ?? '',
          member2: teamJson['mem2'] as String? ?? '',
        ));
      }
    }

    return allTeams;
  }

  /// Upload teams from JSON file
  /// Uses the currently selected tournament ID from TournamentSelectionState
  /// Adapts behavior based on the current tournament style
  static Future<void> uploadTeamsFromJson(BuildContext context) async {
    // Get the current tournament ID from selection state
    final selectionState =
        Provider.of<TournamentSelectionState>(context, listen: false);
    final tournamentId = selectionState.selectedTournamentId ??
        FirestoreBase.defaultTournamentId;

    // Determine tournament style if AdminPanelState is available
    TournamentStyle? style;
    try {
      final adminState = Provider.of<AdminPanelState>(context, listen: false);
      style = adminState.tournamentStyle;
    } catch (_) {
      // AdminPanelState might not be in the tree - defaults to group+KO
      style = TournamentStyle.groupsAndKnockouts;
    }

    try {
      // Pick JSON file
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
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

      final service = FirestoreService();

      if (style == TournamentStyle.groupsAndKnockouts) {
        // Parse teams and groups from JSON (with group structure)
        final result2 = ImportService.parseTeamsFromJson(jsonData);
        final allTeams = result2.$1;
        final groups = result2.$2;

        Logger.info(
            'Loaded ${allTeams.length} teams from JSON in ${groups.groups.length} groups',
            tag: 'ImportService');

        await service.importTeamsAndGroups(
          allTeams,
          groups,
          tournamentId: tournamentId,
        );
        Logger.info('Teams and groups imported from JSON for $tournamentId',
            tag: 'ImportService');

        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${allTeams.length} Teams und ${groups.groups.length} Gruppen importiert!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Parse teams without groups (round-robin / KO-only)
        final allTeams = ImportService.parseTeamsFlatFromJson(jsonData);

        Logger.info(
            'Loaded ${allTeams.length} teams from JSON (flat, no groups)',
            tag: 'ImportService');

        await service.importTeamsOnly(
          allTeams,
          tournamentId: tournamentId,
        );
        Logger.info('Teams imported (flat) from JSON for $tournamentId',
            tag: 'ImportService');

        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${allTeams.length} Teams importiert!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Reload tournament data into state
      if (context.mounted) {
        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        await tournamentData.loadTournamentData(tournamentId);
        Logger.info('Data loaded into app state', tag: 'ImportService');
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
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
