import 'dart:async';

import 'package:flutter/material.dart' hide TableRow;
import 'package:pongstrong/models/models.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/presentation/presentation_event.dart';

/// Identifies the different "slides" the presentation view cycles through.
enum PresentationSlide {
  /// Currently playing matches.
  playingField,

  /// Next upcoming matches (those waiting to be assigned to a table).
  upcomingMatches,

  /// Group standings overview (one per group, cycled automatically).
  groupStandings,

  /// Knockout bracket overview.
  knockoutBracket,
}

/// Manages the state for the beamer/presentation mode.
///
/// Responsibilities:
/// - Cycle through slides on a timer.
/// - Detect tournament events by diffing old vs new data.
/// - Queue events and display them between regular slides.
///
/// This is intentionally a standalone [ChangeNotifier] so the presentation
/// window/overlay can be opened by any user on the desktop app, not only the
/// creator. It listens to [TournamentDataState] for live updates.
class PresentationState extends ChangeNotifier {
  PresentationState(this._tournamentData) {
    _takeSnapshot();
    _tournamentData.addListener(_onTournamentDataChanged);
  }

  final TournamentDataState _tournamentData;

  // ── Slide cycling ─────────────────────────────────────────────

  // ── Duration helpers ──────────────────────────────────────────

  /// Duration for the content currently being displayed.
  Duration get currentDuration {
    if (_activeEvent != null) {
      return _eventDuration(_activeEvent!.type);
    }
    return _slideDuration(currentSlide);
  }

  static Duration _slideDuration(PresentationSlide slide) {
    switch (slide) {
      case PresentationSlide.playingField:
        return const Duration(seconds: 8);
      case PresentationSlide.upcomingMatches:
        return const Duration(seconds: 8);
      case PresentationSlide.groupStandings:
        return const Duration(seconds: 10);
      case PresentationSlide.knockoutBracket:
        return const Duration(seconds: 10);
    }
  }

  static Duration _eventDuration(PresentationEventType type) {
    switch (type) {
      case PresentationEventType.matchFinished:
        return const Duration(seconds: 8);
      case PresentationEventType.bracketWinner:
        return const Duration(seconds: 14);
      case PresentationEventType.groupDecided:
        return const Duration(seconds: 10);
      case PresentationEventType.knockoutPhaseStarted:
        return const Duration(seconds: 10);
      case PresentationEventType.tournamentFinished:
        return const Duration(seconds: 16);
    }
  }

  Timer? _cycleTimer;
  bool _isRunning = false;

  /// Index within the computed [_slideOrder] list.
  int _slideIndex = 0;

  /// Sub-index used when a slide type has multiple pages (e.g. groups).
  int _subIndex = 0;

  /// The current slide type being displayed.
  PresentationSlide get currentSlide => _slideOrder.isEmpty
      ? PresentationSlide.playingField
      : _slideOrder[_slideIndex % _slideOrder.length];

  /// Sub-index for multi-page slides (e.g., which group is shown).
  int get subIndex => _subIndex;

  /// Whether the presentation is currently cycling.
  bool get isRunning => _isRunning;

  /// The event currently being shown (null when showing a regular slide).
  PresentationEvent? get activeEvent => _activeEvent;
  PresentationEvent? _activeEvent;

  /// Access the underlying tournament data for building slide content.
  TournamentDataState get tournamentData => _tournamentData;

  // ── Event queue ───────────────────────────────────────────────

  final List<PresentationEvent> _eventQueue = [];

  // ── Snapshot for diff-based event detection ───────────────────

  /// Previous match-done states for group phase.
  Map<String, bool> _prevGroupMatchDone = {};

  /// Previous match-done states for knockout phase.
  Map<String, bool> _prevKnockoutMatchDone = {};

  /// Previous knockout mode flag.
  bool _prevIsKnockoutMode = false;

  // ── Computed slide order ──────────────────────────────────────

