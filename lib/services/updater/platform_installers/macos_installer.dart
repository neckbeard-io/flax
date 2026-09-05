import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flax/core/logging/app_logger.dart';

class MacOSInstaller {
  /// Checks if Flax was installed via Homebrew Cask.
  static bool isHomebrewInstall() {
    if (!Platform.isMacOS) return false;

    // Standard Homebrew Caskroom locations
    const brewArmPath = '/opt/homebrew/Caskroom/flax';
    const brewIntelPath = '/usr/local/Caskroom/flax';

    return Directory(brewArmPath).existsSync() ||
        Directory(brewIntelPath).existsSync();
  }

  /// Locates the current .app bundle path.
  static String findCurrentAppBundlePath() {
    final exe = Platform.resolvedExecutable;
    final appIndex = exe.indexOf('.app');
    if (appIndex != -1) {
      return exe.substring(0, appIndex + 4);
    }
    if (Directory('/Applications/flax.app').existsSync()) {
      return '/Applications/flax.app';
    }
    if (Directory('/Applications/Flax.app').existsSync()) {
      return '/Applications/Flax.app';
    }
    final home = Platform.environment['HOME'] ?? '';
    if (Directory('$home/Applications/flax.app').existsSync()) {
      return '$home/Applications/flax.app';
    }
    if (Directory('$home/Applications/Flax.app').existsSync()) {
      return '$home/Applications/Flax.app';
    }
    return '/Applications/flax.app';
  }

  /// Installs the update from the downloaded .dmg directly by staging the new
  /// .app bundle, detaching the DMG, and launching a background updater script
  /// that swaps the bundle once this process exits, then relaunches Flax.
  /// If programmatic in-place update fails, falls back to opening the DMG in Finder.
  static Future<void> openDmg(String dmgPath) async {
    if (!Platform.isMacOS) return;

    final targetAppPath = findCurrentAppBundlePath();
    AppLogger.i(
      'Updater',
      'Starting macOS in-place update: target=$targetAppPath, dmg=$dmgPath',
    );
    final stagingDir = await Directory.systemTemp.createTemp('flax-update-');
    String? mountedVolume;

    try {
      // 1. Attach DMG — try hdiutil first, fall back to DiskImageMounter
      String? mountPoint;

      final mountRes = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-plist',
        '-nobrowse',
        '-readonly',
        '-noautoopen',
        '-noverify',
      ]);

      if (mountRes.exitCode == 0) {
        final mountMatch = RegExp(
          r'<key>mount-point</key>\s*<string>([^<]+)</string>',
        ).firstMatch(mountRes.stdout.toString());
        mountPoint = mountMatch?.group(1);
      } else {
        // hdiutil can fail under App Sandbox or restricted entitlements.
        // Fall back to DiskImageMounter which runs out-of-process.
        AppLogger.w(
          'Updater',
          'hdiutil attach failed (${mountRes.exitCode}): '
              '${mountRes.stderr.toString().trim()}. '
              'Falling back to DiskImageMounter.',
        );
        await Process.run('open', ['-a', 'DiskImageMounter', dmgPath]);

        // Poll /Volumes for the mount to appear (up to 8 seconds)
        final volumeName = p
            .basenameWithoutExtension(dmgPath)
            .replaceAll(RegExp(r'-macos.*'), '');
        for (var i = 0; i < 32; i++) {
          await Future.delayed(const Duration(milliseconds: 250));
          final volumes = Directory(
            '/Volumes',
          ).listSync().whereType<Directory>().map((d) => d.path).toList();
          final match = volumes.firstWhere(
            (v) =>
                v.toLowerCase().contains('flax') ||
                v.toLowerCase().contains(volumeName.toLowerCase()),
            orElse: () => '',
          );
          if (match.isNotEmpty && Directory(match).listSync().isNotEmpty) {
            mountPoint = match;
            break;
          }
        }
        if (mountPoint == null) {
          throw Exception(
            'DMG did not mount within timeout after DiskImageMounter fallback.',
          );
        }
      }

