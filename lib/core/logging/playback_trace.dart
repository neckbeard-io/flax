import 'dart:io';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/logging/crash_log.dart';

/// What happened to playback and why, kept on disk in release builds.
///
/// Release builds keep only warnings and errors, so nothing said why music
/// paused or stopped in the car. Every play, pause, audio focus change and
/// end of track is written here. The media session's commands are added by
/// native code with the app that sent each one (`PlaybackTrace.kt`). On
/// Android:
///
///     adb pull /sdcard/Android/data/com.flaxplayer.flax/files/logs/flax-playback.log
class PlaybackTrace {
  PlaybackTrace._();

  static const fileName = 'flax-playback.log';

  /// Past this the file is cut to its newer half.
  static const maxBytes = 256 * 1024;

  static File? _file;

  /// Writes the trace into [logs], the folder the error log uses.
  static void init(Directory? logs) {
    if (logs == null) return;
    _file = File('${logs.path}${Platform.pathSeparator}$fileName');
  }

  static void record(String event) {
    AppLogger.i('Playback', event);
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $event\n',
        mode: FileMode.append,
      );
      CrashLog.keepTail(file, maxBytes);
    } catch (_) {}
  }
}
