//* matches should use an identifier to be able to update the match correctly
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pongstrong/models/match.dart';
import 'package:pongstrong/state/auth_state.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/app_logger.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:provider/provider.dart';

/// Status phases for dialog operations.
enum _DialogStatus { idle, loading, success, error }

/// Safely pops the current bottom-sheet route.
///
/// On Flutter web, popping the last (root) route calls
/// `SystemNavigator.pop()` which navigates the browser back to
/// `index.html`.  This guard ensures we only pop when the modal
/// route is still the current one – preventing the double-pop
/// that occurs when the user dismisses the sheet while the
/// success timer is still running.
void _safePop(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && route.isCurrent) {
    Navigator.pop(context);
  }
}

// ─── Shared helpers for match bottom-sheet dialogs ───

/// Standard bottom-sheet border decoration (skyblue frame).
BoxDecoration matchDialogDecoration({required bool isLargeScreen}) {
  return BoxDecoration(
    color: AppColors.surface,
    border: isLargeScreen
        ? const Border(
            top: BorderSide(color: FieldColors.skyblue, width: 14.0),
            left: BorderSide(color: FieldColors.skyblue, width: 14.0),
            right: BorderSide(color: FieldColors.skyblue, width: 14.0),
          )
        : const Border(
            top: BorderSide(color: FieldColors.skyblue, width: 14.0),
          ),
    borderRadius: isLargeScreen
        ? const BorderRadius.only(
            topLeft: Radius.circular(12.0),
            topRight: Radius.circular(12.0),
          )
        : BorderRadius.zero,
  );
}

/// Action area widget shared by finish-match and start-match dialogs.
///
/// Shows a spinner during [_DialogStatus.loading], a check-mark on
/// [_DialogStatus.success], or [buttonLabel] on idle / error.
Widget buildDialogActionArea({
  required _DialogStatus status,
  required VoidCallback onPressed,
  required String buttonLabel,
}) {
  switch (status) {
    case _DialogStatus.loading:
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: FieldColors.skyblue,
        ),
      );
    case _DialogStatus.success:
      return const Icon(
        Icons.check_circle,
        color: FieldColors.skyblue,
        size: 36,
      );
    case _DialogStatus.idle:
    case _DialogStatus.error:
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: FieldColors.skyblue, width: 3),
            borderRadius: BorderRadius.circular(10),
          ),
          overlayColor: FieldColors.skyblue.withAlpha(128),
        ),
        child: Text(
          buttonLabel,
          style: const TextStyle(color: AppColors.shadow),
        ),
      );
  }
}

/// Shows a bottom sheet dialog to finish a match by entering scores.
///
/// Controllers are managed internally and disposed when the dialog closes.
Future<dynamic> finishMatchDialog(
  BuildContext context, {
  required String team1,
  required String team2,
  required Match match,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return _FinishMatchContent(
        team1: team1,
        team2: team2,
        match: match,
      );
    },
  );
}

/// Stateful content for the finish-match bottom sheet.
///
/// Owns the [TextEditingController]s so they are properly disposed.
class _FinishMatchContent extends StatefulWidget {
  final String team1;
  final String team2;
  final Match match;

  const _FinishMatchContent({
    required this.team1,
    required this.team2,
    required this.match,
  });

  @override
  State<_FinishMatchContent> createState() => _FinishMatchContentState();
}

class _FinishMatchContentState extends State<_FinishMatchContent> {
  final _cups1 = TextEditingController();
  final _cups2 = TextEditingController();
  _DialogStatus _status = _DialogStatus.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _cups1.dispose();
    _cups2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (!authState.isParticipant && !authState.isAdmin) {
      setState(() {
        _status = _DialogStatus.error;
        _errorMessage = 'Keine Berechtigung. Bitte dem Turnier beitreten.';
      });
      return;
    }

    setState(() {
      _status = _DialogStatus.loading;
      _errorMessage = null;
    });

    final score1 = int.tryParse(_cups1.text) ?? 0;
    final score2 = int.tryParse(_cups2.text) ?? 0;

