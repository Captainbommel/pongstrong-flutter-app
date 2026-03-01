import 'package:flutter/material.dart';
import 'package:pongstrong/state/tournament_data_state.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/presentation/presentation_event.dart';
import 'package:pongstrong/views/presentation/presentation_state.dart';
import 'package:pongstrong/views/presentation/slides/event_slide.dart';
import 'package:pongstrong/views/presentation/slides/group_standings_slide.dart';
import 'package:pongstrong/views/presentation/slides/knockout_bracket_slide.dart';
import 'package:pongstrong/views/presentation/slides/playing_field_slide.dart';
import 'package:pongstrong/views/presentation/slides/upcoming_matches_slide.dart';

/// Full-screen presentation / beamer overlay.
///
/// Cycles through tournament slides with crossfade transitions and shows
/// event flashes when notable things happen (match finished, bracket winner,
/// group decided).
///
/// Press Escape or click the close button to exit.
class PresentationScreen extends StatefulWidget {
  final TournamentDataState tournamentData;

  const PresentationScreen({super.key, required this.tournamentData});

  /// Opens the presentation screen as a full-screen overlay route.
  static void open(BuildContext context, TournamentDataState data) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PresentationScreen(tournamentData: data),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen>
    with SingleTickerProviderStateMixin {
  late PresentationState _state;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  // Track the previous slide key to trigger crossfade
  String _currentSlideKey = '';
  Widget? _currentSlideWidget;
  Widget? _previousSlideWidget;

  @override
  void initState() {
    super.initState();
    _state = PresentationState(widget.tournamentData);
    _state.addListener(_onStateChanged);

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOut,
    );

    _transitionController.value = 1.0;

    _state.start();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final newKey = _buildSlideKey();
    if (newKey != _currentSlideKey) {
      setState(() {
        _previousSlideWidget = _currentSlideWidget;
        _currentSlideKey = newKey;
        _currentSlideWidget = _buildSlide();
      });
      _transitionController.forward(from: 0.0);
    } else {
      // Data changed but same slide → rebuild content in place
      setState(() {
        _currentSlideWidget = _buildSlide();
      });
    }
  }

  String _buildSlideKey() {
    if (_state.activeEvent != null) {
      return 'event_${_state.activeEvent.hashCode}';
    }
    return '${_state.currentSlide.name}_${_state.subIndex}';
  }

  Widget _buildSlide() {
    final data = _state.tournamentData;

    // Event flash takes priority
    if (_state.activeEvent != null) {
      return EventSlide(
        key: ValueKey('event_${_state.activeEvent.hashCode}'),
        event: _state.activeEvent!,
      );
    }

    switch (_state.currentSlide) {
      case PresentationSlide.playingField:
        return PlayingFieldSlide(
          key: const ValueKey('playing'),
          data: data,
        );
      case PresentationSlide.upcomingMatches:
        return UpcomingMatchesSlide(
          key: const ValueKey('upcoming'),
          data: data,
        );
      case PresentationSlide.groupStandings:
        return GroupStandingsSlide(
          key: ValueKey('group_${_state.subIndex}'),
          data: data,
          groupIndex: _state.subIndex,
        );
      case PresentationSlide.knockoutBracket:
        final bracketKey = _state.currentBracketKey;
        if (bracketKey == null) {
          return const Center(child: Text('Keine Bracket-Daten'));
        }
        return KnockoutBracketSlide(
          key: ValueKey('ko_${bracketKey.name}'),
          data: data,
          bracketKey: bracketKey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have an initial widget
    _currentSlideWidget ??= _buildSlide();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface,
                  AppColors.grey100,
                ],
              ),
            ),
          ),

          // Slide content with crossfade
          if (_previousSlideWidget != null)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: (1.0 - _fadeAnimation.value).clamp(0.0, 1.0),
                  child: child,
                );
              },
              child: _previousSlideWidget,
            ),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              );
            },
            child: _currentSlideWidget,
          ),

          // Progress indicator at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),

          // Slide indicator dots / close button
          Positioned(
            top: 16,
            right: 16,
            child: _buildControls(),
          ),

          // Pongstrong branding (subtle, bottom-left)
          Positioned(
            bottom: 16,
            left: 24,
            child: Text(
              'Pongstrong',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDisabled.withAlpha(100),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_currentSlideKey),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: _state.currentDuration,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.grey200,
          valueColor: AlwaysStoppedAnimation<Color>(
            _state.activeEvent != null
                ? _eventProgressColor()
                : GroupPhaseColors.steelblue.withAlpha(120),
          ),
          minHeight: 3,
        );
      },
    );
  }

  Color _eventProgressColor() {
    if (_state.activeEvent == null) return GroupPhaseColors.steelblue;
    // Use the event's custom color if provided (e.g. table color)
    if (_state.activeEvent!.color != null) {
      return _state.activeEvent!.color!;
    }
    switch (_state.activeEvent!.type) {
      case PresentationEventType.bracketWinner:
      case PresentationEventType.tournamentFinished:
        return const Color(0xFFFFD700);
      case PresentationEventType.matchFinished:
        return GroupPhaseColors.steelblue;
      case PresentationEventType.groupDecided:
        return AppColors.success;
      case PresentationEventType.knockoutPhaseStarted:
        return GroupPhaseColors.cupred;
    }
  }

  Widget _buildControls() {
    return Material(
      color: AppColors.surface.withAlpha(200),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _state.stop();
          Navigator.of(context).pop();
        },
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.close,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