  List<PresentationSlide> get _slideOrder {
    final slides = <PresentationSlide>[];
    final data = _tournamentData;

    // Always show playing field if there are running matches
    if (data.matchQueue.playing.isNotEmpty) {
      slides.add(PresentationSlide.playingField);
    }

    // Show upcoming matches if there are any waiting
    if (data.matchQueue.nextMatches().isNotEmpty) {
      slides.add(PresentationSlide.upcomingMatches);
    }

    // Show group standings only if NOT in knockout mode and there is table data
    if (!data.isKnockoutMode &&
        data.tournamentStyle != 'knockoutsOnly' &&
        data.hasData &&
        data.tabellen.tables.isNotEmpty) {
      slides.add(PresentationSlide.groupStandings);
    }

    // Show knockout bracket if in knockout mode
    if (data.isKnockoutMode && _activeBracketKeys().isNotEmpty) {
      slides.add(PresentationSlide.knockoutBracket);
    }

    // Fallback: always have at least playing field
    if (slides.isEmpty) {
      slides.add(PresentationSlide.playingField);
    }

    return slides;
  }

  /// Number of sub-pages for the current slide (e.g. number of groups).
  int get currentSubPageCount {
    if (currentSlide == PresentationSlide.groupStandings) {
      // Skip groups with no table data
      final count = _tournamentData.tabellen.tables
          .where((rows) => rows.isNotEmpty)
          .length;
      return count > 0 ? count : 1;
    }
    if (currentSlide == PresentationSlide.knockoutBracket) {
      // Show each non-empty bracket as a sub-page
      return _activeBracketKeys().length;
    }
    return 1;
  }

  /// Returns bracket keys that actually have matches/teams.
  List<BracketKey> _activeBracketKeys() {
    final ko = _tournamentData.knockouts;
    final keys = <BracketKey>[];
    if (ko.champions.rounds.isNotEmpty) keys.add(BracketKey.gold);
    if (ko.europa.rounds.isNotEmpty) keys.add(BracketKey.silver);
    if (ko.conference.rounds.isNotEmpty) keys.add(BracketKey.bronze);
    // Only show extra bracket if it has at least one match with real team IDs
    if (ko.superCup.matches.isNotEmpty &&
        ko.superCup.matches
            .any((m) => m.teamId1.isNotEmpty || m.teamId2.isNotEmpty)) {
      keys.add(BracketKey.extra);
    }
    return keys;
  }

  /// The bracket key currently being shown (when on knockout slide).
  BracketKey? get currentBracketKey {
    if (currentSlide != PresentationSlide.knockoutBracket) return null;
    final keys = _activeBracketKeys();
    if (keys.isEmpty) return null;
    return keys[_subIndex % keys.length];
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _slideIndex = 0;
    _subIndex = 0;
    _takeSnapshot();
    _scheduleNext();
    notifyListeners();
  }

  void stop() {
    _isRunning = false;
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _activeEvent = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _tournamentData.removeListener(_onTournamentDataChanged);
    super.dispose();
  }

  // ── Cycling logic ─────────────────────────────────────────────

  /// Saved sub-index before showing an event, so we can resume cycling
  /// from where we left off (e.g. group C of 4 groups).
  int? _savedSubIndex;

