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

/// Handles importing and exporting tournament data via CSV and JSON files.
///
/// **Team import/export** uses CSV (easy to create/edit in Excel or any
/// spreadsheet application).
/// **Tournament snapshot import/export** uses JSON to preserve the full
/// internal state.
class ImportService {
  // ===================== JSON TEAM PARSING =====================

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

  // ===================== CSV TEAM PARSING =====================

  /// Finds the first column index matching any of the given [aliases].
  ///
  /// Returns -1 if none of the aliases are found in the header.
  static int _findColumnIndex(List<String> header, List<String> aliases) {
    for (final alias in aliases) {
      final idx = header.indexOf(alias);
      if (idx != -1) return idx;
    }
    return -1;
  }

  /// Escapes a single CSV field.
  ///
  /// If [value] contains commas, double-quotes, or newlines the field is
  /// wrapped in double-quotes with inner quotes doubled (RFC 4180).
  static String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Splits a CSV line into fields, respecting quoted fields.
  ///
  /// Handles commas and newlines inside double-quoted fields and un-escapes
  /// doubled quotes (`""` → `"`).
  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          // Check for escaped quote
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  /// Parse teams **with group assignments** from a CSV string.
  ///
  /// Expected CSV format (header required):
  /// ```csv
  /// group,name,member1,member2
  /// 1,Thunder,Alice,Bob
  /// 1,Lightning,Charlie,Diana
  /// 2,Storm,Eve,Frank
  /// ```
  ///
  /// The `group` column can be a number (1-based) or any text label
  /// (e.g. "Gruppe A"). Groups are ordered by first appearance.
  /// Accepts `mem1`/`mem2` or `member1`/`member2` as header aliases.
  static (List<Team>, Groups) parseTeamsFromCsv(String csvContent) {
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return (<Team>[], Groups());

    // Parse header to find column indices
    final header =
        _parseCsvLine(lines[0]).map((h) => h.toLowerCase().trim()).toList();
    final groupIdx = _findColumnIndex(header, ['group', 'gruppe']);
    final nameIdx = _findColumnIndex(header, ['name', 'team']);
    final mem1Idx = _findColumnIndex(header, ['mem1', 'member1', 'spieler1']);
    final mem2Idx = _findColumnIndex(header, ['mem2', 'member2', 'spieler2']);

    if (nameIdx == -1) {
      throw FormatException(
          'CSV header must contain a "name" column. Found: ${lines[0]}');
    }
    if (groupIdx == -1) {
      throw const FormatException(
          'CSV header must contain a "group" column for grouped import.');
    }

    final allTeams = <Team>[];
    // Ordered map: group label → (groupIndex, list of team IDs)
    final groupOrder = <String, int>{};
    final groupTeams = <int, List<String>>{};

    for (int i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length <= nameIdx) continue; // skip malformed rows

      final groupLabel = fields[groupIdx].trim();
      // Assign a 0-based group index by first-appearance order
      final groupIndex =
          groupOrder.putIfAbsent(groupLabel, () => groupOrder.length);
      final teamIndex = allTeams.length;
      final teamId = 'team_${groupIndex}_$teamIndex';

      allTeams.add(Team(
        id: teamId,
        name: fields[nameIdx].trim(),
        member1: (mem1Idx != -1 && fields.length > mem1Idx)
            ? fields[mem1Idx].trim()
            : '',
        member2: (mem2Idx != -1 && fields.length > mem2Idx)
            ? fields[mem2Idx].trim()
            : '',
      ));

      groupTeams.putIfAbsent(groupIndex, () => []);
      groupTeams[groupIndex]!.add(teamId);
    }

    // Build Groups in order of first appearance
    final sortedKeys = groupTeams.keys.toList()..sort();
    final groups =
        Groups(groups: sortedKeys.map((k) => groupTeams[k]!).toList());

