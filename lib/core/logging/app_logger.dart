import 'package:flutter/foundation.dart';

/// Severity levels for application logs.
enum LogLevel {
  debug,
  info,
  warn,
  error;

  String get shortName {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// A structured, immutable log entry stored in the memory ring buffer.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Formats the log entry as a standard diagnostic string.
  String format({bool includeTimestamp = true}) {
    final buffer = StringBuffer();
    if (includeTimestamp) {
      final iso = timestamp.toIso8601String();
      buffer.write('[$iso] ');
    }
    buffer.write('[${level.shortName}] [$tag] $message');
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// High-performance, zero-jank in-memory ring buffer logger for Flax.
///
/// Principles:
/// 1. Pre-allocated circular ring buffer in RAM (~150-200 KB footprint for 500 entries).
/// 2. Instantaneous O(1) array insertion with zero main-thread disk I/O.
/// 3. Zero-cost gating in Release mode: debug logs are dropped with 1 integer check.
/// 4. Lazy evaluation support via `() => String` closures to avoid string construction overhead.
class AppLogger {
  AppLogger._();

  static const int defaultCapacity = 500;
  static int _capacity = defaultCapacity;
  static List<LogEntry?> _ringBuffer = List<LogEntry?>.filled(
    defaultCapacity,
    null,
  );
  static int _head = 0;
  static int _count = 0;

  /// Whether to write logs to console/stdout. Enabled by default in debug mode.
  static bool outputToStdout = kDebugMode;

  /// Minimum severity level to capture. Release mode defaults to [LogLevel.info].
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Resets the ring buffer and configuration. Useful for unit testing.
  @visibleForTesting
  static void reset({
    int capacity = defaultCapacity,
    bool? debugOutput,
    LogLevel? level,
  }) {
    _capacity = capacity;
    _ringBuffer = List<LogEntry?>.filled(capacity, null);
    _head = 0;
    _count = 0;
    if (debugOutput != null) outputToStdout = debugOutput;
    if (level != null) minLevel = level;
  }

  /// Logs a structured message with optional error and stack trace.
  ///
  /// [message] can be a [String] or a lazy callback `String Function()` that is only
  /// evaluated if [level] is active.
  static void log(
    LogLevel level,
    String tag,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final String evaluatedMessage;
    if (message is Function) {
      evaluatedMessage = message().toString();
    } else {
      evaluatedMessage = message.toString();
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: evaluatedMessage,
      error: error,
      stackTrace: stackTrace,
    );

    // O(1) circular ring buffer insertion
    _ringBuffer[_head] = entry;
    _head = (_head + 1) % _capacity;
    if (_count < _capacity) {
      _count++;
    }

    if (outputToStdout) {
      // Direct stdout output for terminal / CLI runs
      // ignore: avoid_print
      print(entry.format());
    }
  }

  /// Debug level log. Dropped in Release mode with 0 allocation.
  static void d(
    String tag,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.debug, tag, message, error: error, stackTrace: stackTrace);

  /// Info level log for discrete lifecycle and state transitions.
  static void i(
    String tag,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.info, tag, message, error: error, stackTrace: stackTrace);

  /// Warning level log for non-fatal degradations or unexpected server responses.
  static void w(
    String tag,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.warn, tag, message, error: error, stackTrace: stackTrace);

  /// Error level log for caught exceptions and failures.
  static void e(
    String tag,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
  }) => log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  /// Returns all stored log entries in chronological order (oldest first).
  static List<LogEntry> getEntries() {
    if (_count == 0) return const [];
    final result = <LogEntry>[];
    final start = _count < _capacity ? 0 : _head;
    for (var i = 0; i < _count; i++) {
      final entry = _ringBuffer[(start + i) % _capacity];
      if (entry != null) {
        result.add(entry);
      }
    }
    return result;
  }

  /// Exports all buffered logs as a single formatted multiline string.
  static String exportLogs({bool reverse = false}) {
    final entries = getEntries();
    final list = reverse ? entries.reversed : entries;
    return list.map((e) => e.format()).join('\n');
  }

  /// Current number of buffered log entries.
  static int get count => _count;

  /// Capacity limit of the ring buffer.
  static int get capacity => _capacity;
}
