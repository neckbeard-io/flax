import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flax/core/logging/app_logger.dart';

/// Updates flax on Windows by handing over to the downloaded Inno Setup
/// installer.
///
/// flax starts Setup and exits. Setup closes flax if it is still running,
/// replaces the files, and reopens flax when given [relaunchArg] (see the
/// `[Run]` section of `packaging/windows/flax.iss`).
///
/// This used to go through a PowerShell script, which never ran: started with
/// no console, as a detached process from a GUI app is, Windows PowerShell
/// exits with code 0 before running anything. flax closed and nothing
/// installed. Setup is a GUI program and needs no console.
class WindowsInstaller {
  /// Asks Setup to reopen flax once the files are replaced.
  static const relaunchArg = '/RELAUNCH=1';

  /// Checks whether the current user has permissions to write directly into
  /// [dirPath] without requiring administrative (UAC) elevation.
  static bool canWriteWithoutElevation(String dirPath) {
    try {
      final testFile = File(p.join(dirPath, '.flax_update_perm_test'));
      testFile.writeAsStringSync('test');
      try {
        testFile.deleteSync();
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The arguments to start Setup with.
  ///
  /// None carries quotes of its own. Dart quotes an argument that contains a
  /// space when it builds the command line, and Setup drops those quotes; a
  /// quote inside an argument would reach Setup escaped with a backslash,
  /// which it does not understand.
  static List<String> buildInstallerArgs({
    required String installDir,
    bool silent = true,
    bool isUserWritable = true,
    String? logFilePath,
  }) {
    return [
      if (silent) ...[
        '/VERYSILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        // Setup's own [Run] entry reopens flax; Restart Manager must not
        // start a second copy.
        '/NORESTARTAPPLICATIONS',
        relaunchArg,
        // An install for all users makes Setup ask for elevation itself.
        if (isUserWritable) '/CURRENTUSER' else '/ALLUSERS',
        if (logFilePath != null) '/LOG=$logFilePath' else '/LOG',
      ],
      '/DIR=$installDir',
    ];
  }

  /// Starts the downloaded installer [setupExePath] and exits flax so its
  /// files can be replaced.
  static Future<void> launchInstaller(
    String setupExePath, {
    bool silent = true,
  }) async {
    if (!Platform.isWindows) return;

    final targetExe = Platform.resolvedExecutable;
    final installDir = File(targetExe).parent.path;
    final userWritable = canWriteWithoutElevation(installDir);
    final args = buildInstallerArgs(
      installDir: installDir,
      silent: silent,
      isUserWritable: userWritable,
    );

    AppLogger.i(
      'Updater',
      'Launching Windows update for $targetExe via $setupExePath args=$args (userWritable=$userWritable)',
    );
    try {
      await Process.start(setupExePath, args, mode: ProcessStartMode.detached);
    } catch (e, st) {
      AppLogger.e(
        'Updater',
        'Failed to launch Windows installer',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to launch Windows installer: $e');
    }

    // Setup closes flax itself if it is still running when the files are
    // replaced; exiting now just spares it the wait.
    await Future.delayed(const Duration(milliseconds: 250));
    exit(0);
  }

  /// Deletes what earlier updates left in [tempDir]: downloaded installers,
  /// which a running Setup cannot delete itself, and the update scripts older
  /// versions wrote and never ran. Returns how many files were deleted.
  static Future<int> deleteLeftovers(Directory tempDir) async {
    final leftover = RegExp(
      r'^(flax-.+-windows-x64-setup\.exe|flax_update_\d+\.ps1)$',
    );
    var deleted = 0;
    try {
      await for (final entity in tempDir.list()) {
        if (entity is! File || !leftover.hasMatch(p.basename(entity.path))) {
          continue;
        }
        try {
          await entity.delete();
          deleted++;
        } catch (_) {
          // Still in use, e.g. by the Setup that just relaunched flax.
        }
      }
    } catch (e) {
      AppLogger.w('Updater', 'Could not clean up old update files: $e');
    }
    return deleted;
  }
}
