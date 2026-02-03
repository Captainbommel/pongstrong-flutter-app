import 'package:flutter/foundation.dart';

/// Log levels for the application
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// ANSI color codes for terminal output
class _Colors {
  static const String reset = '\x1B[0m';
  static const String debug = '\x1B[36m'; // Cyan
  static const String info = '\x1B[32m'; // Green
  static const String warning = '\x1B[33m'; // Yellow
  static const String error = '\x1B[31m'; // Red
}

/// Application logger with configurable log levels
class Logger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Set the minimum log level
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Get current minimum log level
  static LogLevel get minLevel => _minLevel;

  /// Log a debug message (development only)
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Log an info message
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning message
  static void warning(String message, {String? tag, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, error: error);
  }

  /// Log an error message
  static void error(
    String message, {
    String? tag,
    Object? error,
  }) {
    _log(LogLevel.error, message, tag: tag, error: error);
  }

  /// Internal logging method
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
  }) {
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';

    final colorCode = _getColorForLevel(level);
    final logMessage =
        '$colorCode$timestamp | $levelStr | $tagStr$message${_Colors.reset}';

    debugPrint(logMessage);

    if (error != null) {
      debugPrint('$colorCode  Error: $error${_Colors.reset}');
    }
  }

  static String _getColorForLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => _Colors.debug,
      LogLevel.info => _Colors.info,
      LogLevel.warning => _Colors.warning,
      LogLevel.error => _Colors.error,
    };
  }
}
