import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flax/core/logging/app_logger.dart';

class WindowsInstaller {
  /// Checks whether the current user has permissions to write directly into
  /// [dirPath] without requiring administrative (UAC) elevation.
  static bool canWriteWithoutElevation(String dirPath) {
    try {
      final testFile = File(p.join(dirPath, '.flax_update_perm_test'));
      testFile.writeAsStringSync('test');
      testFile.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Escapes single quotes for use inside a PowerShell single-quoted literal string.
  static String escapePowerShellString(String str) {
    return str.replaceAll("'", "''");
  }

  /// Builds the argument list for the Inno Setup installer executable.
  static List<String> buildInstallerArgs({
    required String installDir,
    bool silent = true,
    bool isUserWritable = true,
  }) {
    return [
      if (silent) ...[
        '/VERYSILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        if (isUserWritable) '/CURRENTUSER' else '/ALLUSERS',
      ],
      '/DIR="$installDir"',
    ];
  }

  /// Generates a PowerShell script that coordinates process termination,
  /// silent Inno Setup installation, and automatic application relaunch.
  static String buildUpdateScript({
    required int currentPid,
    required String setupExePath,
    required List<String> installerArgs,
    required String targetExePath,
    required String scriptPath,
  }) {
    final escapedSetup = escapePowerShellString(setupExePath);
    final escapedArgs = escapePowerShellString(installerArgs.join(' '));
    final escapedTarget = escapePowerShellString(targetExePath);
    final escapedScript = escapePowerShellString(scriptPath);

    return '''
# 1. Wait for current running Flax process to completely terminate
\$proc = Get-Process -Id $currentPid -ErrorAction SilentlyContinue
if (\$proc) {
    \$proc.WaitForExit(10000)
}
Start-Sleep -Milliseconds 500

# 2. Run the Inno Setup installer silently
\$setup = Start-Process -FilePath '$escapedSetup' -ArgumentList '$escapedArgs' -Wait -PassThru

# 3. Relaunch Flax upon successful installation
if (\$setup.ExitCode -eq 0 -or \$setup.ExitCode -eq \$null) {
    Start-Sleep -Milliseconds 500
    if (-not (Get-Process -Name 'flax' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath '$escapedTarget'
    }
}

# 4. Clean up downloaded installer and updater script
Start-Sleep -Seconds 2
Remove-Item -Path '$escapedSetup' -Force -ErrorAction SilentlyContinue
Remove-Item -Path '$escapedScript' -Force -ErrorAction SilentlyContinue
''';
  }

  /// Launches the downloaded Inno Setup installer silently and exits Flax
  /// so files can be replaced and the updated Flax process restarted.
  static Future<void> launchInstaller(
    String setupExePath, {
    bool silent = true,
  }) async {
    if (!Platform.isWindows) return;

    final targetExe = Platform.resolvedExecutable;
    final installDir = File(targetExe).parent.path;
    final userWritable = canWriteWithoutElevation(installDir);

    final innoArgs = buildInstallerArgs(
      installDir: installDir,
      silent: silent,
      isUserWritable: userWritable,
    );

    try {
      AppLogger.i(
        'Updater',
        'Launching Windows update for $targetExe via $setupExePath args=$innoArgs (userWritable=$userWritable)',
      );

      if (!silent) {
        await Process.start(
          setupExePath,
          innoArgs,
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
        await Future.delayed(const Duration(milliseconds: 500));
        exit(0);
      }

      // Create a temporary PowerShell script to coordinate exit -> install -> relaunch
      final currentPid = pid;
      final tempDir = Directory.systemTemp;
      final scriptFile = File(
        p.join(tempDir.path, 'flax_update_$currentPid.ps1'),
      );
      final scriptContent = buildUpdateScript(
        currentPid: currentPid,
        setupExePath: setupExePath,
        installerArgs: innoArgs,
        targetExePath: targetExe,
        scriptPath: scriptFile.path,
      );
      await scriptFile.writeAsString(scriptContent);

      try {
        await Process.start('powershell.exe', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptFile.path,
        ], mode: ProcessStartMode.detached);
      } catch (psError) {
        AppLogger.w(
          'Updater',
          'PowerShell runner failed ($psError), falling back to direct installer execution',
        );
        await Process.start(
          setupExePath,
          innoArgs,
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
      }

      // Give the background process a moment to spawn before exiting
      await Future.delayed(const Duration(milliseconds: 250));
      exit(0);
    } catch (e, st) {
      AppLogger.e(
        'Updater',
        'Failed to launch Windows installer',
        error: e,
        stackTrace: st,
      );
      throw Exception('Failed to launch Windows installer: $e');
    }
  }
}