    return (allTeams, groups);
  }

  /// Parse teams **without groups** from a CSV string (round-robin / KO-only).
  ///
  /// Expected CSV format (header required):
  /// ```csv
  /// name,member1,member2
  /// Thunder,Alice,Bob
  /// Lightning,Charlie,Diana
  /// ```
  ///
  /// Accepts `mem1`/`mem2` or `member1`/`member2` as header aliases.
  /// A `group` column, if present, is simply ignored.
  static List<Team> parseTeamsFlatFromCsv(String csvContent) {
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final header =
        _parseCsvLine(lines[0]).map((h) => h.toLowerCase().trim()).toList();
    final nameIdx = _findColumnIndex(header, ['name', 'team']);
    final mem1Idx = _findColumnIndex(header, ['mem1', 'member1', 'spieler1']);
    final mem2Idx = _findColumnIndex(header, ['mem2', 'member2', 'spieler2']);

    if (nameIdx == -1) {
      throw FormatException(
          'CSV header must contain a "name" column. Found: ${lines[0]}');
    }

    final allTeams = <Team>[];
    for (int i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length <= nameIdx) continue;

      allTeams.add(Team(
        id: 'team_${allTeams.length}',
        name: fields[nameIdx].trim(),
        member1: (mem1Idx != -1 && fields.length > mem1Idx)
            ? fields[mem1Idx].trim()
            : '',
        member2: (mem2Idx != -1 && fields.length > mem2Idx)
            ? fields[mem2Idx].trim()
            : '',
      ));
    }

    return allTeams;
  }

  // ===================== CSV EXPORT =====================

  /// Export teams with group assignments to a CSV string.
  ///
  /// Produces a header row followed by one row per team:
  /// ```csv
  /// group,name,member1,member2
  /// 1,Thunder,Alice,Bob
  /// ```
  static String exportTeamsToCsv(List<Team> teams, Groups groups) {
    final buffer = StringBuffer();
    buffer.writeln('group,name,member1,member2');

    for (int g = 0; g < groups.groups.length; g++) {
      for (final teamId in groups.groups[g]) {
        final team = teams.firstWhere(
          (t) => t.id == teamId,
          orElse: () => Team(id: teamId, name: teamId),
        );
        buffer.writeln(
          '${g + 1},'
          '${_escapeCsvField(team.name)},'
          '${_escapeCsvField(team.member1)},'
          '${_escapeCsvField(team.member2)}',
        );
      }
    }
    return buffer.toString();
  }

  /// Export a flat team list (no groups) to a CSV string.
  ///
  /// Produces a header row followed by one row per team:
  /// ```csv
  /// name,member1,member2
  /// Thunder,Alice,Bob
  /// ```
  static String exportTeamsFlatToCsv(List<Team> teams) {
    final buffer = StringBuffer();
    buffer.writeln('name,member1,member2');

    for (final team in teams) {
      buffer.writeln(
        '${_escapeCsvField(team.name)},'
        '${_escapeCsvField(team.member1)},'
        '${_escapeCsvField(team.member2)}',
      );
    }
    return buffer.toString();
  }

  // ===================== TOURNAMENT SNAPSHOT =====================

  /// Checks whether [jsonData] represents a full tournament snapshot
  /// (as produced by [TournamentDataState.toJson]).
  static bool isSnapshotJson(dynamic jsonData) {
    if (jsonData is! Map<String, dynamic>) return false;
    return jsonData.containsKey('teams') &&
        jsonData.containsKey('matchQueue') &&
        jsonData.containsKey('gruppenphase');
  }

  /// Parses a full tournament snapshot JSON into all state objects.
  ///
  /// Returns a record containing every field needed to fully restore a
  /// tournament's in-memory state.
  static ({
    List<Team> teams,
    MatchQueue matchQueue,
    Gruppenphase gruppenphase,
    Tabellen tabellen,
    Knockouts knockouts,
    String currentTournamentId,
    bool isKnockoutMode,
    String tournamentStyle,
    String? selectedRuleset,
  }) parseSnapshotFromJson(Map<String, dynamic> jsonData) {
    final teams = (jsonData['teams'] as List)
        .map((t) => Team.fromJson(t as Map<String, dynamic>))
        .toList();

    final matchQueue =
        MatchQueue.fromJson(jsonData['matchQueue'] as Map<String, dynamic>);

    final gruppenphase =
        Gruppenphase.fromJson(jsonData['gruppenphase'] as List);

    final tabellen = Tabellen.fromJson(jsonData['tabellen'] as List);

    final knockouts =
        Knockouts.fromJson(jsonData['knockouts'] as Map<String, dynamic>);

    final currentTournamentId =
        (jsonData['currentTournamentId'] as String?) ?? '';
    final isKnockoutMode = (jsonData['isKnockoutMode'] as bool?) ?? false;
    final tournamentStyle =
        (jsonData['tournamentStyle'] as String?) ?? 'groupsAndKnockouts';
    final selectedRuleset = jsonData['selectedRuleset'] as String?;

    return (
      teams: teams,
      matchQueue: matchQueue,
      gruppenphase: gruppenphase,
      tabellen: tabellen,
      knockouts: knockouts,
      currentTournamentId: currentTournamentId,
      isKnockoutMode: isKnockoutMode,
      tournamentStyle: tournamentStyle,
      selectedRuleset: selectedRuleset,
    );
  }

  // ===================== FILE UPLOAD HANDLERS =====================

  /// Upload teams from a CSV file.
  /// Uses the currently selected tournament ID from TournamentSelectionState.
  /// Adapts behavior based on the current tournament style.
  static Future<void> uploadTeamsFromFile(BuildContext context) async {
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
      // Pick CSV file
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Teams importieren (CSV)',
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
                    Text('Teams werden importiert...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final bytes = result.files.single.bytes!;
      final csvContent = utf8.decode(bytes);

      final service = FirestoreService();

      if (style == TournamentStyle.groupsAndKnockouts) {
        final parsed = ImportService.parseTeamsFromCsv(csvContent);
        final allTeams = parsed.$1;
        final groups = parsed.$2;

        Logger.info(
            'Loaded ${allTeams.length} teams from CSV in ${groups.groups.length} groups',
            tag: 'ImportService');

        await service.importTeamsAndGroups(
          allTeams,
          groups,
          tournamentId: tournamentId,
        );

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
        final allTeams = ImportService.parseTeamsFlatFromCsv(csvContent);

        Logger.info(
            'Loaded ${allTeams.length} teams from CSV (flat, no groups)',
            tag: 'ImportService');

        await service.importTeamsOnly(
          allTeams,
          tournamentId: tournamentId,
        );

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

      // Also refresh AdminPanelState so dropdowns stay in sync
      if (context.mounted) {
        try {
          final adminState =
              Provider.of<AdminPanelState>(context, listen: false);
          await adminState.loadTeams();
          await adminState.loadGroups();
          Logger.info('Admin panel state refreshed', tag: 'ImportService');
        } catch (_) {
          // AdminPanelState may not be in the widget tree
        }
      }
    } catch (e) {
      Logger.error('Error loading teams from CSV',
          tag: 'ImportService', error: e);

      // Close loading dialog if open
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Upload a full tournament snapshot from a JSON file and restore it.
  static Future<void> uploadSnapshotFromJson(BuildContext context) async {
    final selectionState =
        Provider.of<TournamentSelectionState>(context, listen: false);
    final tournamentId = selectionState.selectedTournamentId ??
        FirestoreBase.defaultTournamentId;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Turnier-Snapshot importieren (JSON)',
      );

      if (result == null || result.files.single.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
        return;
      }

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
                    Text('Turnier-Snapshot wird wiederhergestellt...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final bytes = result.files.single.bytes!;
      final jsonString = utf8.decode(bytes);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      if (!isSnapshotJson(jsonData)) {
        throw const FormatException(
            'Die Datei enthält keinen gültigen Turnier-Snapshot.');
      }

      final snapshot = parseSnapshotFromJson(jsonData);

      Logger.info(
          'Parsed snapshot with ${snapshot.teams.length} teams, style=${snapshot.tournamentStyle}',
          tag: 'ImportService');

      // Restore into TournamentDataState (which also persists to Firestore)
      if (context.mounted) {
        final tournamentData =
            Provider.of<TournamentDataState>(context, listen: false);
        await tournamentData.restoreFromSnapshot(
          teams: snapshot.teams,
          matchQueue: snapshot.matchQueue,
          gruppenphase: snapshot.gruppenphase,
          tabellen: snapshot.tabellen,
          knockouts: snapshot.knockouts,
          isKnockoutMode: snapshot.isKnockoutMode,
          tournamentStyle: snapshot.tournamentStyle,
          selectedRuleset: snapshot.selectedRuleset,
          tournamentId: tournamentId,
        );
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Turnier-Snapshot wiederhergestellt (${snapshot.teams.length} Teams)'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error restoring tournament snapshot',
          tag: 'ImportService', error: e);

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Snapshot-Import: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Upload teams from a JSON file.
  /// Supports grouped format (array of groups) and flat format.
  /// Uses the currently selected tournament ID from TournamentSelectionState.
  static Future<void> uploadTeamsFromJson(BuildContext context) async {
    final selectionState =
        Provider.of<TournamentSelectionState>(context, listen: false);
    final tournamentId = selectionState.selectedTournamentId ??
        FirestoreBase.defaultTournamentId;

    TournamentStyle? style;
    try {
      final adminState = Provider.of<AdminPanelState>(context, listen: false);
      style = adminState.tournamentStyle;
    } catch (_) {
      style = TournamentStyle.groupsAndKnockouts;
    }

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Teams importieren (JSON)',
      );

      if (result == null || result.files.single.bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
        return;
      }

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
                    Text('Teams werden importiert...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final bytes = result.files.single.bytes!;
      final jsonString = utf8.decode(bytes);
      final jsonData = json.decode(jsonString);

      // Reject full snapshots – those should use "Snapshot importieren"
      if (jsonData is Map<String, dynamic> && isSnapshotJson(jsonData)) {
        if (context.mounted) Navigator.pop(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Diese Datei ist ein Turnier-Snapshot. Bitte "Snapshot importieren" verwenden.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final service = FirestoreService();

      if (style == TournamentStyle.groupsAndKnockouts) {
        final parsed = ImportService.parseTeamsFromJson(jsonData);
        final allTeams = parsed.$1;
        final groups = parsed.$2;

        Logger.info(
            'Loaded ${allTeams.length} teams from JSON in ${groups.groups.length} groups',
            tag: 'ImportService');

        await service.importTeamsAndGroups(
          allTeams,
          groups,
          tournamentId: tournamentId,
        );

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
        final allTeams = ImportService.parseTeamsFlatFromJson(jsonData);

        Logger.info(
            'Loaded ${allTeams.length} teams from JSON (flat, no groups)',
            tag: 'ImportService');

        await service.importTeamsOnly(
          allTeams,
          tournamentId: tournamentId,
        );

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

      // Also refresh AdminPanelState so dropdowns stay in sync
      if (context.mounted) {
        try {
          final adminState =
              Provider.of<AdminPanelState>(context, listen: false);
          await adminState.loadTeams();
          await adminState.loadGroups();
          Logger.info('Admin panel state refreshed', tag: 'ImportService');
        } catch (_) {
          // AdminPanelState may not be in the widget tree
        }
      }
    } catch (e) {
      Logger.error('Error loading teams from JSON',
          tag: 'ImportService', error: e);

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
