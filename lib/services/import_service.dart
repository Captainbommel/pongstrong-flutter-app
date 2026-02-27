import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/services/firestore_service/firestore_service.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/state/tournament_selection_state.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/snackbar_helper.dart';
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
  ///     {"name": "Thunder", "member1": "Alice", "member2": "Bob"},
  ///     {"name": "Lightning", "member1": "Charlie", "member2": "Diana"},
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
          final teamId = 'team-$groupIndex-$teamIndex';

          final team = Team(
            id: teamId,
            name: teamJson['name'] as String,
            member1: teamJson['member1'] as String? ?? '',
            member2: teamJson['member2'] as String? ?? '',
            member3: teamJson['member3'] as String? ?? '',
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
          member1: teamMap['member1'] as String? ?? '',
          member2: teamMap['member2'] as String? ?? '',
          member3: teamMap['member3'] as String? ?? '',
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
  ///   {"name": "Thunder", "member1": "Alice", "member2": "Bob"},
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
              id: 'team-$idx',
              name: map['name'] as String,
              member1: map['member1'] as String? ?? '',
              member2: map['member2'] as String? ?? '',
              member3: map['member3'] as String? ?? '',
            ));
            idx++;
          }
        }
      } else {
        // Flat list of teams
        for (int i = 0; i < jsonData.length; i++) {
          final teamJson = jsonData[i] as Map<String, dynamic>;
          allTeams.add(Team(
            id: teamJson['id'] as String? ?? 'team-$i',
            name: teamJson['name'] as String,
            member1: teamJson['member1'] as String? ?? '',
            member2: teamJson['member2'] as String? ?? '',
            member3: teamJson['member3'] as String? ?? '',
          ));
        }
      }
    } else if (jsonData is Map<String, dynamic>) {
      final teamsList = jsonData['teams'] as List;
      for (int i = 0; i < teamsList.length; i++) {
        final teamJson = teamsList[i] as Map<String, dynamic>;
        allTeams.add(Team(
          id: teamJson['id'] as String? ?? 'team-$i',
          name: teamJson['name'] as String,
          member1: teamJson['member1'] as String? ?? '',
          member2: teamJson['member2'] as String? ?? '',
          member3: teamJson['member3'] as String? ?? '',
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
    final mem1Idx = _findColumnIndex(header, ['member1', 'spieler1']);
    final mem2Idx = _findColumnIndex(header, ['member2', 'spieler2']);
    final mem3Idx = _findColumnIndex(header, ['member3', 'spieler3']);

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
      final teamId = 'team-$groupIndex-$teamIndex';

      allTeams.add(Team(
        id: teamId,
        name: fields[nameIdx].trim(),
        member1: (mem1Idx != -1 && fields.length > mem1Idx)
            ? fields[mem1Idx].trim()
            : '',
        member2: (mem2Idx != -1 && fields.length > mem2Idx)
            ? fields[mem2Idx].trim()
            : '',
        member3: (mem3Idx != -1 && fields.length > mem3Idx)
            ? fields[mem3Idx].trim()
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
    final mem1Idx = _findColumnIndex(header, ['member1', 'spieler1']);
    final mem2Idx = _findColumnIndex(header, ['member2', 'spieler2']);
    final mem3Idx = _findColumnIndex(header, ['member3', 'spieler3']);

    if (nameIdx == -1) {
      throw FormatException(
          'CSV header must contain a "name" column. Found: ${lines[0]}');
    }

    final allTeams = <Team>[];
    for (int i = 1; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]);
      if (fields.length <= nameIdx) continue;

      allTeams.add(Team(
        id: 'team-${allTeams.length}',
        name: fields[nameIdx].trim(),
        member1: (mem1Idx != -1 && fields.length > mem1Idx)
            ? fields[mem1Idx].trim()
            : '',
        member2: (mem2Idx != -1 && fields.length > mem2Idx)
            ? fields[mem2Idx].trim()
            : '',
        member3: (mem3Idx != -1 && fields.length > mem3Idx)
            ? fields[mem3Idx].trim()
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
    buffer.writeln('group,name,member1,member2,member3');

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
          '${_escapeCsvField(team.member2)},'
          '${_escapeCsvField(team.member3)}',
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
    buffer.writeln('name,member1,member2,member3');

    for (final team in teams) {
      buffer.writeln(
        '${_escapeCsvField(team.name)},'
        '${_escapeCsvField(team.member1)},'
        '${_escapeCsvField(team.member2)},'
        '${_escapeCsvField(team.member3)}',
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
    int numberOfTables,
    Groups groups,
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

    // numberOfTables – defaults to 6 for backward compatibility with older
    // snapshots that didn't include this field.
    final numberOfTables = (jsonData['numberOfTables'] as num?)?.toInt() ?? 6;

    // groups – team-to-group assignments.  Older snapshots may omit this.
    Groups groups;
    if (jsonData.containsKey('groups') &&
        jsonData['groups'] is Map<String, dynamic>) {
      groups = Groups.fromJson(jsonData['groups'] as Map<String, dynamic>);
    } else {
      groups = Groups();
    }

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
      numberOfTables: numberOfTables,
      groups: groups,
    );
  }

  // ===================== SNAPSHOT VALIDATION =====================

  /// Validates a parsed snapshot for structural integrity.
  ///
  /// Returns a list of human-readable error strings. An empty list means
  /// the snapshot is valid. Checks performed:
  ///
  /// 1. **Knockout bracket tree structure** – each round must have exactly
  ///    half the matches of the previous round.
  /// 2. **Super Cup size** – must have exactly 0 or 2 matches.
  /// 3. **Team ID referential integrity** – every non-empty team ID in
  ///    matches (gruppenphase, knockouts, match queue) must refer to a team
  ///    in the teams list.
  /// 4. **Match ID uniqueness** – no duplicate IDs across all collections.
  /// 5. **Gruppenphase / Tabellen consistency** – both must have the same
  ///    number of groups when non-empty.
  /// 6. **Done / score consistency** – finished matches must have valid
  ///    scores (per [isValid]).
  /// 7. **Match queue integrity** – no match ID may appear in both waiting
  ///    and playing.
  /// 8. **numberOfTables** – must be at least 1.
  /// 9. **Groups / teams consistency** – every team ID in groups must
  ///    reference an existing team.
  static List<String> validateSnapshot({
    required List<Team> teams,
    required MatchQueue matchQueue,
    required Gruppenphase gruppenphase,
    required Tabellen tabellen,
    required Knockouts knockouts,
    int numberOfTables = 6,
    Groups? groups,
  }) {
    final errors = <String>[];

    // ---- helpers -----------------------------------------------------------
    final teamIds = teams.map((t) => t.id).toSet();

    // ---- 0. Team ID uniqueness ---------------------------------------------
    {
      final seen = <String>{};
      for (final t in teams) {
        if (t.id.isNotEmpty && !seen.add(t.id)) {
          errors.add('Duplicate team ID "${t.id}".');
        }
      }
    }

    void checkTeamRef(String teamId, String context) {
      if (teamId.isNotEmpty && !teamIds.contains(teamId)) {
        errors.add('Unknown team ID "$teamId" in $context.');
      }
    }

    void checkMatchScore(Match m, String context) {
      if (m.done && !isValid(m.score1, m.score2)) {
        errors.add(
          'Match "${m.id}" in $context is marked done but has invalid '
          'scores (${m.score1} : ${m.score2}).',
        );
      }
    }

    /// Validates that each round halves the previous one.
    void checkBracketStructure(List<List<Match>> rounds, String bracketName) {
      if (rounds.isEmpty) return;
      for (int i = 1; i < rounds.length; i++) {
        final expected = (rounds[i - 1].length / 2).ceil();
        if (rounds[i].length != expected) {
          errors.add(
            '$bracketName round ${i + 1} has ${rounds[i].length} matches '
            "but should have $expected (half of round $i's "
            '${rounds[i - 1].length}).',
          );
        }
      }
    }

    // ---- 1. Knockout bracket tree structure --------------------------------
    checkBracketStructure(knockouts.champions.rounds, 'Champions');
    checkBracketStructure(knockouts.europa.rounds, 'Europa');
    checkBracketStructure(knockouts.conference.rounds, 'Conference');

    // ---- 2. Super Cup size -------------------------------------------------
    if (knockouts.superCup.matches.isNotEmpty &&
        knockouts.superCup.matches.length != 2) {
      errors.add(
        'Super Cup must have exactly 2 matches but has '
        '${knockouts.superCup.matches.length}.',
      );
    }

    // ---- 3. Team ID referential integrity ----------------------------------
    // Gruppenphase
    for (int g = 0; g < gruppenphase.groups.length; g++) {
      for (final m in gruppenphase.groups[g]) {
        checkTeamRef(m.teamId1, 'gruppenphase group $g');
        checkTeamRef(m.teamId2, 'gruppenphase group $g');
      }
    }
    // Knockouts
    for (final bracket in [
      ('Champions', knockouts.champions.rounds),
      ('Europa', knockouts.europa.rounds),
      ('Conference', knockouts.conference.rounds),
    ]) {
      for (final round in bracket.$2) {
        for (final m in round) {
          checkTeamRef(m.teamId1, bracket.$1);
          checkTeamRef(m.teamId2, bracket.$1);
        }
      }
    }
    for (final m in knockouts.superCup.matches) {
      checkTeamRef(m.teamId1, 'Super Cup');
      checkTeamRef(m.teamId2, 'Super Cup');
    }
    // Match queue
    for (int w = 0; w < matchQueue.waiting.length; w++) {
      for (final m in matchQueue.waiting[w]) {
        checkTeamRef(m.teamId1, 'matchQueue waiting[$w]');
        checkTeamRef(m.teamId2, 'matchQueue waiting[$w]');
      }
    }
    for (final m in matchQueue.playing) {
      checkTeamRef(m.teamId1, 'matchQueue playing');
      checkTeamRef(m.teamId2, 'matchQueue playing');
    }

    // ---- 4. Match ID uniqueness --------------------------------------------
    final allMatchIds = <String>{};
    void checkUniqueId(String id, String context) {
      if (id.isEmpty) return;
      if (!allMatchIds.add(id)) {
        errors.add('Duplicate match ID "$id" found in $context.');
      }
    }

    for (int g = 0; g < gruppenphase.groups.length; g++) {
      for (final m in gruppenphase.groups[g]) {
        checkUniqueId(m.id, 'gruppenphase group $g');
      }
    }
    for (final bracket in [
      ('Champions', knockouts.champions.rounds),
      ('Europa', knockouts.europa.rounds),
      ('Conference', knockouts.conference.rounds),
    ]) {
      for (final round in bracket.$2) {
        for (final m in round) {
          checkUniqueId(m.id, bracket.$1);
        }
      }
    }
    for (final m in knockouts.superCup.matches) {
      checkUniqueId(m.id, 'Super Cup');
    }

    // ---- 5. Gruppenphase / Tabellen consistency ----------------------------
    if (gruppenphase.groups.isNotEmpty && tabellen.tables.isNotEmpty) {
      if (gruppenphase.groups.length != tabellen.tables.length) {
        errors.add(
          'Gruppenphase has ${gruppenphase.groups.length} groups but '
          'Tabellen has ${tabellen.tables.length} tables.',
        );
      }
    }

    // ---- 6. Done / score consistency ---------------------------------------
    for (int g = 0; g < gruppenphase.groups.length; g++) {
      for (final m in gruppenphase.groups[g]) {
        checkMatchScore(m, 'gruppenphase group $g');
      }
    }
    for (final bracket in [
      ('Champions', knockouts.champions.rounds),
      ('Europa', knockouts.europa.rounds),
      ('Conference', knockouts.conference.rounds),
    ]) {
      for (final round in bracket.$2) {
        for (final m in round) {
          checkMatchScore(m, bracket.$1);
        }
      }
    }
    for (final m in knockouts.superCup.matches) {
      checkMatchScore(m, 'Super Cup');
    }

    // ---- 7. Match queue integrity ------------------------------------------
    final waitingIds = <String>{};
    for (final line in matchQueue.waiting) {
      for (final m in line) {
        waitingIds.add(m.id);
      }
    }
    for (final m in matchQueue.playing) {
      if (waitingIds.contains(m.id)) {
        errors.add(
          'Match "${m.id}" appears in both waiting and playing queues.',
        );
      }
    }

    // ---- 8. numberOfTables -------------------------------------------------
    if (numberOfTables < 1) {
      errors.add(
        'numberOfTables must be at least 1 but is $numberOfTables.',
      );
    }

    // ---- 9. Groups / teams consistency -------------------------------------
    if (groups != null && groups.groups.isNotEmpty) {
      for (int g = 0; g < groups.groups.length; g++) {
        for (final teamId in groups.groups[g]) {
          if (teamId.isNotEmpty && !teamIds.contains(teamId)) {
            errors.add(
              'Unknown team ID "$teamId" in groups group $g.',
            );
          }
        }
      }
    }

    return errors;
  }

  // ===================== FILE UPLOAD HANDLERS =====================

  // ─── Shared helpers ─────────────────────────────────────────

  static String _tournamentId(BuildContext context) {
    final selectionState =
        Provider.of<TournamentSelectionState>(context, listen: false);
    return selectionState.selectedTournamentId ??
        FirestoreBase.defaultTournamentId;
  }

  static TournamentStyle _tournamentStyle(BuildContext context) {
    try {
      return Provider.of<AdminPanelState>(context, listen: false)
          .tournamentStyle;
    } catch (_) {
      return TournamentStyle.groupsAndKnockouts;
    }
  }

  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Refreshes TournamentDataState and AdminPanelState after an import.
  static Future<void> _refreshState(
    BuildContext context,
    String tournamentId, {
    bool includeMetadata = false,
  }) async {
    if (context.mounted) {
      final tournamentData =
          Provider.of<TournamentDataState>(context, listen: false);
      await tournamentData.loadTournamentData(tournamentId);
    }
    if (context.mounted) {
      try {
        final adminState = Provider.of<AdminPanelState>(context, listen: false);
        if (includeMetadata) await adminState.loadTournamentMetadata();
        await adminState.loadTeams();
        await adminState.loadGroups();
      } catch (_) {
        // AdminPanelState may not be in the widget tree
      }
    }
  }

  /// Pick a file, show a loading spinner, run [action], then show result.
  ///
  /// Returns early (with no error) if the user cancels the file dialog.
  static Future<void> _withFilePickerAndDialog({
    required BuildContext context,
    required List<String> extensions,
    required String dialogTitle,
    required String loadingMessage,
    required String errorTag,
    required Future<String> Function(List<int> bytes) action,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        dialogTitle: dialogTitle,
      );
      if (result == null || result.files.single.bytes == null) return;

      if (context.mounted) _showLoadingDialog(context, loadingMessage);

      final successMessage = await action(result.files.single.bytes!);

      if (context.mounted) Navigator.pop(context);
      if (context.mounted) SnackBarHelper.showSuccess(context, successMessage);
    } catch (e) {
      Logger.error('Error in $errorTag', tag: 'ImportService', error: e);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Fehler beim Import: $e');
      }
    }
  }

  // ─── Public upload methods ──────────────────────────────────

  /// Upload teams from a CSV file.
  static Future<void> uploadTeamsFromFile(BuildContext context) async {
    final tournamentId = _tournamentId(context);
    final style = _tournamentStyle(context);

    await _withFilePickerAndDialog(
      context: context,
      extensions: ['csv'],
      dialogTitle: 'Teams importieren (CSV)',
      loadingMessage: 'Teams werden importiert...',
      errorTag: 'CSV team upload',
      action: (bytes) async {
        final csvContent = utf8.decode(bytes);
        final service = FirestoreService();
        String message;

        if (style == TournamentStyle.groupsAndKnockouts) {
          final (allTeams, groups) = parseTeamsFromCsv(csvContent);
          await service.importTeamsAndGroups(allTeams, groups,
              tournamentId: tournamentId);
          message =
              '${allTeams.length} Teams und ${groups.groups.length} Gruppen importiert!';
        } else {
          final allTeams = parseTeamsFlatFromCsv(csvContent);
          await service.importTeamsOnly(allTeams, tournamentId: tournamentId);
          message = '${allTeams.length} Teams importiert!';
        }

        if (context.mounted) await _refreshState(context, tournamentId);
        return message;
      },
    );
  }

  /// Upload a full tournament snapshot from a JSON file and restore it.
  static Future<void> uploadSnapshotFromJson(BuildContext context) async {
    final tournamentId = _tournamentId(context);

    await _withFilePickerAndDialog(
      context: context,
      extensions: ['json'],
      dialogTitle: 'Turnier-Snapshot importieren (JSON)',
      loadingMessage: 'Turnier-Snapshot wird wiederhergestellt...',
      errorTag: 'snapshot restore',
      action: (bytes) async {
        final jsonData =
            json.decode(utf8.decode(bytes)) as Map<String, dynamic>;

        if (!isSnapshotJson(jsonData)) {
          throw const FormatException(
              'Die Datei enthält keinen gültigen Turnier-Snapshot.');
        }

        final snapshot = parseSnapshotFromJson(jsonData);

        final validationErrors = validateSnapshot(
          teams: snapshot.teams,
          matchQueue: snapshot.matchQueue,
          gruppenphase: snapshot.gruppenphase,
          tabellen: snapshot.tabellen,
          knockouts: snapshot.knockouts,
          numberOfTables: snapshot.numberOfTables,
          groups: snapshot.groups,
        );
        if (validationErrors.isNotEmpty) {
          throw FormatException(
            'Snapshot-Validierung fehlgeschlagen:\n${validationErrors.join('\n')}',
          );
        }

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
            numberOfTables: snapshot.numberOfTables,
            groups: snapshot.groups,
          );
        }

        if (context.mounted) {
          await _refreshState(context, tournamentId, includeMetadata: true);
        }
        return 'Turnier-Snapshot wiederhergestellt (${snapshot.teams.length} Teams)';
      },
    );
  }

  /// Upload teams from a JSON file.
  static Future<void> uploadTeamsFromJson(BuildContext context) async {
    final tournamentId = _tournamentId(context);
    final style = _tournamentStyle(context);

    await _withFilePickerAndDialog(
      context: context,
      extensions: ['json'],
      dialogTitle: 'Teams importieren (JSON)',
      loadingMessage: 'Teams werden importiert...',
      errorTag: 'JSON team upload',
      action: (bytes) async {
        final jsonData = json.decode(utf8.decode(bytes));

        if (jsonData is Map<String, dynamic> && isSnapshotJson(jsonData)) {
          throw const FormatException(
              'Diese Datei ist ein Turnier-Snapshot. Bitte "Snapshot importieren" verwenden.');
        }

        final service = FirestoreService();
        String message;

        if (style == TournamentStyle.groupsAndKnockouts) {
          final (allTeams, groups) = parseTeamsFromJson(jsonData);
          await service.importTeamsAndGroups(allTeams, groups,
              tournamentId: tournamentId);
          message =
              '${allTeams.length} Teams und ${groups.groups.length} Gruppen importiert!';
        } else {
          final allTeams = parseTeamsFlatFromJson(jsonData);
          await service.importTeamsOnly(allTeams, tournamentId: tournamentId);
          message = '${allTeams.length} Teams importiert!';
        }

        if (context.mounted) await _refreshState(context, tournamentId);
        return message;
      },
    );
  }
}