      mountPoint ??= '/Volumes/flax';
      mountedVolume = mountPoint;

      final mountDir = Directory(mountPoint);
      if (!mountDir.existsSync()) {
        throw Exception('Mounted volume does not exist: $mountPoint');
      }

      final entries = mountDir.listSync();
      final appSource = entries
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.app'))
          .firstOrNull;

      if (appSource == null) {
        throw Exception(
          'No .app bundle found inside mounted DMG ($mountPoint).',
        );
      }

      final stagedAppPath = p.join(stagingDir.path, p.basename(appSource.path));

      // Copy new .app bundle to staging directory using ditto
      final cpStagedRes = await Process.run('ditto', [
        appSource.path,
        stagedAppPath,
      ]);
      if (cpStagedRes.exitCode != 0) {
        throw Exception(
          'Failed to stage .app bundle: ${cpStagedRes.stderr.toString().trim()}',
        );
      }

      // Detach the DMG now that files are in staging
      await Process.run('hdiutil', ['detach', mountPoint, '-force', '-quiet']);
      mountedVolume = null;

      // Strip quarantine and ensure standard execute permissions on staged app
      await Process.run('xattr', ['-cr', stagedAppPath]);
      await Process.run('chmod', ['-R', '755', stagedAppPath]);

      // Create detached update script in /tmp so it outlives the staging directory.
      final currentPid = pid;
      final scriptPath = '/tmp/flax_macos_update_$currentPid.sh';
      final scriptFile = File(scriptPath);

      await scriptFile.writeAsString('''#!/bin/bash
exec > /tmp/flax_macos_update.log 2>&1
set -ex

PID=$currentPid
STAGED_APP="$stagedAppPath"
TARGET_APP="$targetAppPath"
STAGING_DIR="${stagingDir.path}"
SCRIPT_PATH="$scriptPath"

# 1. Wait for running Flax process to terminate completely
while kill -0 "\$PID" 2>/dev/null; do
  sleep 0.1
done

# Buffer for OS file handles to release
sleep 0.3

# 2. Safely swap in the new app bundle
rm -rf "\$TARGET_APP" 2>/dev/null || true
if [ -d "\$TARGET_APP" ]; then
  mv "\$TARGET_APP" "\$STAGING_DIR/old_app" 2>/dev/null || true
  rm -rf "\$TARGET_APP" 2>/dev/null || true
fi

ditto "\$STAGED_APP" "\$TARGET_APP"
chmod -R 755 "\$TARGET_APP"
xattr -cr "\$TARGET_APP" 2>/dev/null || true

# 3. Relaunch updated Flax BEFORE cleaning up
open -n "\$TARGET_APP"

# 4. Clean up staging folder and update script
rm -rf "\$STAGING_DIR" 2>/dev/null || true
rm -f "\$SCRIPT_PATH" 2>/dev/null || true
''');

      await Process.run('chmod', ['+x', scriptFile.path]);

      // Launch the script detached from the current process
      await Process.start('/bin/bash', [
        scriptFile.path,
      ], mode: ProcessStartMode.detached);

      // Brief delay before exit to ensure detached script has spawned
      await Future.delayed(const Duration(milliseconds: 150));
      exit(0);
    } catch (e, st) {
      AppLogger.e(
        'Updater',
        'macOS in-place update failed: $e',
        error: e,
        stackTrace: st,
      );
      // Clean up mount and staging directories if still present
      if (mountedVolume != null) {
        try {
          await Process.run('hdiutil', [
            'detach',
            mountedVolume,
            '-force',
            '-quiet',
          ]);
        } catch (_) {}
      }
      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }

      // Graceful fallback: open the DMG directly in Finder
      try {
        await Process.run('open', [dmgPath]);
      } catch (_) {}

      throw Exception(
        'Automatic update error ($e). Opened installer in Finder.',
      );
    }
  }
}
