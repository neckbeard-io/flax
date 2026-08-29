import 'dart:io';
import 'package:path/path.dart' as p;

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
    final stagingDir = await Directory.systemTemp.createTemp('flax-update-');
    String? mountedVolume;

    try {
      // 1. Attach DMG using standard Apple plist output without custom mountpoint
      final mountRes = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-plist',
        '-nobrowse',
        '-readonly',
        '-noautoopen',
        '-noverify',
      ]);

      if (mountRes.exitCode != 0) {
        throw Exception(
          'Failed to attach DMG (exit code ${mountRes.exitCode}): ${mountRes.stderr.toString().trim()}',
        );
      }

      // Parse mount point from plist stdout
      final mountMatch = RegExp(
        r'<key>mount-point</key>\s*<string>([^<]+)</string>',
      ).firstMatch(mountRes.stdout.toString());
      final mountPoint = mountMatch?.group(1) ?? '/Volumes/flax';
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

      // Copy new .app bundle to staging directory
      final cpStagedRes = await Process.run('cp', [
        '-R',
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

      // Strip quarantine on staged app
      await Process.run('xattr', [
        '-dr',
        'com.apple.quarantine',
        stagedAppPath,
      ]);

      // Create detached update script that waits for current process to exit,
      // replaces the app bundle, and launches the updated version.
      final scriptFile = File(p.join(stagingDir.path, 'update.sh'));
      final currentPid = pid;

      await scriptFile.writeAsString('''#!/bin/bash
PID=$currentPid
STAGED_APP="$stagedAppPath"
TARGET_APP="$targetAppPath"
STAGING_DIR="${stagingDir.path}"

# 1. Wait for Flax process to terminate completely
while kill -0 "\$PID" 2>/dev/null; do
  sleep 0.1
done

# Small buffer for OS file handles to release
sleep 0.2

# 2. Atomically swap in the new app bundle
rm -rf "\$TARGET_APP"
cp -R "\$STAGED_APP" "\$TARGET_APP"
xattr -dr com.apple.quarantine "\$TARGET_APP" 2>/dev/null || true

# 3. Clean up staging folder
rm -rf "\$STAGING_DIR"

# 4. Relaunch updated Flax
open -n "\$TARGET_APP"
''');

      await Process.run('chmod', ['+x', scriptFile.path]);

      // Launch the script detached from the current process
      await Process.start('/bin/bash', [
        scriptFile.path,
      ], mode: ProcessStartMode.detached);

      // Brief delay before exit to ensure detached script has spawned
      await Future.delayed(const Duration(milliseconds: 100));
      exit(0);
    } catch (e) {
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
