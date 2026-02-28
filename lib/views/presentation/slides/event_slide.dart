import 'package:flutter/material.dart';
import 'package:pongstrong/utils/colors.dart';
import 'package:pongstrong/views/presentation/presentation_event.dart';

/// Full-screen event flash slide with entrance animation.
///
/// Shows when a notable tournament event occurs (match finished,
/// bracket winner decided, group placements finalised).
class EventSlide extends StatefulWidget {
  final PresentationEvent event;

  const EventSlide({super.key, required this.event});

  @override
  State<EventSlide> createState() => _EventSlideState();
}

class _EventSlideState extends State<EventSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _eventColor() {
    // Use custom color from event if provided (e.g. table color)
    if (widget.event.color != null) {
      return widget.event.color!;
    }
    switch (widget.event.type) {
      case PresentationEventType.matchFinished:
        return GroupPhaseColors.steelblue;
      case PresentationEventType.bracketWinner:
        return const Color(0xFFFFD700); // Gold
      case PresentationEventType.groupDecided:
        return AppColors.success;
      case PresentationEventType.knockoutPhaseStarted:
        return GroupPhaseColors.cupred;
      case PresentationEventType.tournamentFinished:
        return const Color(0xFFFFD700);
    }
  }

  IconData _eventIcon() {
    switch (widget.event.type) {
      case PresentationEventType.matchFinished:
        return Icons.sports_bar;
      case PresentationEventType.bracketWinner:
        return Icons.emoji_events;
      case PresentationEventType.groupDecided:
        return Icons.check_circle_outline;
      case PresentationEventType.knockoutPhaseStarted:
        return Icons.bolt;
      case PresentationEventType.tournamentFinished:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _eventColor();
    final icon = _eventIcon();
    final isBig = widget.event.type == PresentationEventType.bracketWinner ||
        widget.event.type == PresentationEventType.tournamentFinished;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: child,
          ),
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: isBig ? 120 : 96,
                height: isBig ? 120 : 96,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(80), width: 3),
                ),
                child: Icon(icon, size: isBig ? 68 : 52, color: color),
              ),
              const SizedBox(height: 28),

              // Context badge
              if (widget.event.context != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.event.context!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Headline
              Text(
                widget.event.headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isBig ? 52 : 44,
                  fontWeight: FontWeight.bold,
                  color: color,
                  shadows: [
                    Shadow(
                      color: color.withAlpha(40),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Body
              Text(
                widget.event.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isBig ? 34 : 30,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