    final tournamentData =
        Provider.of<TournamentDataState>(context, listen: false);
    final success = await tournamentData.finishMatch(
      widget.match.id,
      score1: score1,
      score2: score2,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _status = _DialogStatus.success);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _safePop(context);
    } else {
      setState(() {
        _status = _DialogStatus.error;
        _errorMessage = 'Ungültiges Ergebnis oder Fehler beim Speichern.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final isInteractive =
        _status == _DialogStatus.idle || _status == _DialogStatus.error;

    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: matchDialogDecoration(isLargeScreen: isLargeScreen),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          const Text(
            'Ergebnis eintragen',
            style: TextStyle(
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        widget.team1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      cupInput(_cups1, enabled: isInteractive),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        widget.team2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                      cupInput(_cups2, enabled: isInteractive),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          buildDialogActionArea(
            status: _status,
            onPressed: _submit,
            buttonLabel: 'Spiel Abschließen',
          ),
        ],
      ),
    );
  }
}

class CupsTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // allow empty input
    if (newValue.text.isEmpty) return newValue;

    // allow digits and minus sign
    if (!RegExp(r'^-?[0-9]*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    // only allow integers between -2 and 100
    final int? value = int.tryParse(newValue.text);
    if (value == null || value < -2 || value > 100) {
      return oldValue;
    }

    return newValue;
  }
}

SizedBox cupInput(TextEditingController cups1, {bool enabled = true}) {
  return SizedBox(
    width: 100,
    child: TextField(
      controller: cups1,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [CupsTextInputFormatter()],
      textAlign: TextAlign.center,
      cursorColor: FieldColors.skyblue,
      decoration: InputDecoration(
        focusColor: FieldColors.skyblue,
        border: OutlineInputBorder(
          borderSide: const BorderSide(
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: FieldColors.skyblue,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    ),
  );
}

/// Shows a bottom sheet dialog to start a match (move from queue to playing).
Future<dynamic> startMatchDialog(
  BuildContext context, {
  required String team1,
  required String team2,
  required List<String> members1,
  required List<String> members2,
  required Match match,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return _StartMatchContent(
        team1: team1,
        team2: team2,
        members1: members1,
        members2: members2,
        match: match,
      );
    },
  );
}

/// Stateful content for the start-match bottom sheet.
class _StartMatchContent extends StatefulWidget {
  final String team1;
  final String team2;
  final List<String> members1;
  final List<String> members2;
  final Match match;

  const _StartMatchContent({
    required this.team1,
    required this.team2,
    required this.members1,
    required this.members2,
    required this.match,
  });

  @override
  State<_StartMatchContent> createState() => _StartMatchContentState();
}

class _StartMatchContentState extends State<_StartMatchContent> {
  _DialogStatus _status = _DialogStatus.idle;
  String? _errorMessage;

  Future<void> _handleStartMatch() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (!authState.isParticipant && !authState.isAdmin) {
      setState(() {
        _status = _DialogStatus.error;
        _errorMessage = 'Keine Berechtigung. Bitte dem Turnier beitreten.';
      });
      return;
    }

    setState(() {
      _status = _DialogStatus.loading;
      _errorMessage = null;
    });

    final tournamentData =
        Provider.of<TournamentDataState>(context, listen: false);
    final matchId = widget.match.id;
    Logger.debug(
        'Starting match with ID $matchId at table ${widget.match.tableNumber}',
        tag: 'MatchDialog');

    final success = await tournamentData.startMatch(matchId);

    if (!mounted) return;

    if (success) {
      setState(() => _status = _DialogStatus.success);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _safePop(context);
    } else {
      setState(() {
        _status = _DialogStatus.error;
        _errorMessage = 'Tisch nicht verfügbar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Container(
      height: MediaQuery.of(context).size.height / 3,
      decoration: matchDialogDecoration(isLargeScreen: isLargeScreen),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          const Text(
            'Match Info:',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildTeamColumn(widget.team1, widget.members1),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
              Expanded(
                child: _buildTeamColumn(widget.team2, widget.members2),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          buildDialogActionArea(
            status: _status,
            onPressed: _handleStartMatch,
            buttonLabel: 'Spiel starten',
          ),
        ],
      ),
    );
  }

  /// Builds a responsive column for one team's name and members.
  /// Filters out empty member names and adjusts text size based on count.
  Widget _buildTeamColumn(String teamName, List<String> members) {
    final nonEmptyMembers = members.where((m) => m.isNotEmpty).toList();
    final hasManyMembers = nonEmptyMembers.length >= 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          teamName,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (nonEmptyMembers.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            nonEmptyMembers.join(', '),
            style: TextStyle(
              fontSize: hasManyMembers ? 12.0 : 14.0,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}
