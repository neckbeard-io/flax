import 'dart:io';

import 'package:flax/core/logging/app_logger.dart';

class WindowsInstaller {
  /// Launches the downloaded Inno Setup installer silently and exits Flax
  /// so files can be replaced and the updated Flax process restarted.
  static Future<void> launchInstaller(
    String setupExePath, {
    bool silent = true,
  }) async {
    if (!Platform.isWindows) return;

    final args = <String>[
      if (silent) ...[
        '/VERYSILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ],
    ];

    try {
      AppLogger.i(
        'Updater',
        'Launching Windows installer: $setupExePath args=$args',
      );
      await Process.start(
        setupExePath,
        args,
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      // Give the process a brief moment to spin up before exiting.
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e) {
      AppLogger.e('Updater', 'Failed to launch Windows installer', error: e);
      throw Exception('Failed to launch Windows installer: $e');
    }
  }
}
