import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flax/core/logging/app_logger.dart';

/// Unexpected errors, kept on disk.
///
/// [AppLogger] lives in memory, so the reason a screen broke used to vanish
/// with the force stop that fixed it. Each error is appended here with the log
/// lines that led up to it.
///
/// On Android the file is in the app's external files directory, which adb can
/// read from a release build:
///
/// ```bash
/// adb pull /sdcard/Android/data/com.flaxplayer.flax/files/logs/flax-errors.log
/// ```
class CrashLog {
  CrashLog._();

  static const fileName = 'flax-errors.log';

  /// Beyond this the oldest half of the file is dropped.
  static const maxBytes = 256 * 1024;

  /// Log lines written ahead of the first error of a run.
  static const contextLines = 40;

  static File? _file;
  static String? _lastSummary;
  static int _repeats = 0;
  static bool _wroteContext = false;

  /// Where errors are written, once [init] has run.
  static String? get path => _file?.path;

  /// The `logs` folder the error log is in, once [init] has run.
  static Directory? get directory => _file?.parent;

  /// Opens the log under [directory], or the platform default.
  static Future<void> init({Directory? directory}) async {
    try {
      final base = directory ?? await _defaultDirectory();
      final logs = Directory('${base.path}${Platform.pathSeparator}logs');
      await logs.create(recursive: true);
      _file = File('${logs.path}${Platform.pathSeparator}$fileName');
    } catch (e, st) {
      AppLogger.w('CrashLog', 'No error log on disk', error: e, stackTrace: st);
    }
  }

  static Future<Directory> _defaultDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    }
    return getApplicationSupportDirectory();
  }

  /// Records [error] from [source]. The same error raised again straight
  /// after — a broken widget fails on every rebuild — is counted, not
  /// rewritten.
  static void record(String source, Object error, StackTrace? stack) {
    final summary = '$error';
    if (summary == _lastSummary) {
      _repeats++;
      return;
    }

    final trace = _trim(stack);
    final file = _file;
    if (file == null) return;
    final out = StringBuffer();
    if (_repeats > 0) {
      out.writeln('(previous error repeated $_repeats more times)');
    }
    out
      ..writeln('=== ${DateTime.now().toIso8601String()} $source')
      ..writeln(summary)
      ..writeln(trace);
    if (!_wroteContext) {
      _wroteContext = true;
      final entries = AppLogger.getEntries();
      final recent = entries.length > contextLines
          ? entries.sublist(entries.length - contextLines)
          : entries;
      out.writeln('--- log before this error ---');
      // One line each: the newest is usually this error, stack and all.
      for (final entry in recent) {
        out.writeln(entry.format().split('\n').first);
      }
    }
    out.writeln();
    _lastSummary = summary;
    _repeats = 0;

    try {
      file.writeAsStringSync(out.toString(), mode: FileMode.append);
      keepTail(file, maxBytes);
    } catch (_) {
      // Nowhere left to report a failure to record a failure.
    }
  }

  /// Cuts [file] to its newer half once it grows past [maxBytes].
  static void keepTail(File file, int maxBytes) {
    if (file.lengthSync() <= maxBytes) return;
    final bytes = file.readAsBytesSync();
    var tail = bytes.sublist(bytes.length - maxBytes ~/ 2);
    // Cut at a line break: a byte offset can land inside a multi-byte
    // character, and one malformed character makes the file unreadable.
    final lineBreak = tail.indexOf(0x0A);
    if (lineBreak >= 0) tail = tail.sublist(lineBreak + 1);
    file.writeAsBytesSync(tail);
  }

  /// The most recent [maxChars] of the log, or null when nothing was saved.
  static String? readRecent({int maxChars = 16000}) {
    final file = _file;
    if (file == null) return null;
    try {
      if (!file.existsSync()) return null;
      final text = file.readAsStringSync();
      if (text.trim().isEmpty) return null;
      return text.length > maxChars
          ? text.substring(text.length - maxChars)
          : text;
    } catch (_) {
      return null;
    }
  }

  static String _trim(StackTrace? stack) {
    if (stack == null) return '';
    final lines = stack.toString().split('\n');
    return lines.length > 40 ? lines.take(40).join('\n') : lines.join('\n');
  }

  @visibleForTesting
  static void resetForTest() {
    _file = null;
    _lastSummary = null;
    _repeats = 0;
    _wroteContext = false;
  }
}
