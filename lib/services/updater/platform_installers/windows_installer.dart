import 'dart:convert';
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
      try {
        testFile.deleteSync();
      } catch (_) {}
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
    String? logFilePath,
  }) {
    return [
      if (silent) ...[
        '/VERYSILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        // The update script relaunches flax; Setup must not start a second copy.
        '/NORESTARTAPPLICATIONS',
        if (isUserWritable) '/CURRENTUSER' else '/ALLUSERS',
        if (logFilePath != null) '/LOG="$logFilePath"' else '/LOG',
      ],
      '/DIR="$installDir"',
    ];
  }

  /// Generates a PowerShell script that coordinates process termination,
  /// silent Inno Setup installation, and automatic application relaunch.
  ///
  /// Every value is assigned once as a single-quoted PowerShell literal, in
  /// which only a doubled single quote is special. A backtick there is an
  /// ordinary character, so the argument string must carry its double quotes
  /// bare: Start-Process hands it to Setup verbatim, and Setup strips them.
  static String buildUpdateScript({
    required int currentPid,
    required String setupExePath,
    required List<String> installerArgs,
    required String targetExePath,
    required String scriptPath,
    bool isElevated = false,
  }) {
    String literal(String value) => "'${escapePowerShellString(value)}'";
    final verbParam = isElevated ? '-Verb RunAs ' : '';

    return '''
\$logPath = "\$env:TEMP\\flax_updater.log"
\$setupPath = ${literal(setupExePath)}
\$setupArgs = ${literal(installerArgs.join(' '))}
\$targetExe = ${literal(targetExePath)}
\$scriptPath = ${literal(scriptPath)}

function Log(\$msg) {
    \$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path \$logPath -Value "[\$ts] \$msg" -ErrorAction SilentlyContinue
}

Log "Updater script started for PID $currentPid."

# 1. Wait for current running Flax process to completely terminate
\$proc = Get-Process -Id $currentPid -ErrorAction SilentlyContinue
if (\$proc) {
    Log "Waiting up to 10s for PID $currentPid to exit..."
    \$proc.WaitForExit(10000)
}
Start-Sleep -Milliseconds 500

# 2. Run the Inno Setup installer silently
Log "Launching installer '\$setupPath' with args: \$setupArgs (elevated: $isElevated)"
try {
    \$setup = Start-Process -FilePath \$setupPath -ArgumentList \$setupArgs $verbParam-Wait -PassThru
    Log "Installer exited with code: \$(\$setup.ExitCode)"
} catch {
    Log "Installer failed to start: \$_"
    \$setup = \$null
}
\$installed = \$setup -and (\$setup.ExitCode -eq 0 -or \$setup.ExitCode -eq \$null)

# 3. Relaunch Flax upon successful installation
if (\$installed) {
    Log "Installation successful. Relaunching Flax at '\$targetExe'..."
    Start-Sleep -Milliseconds 500
    \$targetDir = Split-Path -Parent \$targetExe
    try {
        Start-Process -FilePath \$targetExe -WorkingDirectory \$targetDir
        Log "Flax relaunched successfully."
    } catch {
        Log "Failed to relaunch Flax: \$_"
    }
} else {
    Log "Installation failed or non-zero exit code. Skipping relaunch."
}

# 4. Clean up downloaded installer and updater script if successful
if (\$installed) {
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath \$setupPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath \$scriptPath -Force -ErrorAction SilentlyContinue
} else {
    Log "Retaining installer and script for inspection."
}
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
        isElevated: !userWritable,
      );
      // Windows PowerShell reads a script without a byte order mark in the
      // ANSI code page, which would garble any non-ASCII character in a path.
      await scriptFile.writeAsBytes([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(scriptContent),
      ]);

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
