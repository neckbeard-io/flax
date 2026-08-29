import 'package:flutter_test/flutter_test.dart';
import 'package:flax/core/logging/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.reset(capacity: 5, debugOutput: false, level: LogLevel.debug);
  });

  group('AppLogger Ring Buffer', () {
    test('stores entries within capacity', () {
      AppLogger.i('Test', 'Message 1');
      AppLogger.w('Test', 'Message 2');

      final entries = AppLogger.getEntries();
      expect(entries.length, 2);
      expect(entries[0].message, 'Message 1');
      expect(entries[0].level, LogLevel.info);
      expect(entries[1].message, 'Message 2');
      expect(entries[1].level, LogLevel.warn);
    });

    test('overwrites oldest entries when exceeding capacity', () {
      // Buffer capacity is set to 5 in setUp
      for (var i = 1; i <= 8; i++) {
        AppLogger.i('Tag', 'Event $i');
      }

      expect(AppLogger.count, 5);
      final entries = AppLogger.getEntries();
      expect(entries.length, 5);
      expect(entries.map((e) => e.message).toList(), [
        'Event 4',
        'Event 5',
        'Event 6',
        'Event 7',
        'Event 8',
      ]);
    });

    test('filters logs below minLevel', () {
      AppLogger.reset(capacity: 10, debugOutput: false, level: LogLevel.warn);

      AppLogger.d('Test', 'Debug log');
      AppLogger.i('Test', 'Info log');
      AppLogger.w('Test', 'Warn log');
      AppLogger.e('Test', 'Error log');

      final entries = AppLogger.getEntries();
      expect(entries.length, 2);
      expect(entries[0].level, LogLevel.warn);
      expect(entries[1].level, LogLevel.error);
    });

    test('supports lazy evaluation only when level is active', () {
      var evaluated = false;
      String expensiveBuilder() {
        evaluated = true;
        return 'Expensive result';
      }

      // Disabled level
      AppLogger.reset(capacity: 10, debugOutput: false, level: LogLevel.info);
      AppLogger.d('Test', expensiveBuilder);
      expect(evaluated, isFalse);

      // Enabled level
      AppLogger.i('Test', expensiveBuilder);
      expect(evaluated, isTrue);
    });

    test('formats log entries with error and stack trace', () {
      final trace = StackTrace.current;
      final entry = LogEntry(
        timestamp: DateTime.parse('2026-08-29T12:00:00.000Z'),
        level: LogLevel.error,
        tag: 'Player',
        message: 'Playback failed',
        error: 'Codec unsupported',
        stackTrace: trace,
      );

      final formatted = entry.format();
      expect(formatted, contains('[ERROR] [Player] Playback failed'));
      expect(formatted, contains('Error: Codec unsupported'));
      expect(formatted, contains(trace.toString()));
    });

    test('exports logs as chronological or reverse string', () {
      AppLogger.i('A', 'First');
      AppLogger.i('B', 'Second');

      final forward = AppLogger.exportLogs();
      expect(forward.indexOf('First'), lessThan(forward.indexOf('Second')));

      final reverse = AppLogger.exportLogs(reverse: true);
      expect(reverse.indexOf('Second'), lessThan(reverse.indexOf('First')));
    });

    test('benchmark: 5,000 insertions complete in under 50ms', () {
      AppLogger.reset(capacity: 500, debugOutput: false, level: LogLevel.debug);
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 5000; i++) {
        AppLogger.i('Benchmark', 'Event $i');
      }

      stopwatch.stop();
      // Average insertion is less than 0.01ms (5000 in < 50ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(AppLogger.count, 500);
    });
  });
}