  void _scheduleNext() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer(currentDuration, _advance);
  }

  void _advance() {
    if (!_isRunning) return;

    // If there was an active event, clear it and resume where we left off
    if (_activeEvent != null) {
      _activeEvent = null;

      // If there are more queued events, show them back-to-back
      if (_eventQueue.isNotEmpty) {
        _activeEvent = _eventQueue.removeAt(0);
        notifyListeners();
        _scheduleNext();
        return;
      }

      // Restore saved sub-index so group/bracket cycling continues
      if (_savedSubIndex != null) {
        _subIndex = _savedSubIndex!;
        _savedSubIndex = null;
      }
      notifyListeners();
      _scheduleNext();
      return;
    }

    // Check event queue – events always have priority, even mid-sub-page
    if (_eventQueue.isNotEmpty) {
      // Save current sub-index so we can resume after the event(s)
      _savedSubIndex = _subIndex;
      _activeEvent = _eventQueue.removeAt(0);
      notifyListeners();
      _scheduleNext();
      return;
    }

    // Normal cycling: advance sub-index first, then slide index
    final subCount = currentSubPageCount;
    if (subCount > 1 && _subIndex < subCount - 1) {
      _subIndex++;
    } else {
      _subIndex = 0;
      _slideIndex = (_slideIndex + 1) % _slideOrder.length;
    }

    notifyListeners();
    _scheduleNext();
  }

  // ── Event detection ───────────────────────────────────────────

  void _takeSnapshot() {
    _prevGroupMatchDone = _buildGroupMatchSnapshot();
    _prevKnockoutMatchDone = _buildKnockoutMatchSnapshot();
    _prevIsKnockoutMode = _tournamentData.isKnockoutMode;
  }

  Map<String, bool> _buildGroupMatchSnapshot() {
    final map = <String, bool>{};
    for (final group in _tournamentData.gruppenphase.groups) {
      for (final match in group) {
        map[match.id] = match.done;
      }
    }
    return map;
  }

  Map<String, bool> _buildKnockoutMatchSnapshot() {
    final map = <String, bool>{};
    void addBracket(KnockoutBracket bracket) {
      for (final round in bracket.rounds) {
        for (final match in round) {
          map[match.id] = match.done;
        }
      }
    }

    final ko = _tournamentData.knockouts;
    addBracket(ko.champions);
    addBracket(ko.europa);
    addBracket(ko.conference);
    for (final match in ko.superCup.matches) {
      map[match.id] = match.done;
    }
    return map;
  }

  void _onTournamentDataChanged() {
    if (!_isRunning) {
      _takeSnapshot();
      notifyListeners();
      return;
    }

    _detectEvents();
    _takeSnapshot();
    notifyListeners();
  }

  void _detectEvents() {
    final data = _tournamentData;

    // ── Knockout phase started ──
    if (data.isKnockoutMode && !_prevIsKnockoutMode) {
      _eventQueue.add(const PresentationEvent(
        type: PresentationEventType.knockoutPhaseStarted,
        headline: 'K.O.-Phase beginnt!',
        body:
            'Die Gruppenphase ist beendet.\nDie Knockout-Runden starten jetzt!',
      ));
    }

    // ── Group matches finished ──
    _detectGroupMatchEvents(data);

    // ── Knockout matches finished ──
    _detectKnockoutMatchEvents(data);

    // ── Group decided ──
    _detectGroupDecided(data);
  }

  /// Returns the trophy accent color for a bracket winner event.
  static Color _trophyColor(BracketKey key) {
    switch (key) {
      case BracketKey.gold:
        return const Color(0xFFFFD700); // Gold
      case BracketKey.silver:
        return const Color(0xFFC0C0C0); // Silver
      case BracketKey.bronze:
        return const Color(0xFFCD7F32); // Bronze
      case BracketKey.extra:
        return TreeColors.hotpink;
    }
  }

  /// Build descriptive body text for a finished match.
  /// "X schlägt Y mit Z : Z" or "X und Y trennen sich Z : Z".
  String _matchResultBody(String team1, String team2, Match match) {
    final winnerId = match.getWinnerId();
    if (winnerId == null) {
      return '$team1  ${match.score1} : ${match.score2}  $team2';
    }
    final bool team1Won = winnerId == match.teamId1;
    final winner = team1Won ? team1 : team2;
    final loser = team1Won ? team2 : team1;
    final wScore = team1Won ? match.score1 : match.score2;
    final lScore = team1Won ? match.score2 : match.score1;
    return '$winner schlägt $loser\nmit $wScore : $lScore';
  }

  void _detectGroupMatchEvents(TournamentDataState data) {
    for (final group in data.gruppenphase.groups) {
      for (final match in group) {
        final wasDone = _prevGroupMatchDone[match.id] ?? false;
        if (match.done && !wasDone) {
          final team1 = data.getTeam(match.teamId1)?.name ?? match.teamId1;
          final team2 = data.getTeam(match.teamId2)?.name ?? match.teamId2;
          _eventQueue.add(PresentationEvent(
            type: PresentationEventType.matchFinished,
            headline: 'Spiel beendet!',
            body: _matchResultBody(team1, team2, match),
            context: 'Gruppenphase',
            color: match.tableNumber > 0
                ? TableColors.forIndex(match.tableNumber - 1)
                : null,
          ));
        }
      }
    }
  }

  void _detectKnockoutMatchEvents(TournamentDataState data) {
    final ko = data.knockouts;

    void checkBracket(
        KnockoutBracket bracket, String bracketName, BracketKey key) {
      for (int r = 0; r < bracket.rounds.length; r++) {
        for (final match in bracket.rounds[r]) {
          final wasDone = _prevKnockoutMatchDone[match.id] ?? false;
          if (match.done && !wasDone) {
            final team1 = data.getTeam(match.teamId1)?.name ?? match.teamId1;
            final team2 = data.getTeam(match.teamId2)?.name ?? match.teamId2;

            // Check if this is the final match of the bracket
            final isFinal =
                r == bracket.rounds.length - 1 && bracket.rounds[r].length == 1;
            if (isFinal) {
              final winnerId = match.getWinnerId();
              final winnerName = winnerId != null
                  ? (data.getTeam(winnerId)?.name ?? winnerId)
                  : '?';
              _eventQueue.add(PresentationEvent(
                type: PresentationEventType.bracketWinner,
                headline: '$bracketName Sieger!',
                body: '🏆 $winnerName 🏆',
                context: bracketName,
                color: _trophyColor(key),
              ));
            } else {
              _eventQueue.add(PresentationEvent(
                type: PresentationEventType.matchFinished,
                headline: 'Spiel beendet!',
                body: _matchResultBody(team1, team2, match),
                context: bracketName,
                color: match.tableNumber > 0
                    ? TableColors.forIndex(match.tableNumber - 1)
                    : null,
              ));
            }
          }
        }
      }
    }

    checkBracket(
        ko.champions, ko.getBracketName(BracketKey.gold), BracketKey.gold);
    checkBracket(
        ko.europa, ko.getBracketName(BracketKey.silver), BracketKey.silver);
    checkBracket(
        ko.conference, ko.getBracketName(BracketKey.bronze), BracketKey.bronze);

    // Super cup
    for (final match in ko.superCup.matches) {
      final wasDone = _prevKnockoutMatchDone[match.id] ?? false;
      if (match.done && !wasDone) {
        final team1 = data.getTeam(match.teamId1)?.name ?? match.teamId1;
        final team2 = data.getTeam(match.teamId2)?.name ?? match.teamId2;
        _eventQueue.add(PresentationEvent(
          type: PresentationEventType.matchFinished,
          headline: 'Spiel beendet!',
          body: _matchResultBody(team1, team2, match),
          context: ko.getBracketName(BracketKey.extra),
          color: match.tableNumber > 0
              ? TableColors.forIndex(match.tableNumber - 1)
              : null,
        ));
      }
    }
  }

  void _detectGroupDecided(TournamentDataState data) {
    if (data.tournamentStyle == 'knockoutsOnly') return;

    for (int g = 0; g < data.gruppenphase.groups.length; g++) {
      final group = data.gruppenphase.groups[g];
      final allDone = group.isNotEmpty && group.every((m) => m.done);
      final wasAllDone = group.isNotEmpty &&
          group.every((m) => _prevGroupMatchDone[m.id] == true);

      if (allDone && !wasAllDone) {
        final groupName = String.fromCharCode(65 + g);
        // Build full placement list so every team is shown
        final standings =
            data.tabellen.tables.length > g ? data.tabellen.tables[g] : null;
        String placementInfo = 'Alle Spiele abgeschlossen.';
        if (standings != null && standings.isNotEmpty) {
          final lines = <String>[];
          for (int p = 0; p < standings.length; p++) {
            final name =
                data.getTeam(standings[p].teamId)?.name ?? standings[p].teamId;
            lines.add('${p + 1}. $name');
          }
          placementInfo = lines.join('\n');
        }

        _eventQueue.add(PresentationEvent(
          type: PresentationEventType.groupDecided,
          headline: 'Gruppe $groupName entschieden!',
          body: placementInfo,
          context: 'Gruppe $groupName',
        ));
      }
    }
  }
}
