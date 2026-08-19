import 'dart:io';

class WindowsInstaller {
  /// Launches the downloaded Inno Setup installer and exits Flax so files can be replaced.
  static Future<void> launchInstaller(
    String setupExePath, {
    bool silent = false,
  }) async {
    if (!Platform.isWindows) return;

    final args = <String>[
      if (silent) ...['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
    ];

    try {
      await Process.start(
        setupExePath,
        args,
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      // Give the process a brief moment to spin up before exiting.
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      throw Exception('Failed to launch Windows installer: $e');
    }
  }
}
