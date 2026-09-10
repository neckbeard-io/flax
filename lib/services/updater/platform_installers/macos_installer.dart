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

  /// Returns currently mounted volume paths under /Volumes, safe against
  /// macOS TCC permission errors (PathAccessException / errno = 1).
  static List<String> getMountedVolumes() {
    try {
      final volumes = Directory(
        '/Volumes',
      ).listSync().whereType<Directory>().map((d) => d.path).toList();
      if (volumes.isNotEmpty) return volumes;
    } catch (_) {}

    try {
      final res = Process.runSync('mount', []);
      if (res.exitCode == 0) {
        final matches = RegExp(
          r'on\s+(/Volumes/[^\s(]+)',
        ).allMatches(res.stdout.toString());
        return matches.map((m) => m.group(1)!).toList();
      }
    } catch (_) {}

    return const [];
  }

  /// Locates the .app bundle inside the mounted DMG volume without failing on
  /// macOS TCC directory listing restrictions.
  static Future<String?> findAppBundleInside(
    String mountPoint,
    String targetAppPath,
  ) async {
    final targetName = p.basename(targetAppPath);
    final candidates = <String>{
      p.join(mountPoint, targetName),
      p.join(mountPoint, 'flax.app'),
      p.join(mountPoint, 'Flax.app'),
    };

    // 1. Direct candidate path existence check (fast, avoids directory enumeration)
    for (final candidate in candidates) {
      try {
        if (Directory(candidate).existsSync()) {
          return candidate;
        }
      } catch (_) {}
    }

    // 2. Out-of-process `find` tool (bypasses in-process TCC directory enumeration limits)
    try {
      final findRes = await Process.run('find', [
        mountPoint,
        '-maxdepth',
        '2',
        '-name',
        '*.app',
      ]);
      if (findRes.exitCode == 0) {
        final lines = findRes.stdout
            .toString()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.endsWith('.app'))
            .toList();
        if (lines.isNotEmpty) {
          return lines.first;
        }
      }
    } catch (_) {}

    // 3. Fallback to Directory.listSync() in a safe try-catch block
    try {
      final entries = Directory(mountPoint).listSync();
      final appSource = entries
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.app'))
          .firstOrNull;
      if (appSource != null) {
        return appSource.path;
      }
    } catch (e) {
      AppLogger.w(
        'Updater',
        'Directory.listSync failed on $mountPoint ($e), falling back to candidate checks.',
      );
    }

    // 4. Shell test -d fallback on candidates
    for (final candidate in candidates) {
      try {
        final testRes = await Process.run('test', ['-d', candidate]);
        if (testRes.exitCode == 0) {
          return candidate;
        }
      } catch (_) {}
    }

    return null;
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
    final privateMountDir = Directory(p.join(stagingDir.path, 'mnt'));
    await privateMountDir.create(recursive: true);
    String? mountedVolume;

    try {
      // 1. Attach DMG:
      // Try attaching to a private mountpoint inside staging directory first.
      // Mounting to a private temp directory completely avoids macOS TCC
      // "Removable Volumes" permission restrictions (errno = 1).
      String? mountPoint;

      final privateMountRes = await Process.run('hdiutil', [
        'attach',
        dmgPath,
        '-mountpoint',
        privateMountDir.path,
        '-nobrowse',
        '-readonly',
        '-noautoopen',
        '-noverify',
      ]);

      if (privateMountRes.exitCode == 0) {
        mountPoint = privateMountDir.path;
        mountedVolume = mountPoint;
        AppLogger.i(
          'Updater',
          'Attached DMG to private mountpoint: $mountPoint',
        );
      } else {
        AppLogger.w(
          'Updater',
          'hdiutil attach with private mountpoint failed (${privateMountRes.exitCode}): '
              '${privateMountRes.stderr.toString().trim()}. Falling back to standard attach.',
        );

        // Fallback 1a: Standard hdiutil attach
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
          mountedVolume = mountPoint;
          AppLogger.i(
            'Updater',
            'Attached DMG to standard volume: $mountPoint',
          );
        } else {
          // Fallback 1b: DiskImageMounter (runs out-of-process)
          AppLogger.w(
            'Updater',
            'Standard hdiutil attach failed (${mountRes.exitCode}): '
                '${mountRes.stderr.toString().trim()}. Falling back to DiskImageMounter.',
          );
          await Process.run('open', ['-a', 'DiskImageMounter', dmgPath]);

          // Poll mounted volumes (up to 8 seconds) using getMountedVolumes()
          final volumeName = p
              .basenameWithoutExtension(dmgPath)
              .replaceAll(RegExp(r'-macos.*'), '');
          for (var i = 0; i < 32; i++) {
            await Future.delayed(const Duration(milliseconds: 250));
            final volumes = getMountedVolumes();
            final match = volumes.firstWhere(
              (v) =>
                  v.toLowerCase().contains('flax') ||
                  v.toLowerCase().contains(volumeName.toLowerCase()),
              orElse: () => '',
            );
            if (match.isNotEmpty) {
              mountPoint = match;
              mountedVolume = mountPoint;
              break;
            }
          }
          if (mountPoint == null) {
            throw Exception(
              'DMG did not mount within timeout after DiskImageMounter fallback.',
            );
          }
        }
      }

      mountPoint ??= '/Volumes/flax';
      mountedVolume ??= mountPoint;

      // 2. Locate .app bundle inside mount point
      final appSourcePath = await findAppBundleInside(
        mountPoint,
        targetAppPath,
      );
      if (appSourcePath == null) {
        throw Exception(
          'No .app bundle found inside mounted DMG ($mountPoint).',
        );
      }

      final stagedAppPath = p.join(stagingDir.path, p.basename(appSourcePath));

      // 3. Copy new .app bundle to staging directory using ditto
      final cpStagedRes = await Process.run('ditto', [
        appSourcePath,
        stagedAppPath,
      ]);
      if (cpStagedRes.exitCode != 0) {
        throw Exception(
          'Failed to stage .app bundle: ${cpStagedRes.stderr.toString().trim()}',
        );
      }

      // 4. Detach the DMG now that files are in staging
      await Process.run('hdiutil', [
        'detach',
        mountedVolume,
        '-force',
        '-quiet',
      ]);
      mountedVolume = null;

      // Strip quarantine and ensure standard execute permissions on staged app
      await Process.run('xattr', ['-cr', stagedAppPath]);
      await Process.run('chmod', ['-R', '755', stagedAppPath]);

      // 5. Create detached update script in /tmp so it outlives the staging directory.
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
        try {
          stagingDir.deleteSync(recursive: true);
        } catch (_) {}
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
