import 'dart:io';

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

  /// Installs the update from the downloaded .dmg directly to /Applications/flax.app,
  /// or falls back to opening the .dmg volume in Finder.
  static Future<void> openDmg(String dmgPath) async {
    if (!Platform.isMacOS) return;

    try {
      final appDest = Directory('/Applications/flax.app');
      final tempMountDir = await Directory.systemTemp.createTemp('flax-mount-');
      try {
        final mountRes = await Process.run('hdiutil', [
          'attach',
          dmgPath,
          '-mountpoint',
          tempMountDir.path,
          '-nobrowse',
          '-quiet',
        ]);

        if (mountRes.exitCode == 0) {
          final entries = tempMountDir.listSync();
          final appSource = entries
              .whereType<Directory>()
              .where((d) => d.path.endsWith('.app'))
              .firstOrNull;

          if (appSource != null) {
            if (appDest.existsSync()) {
              await Process.run('rm', ['-rf', appDest.path]);
            }
            final cpRes = await Process.run('cp', [
              '-R',
              appSource.path,
              '/Applications/',
            ]);
            await Process.run('hdiutil', [
              'detach',
              tempMountDir.path,
              '-quiet',
            ]);
            await Process.run('xattr', [
              '-dr',
              'com.apple.quarantine',
              '/Applications/flax.app',
            ]);

            if (cpRes.exitCode == 0) {
              await Process.run('open', ['-n', '/Applications/flax.app']);
              exit(0);
            }
          } else {
            await Process.run('hdiutil', [
              'detach',
              tempMountDir.path,
              '-quiet',
            ]);
          }
        }
      } catch (_) {
        // Fall back to opening Finder DMG
      } finally {
        if (tempMountDir.existsSync()) {
          try {
            await Process.run('hdiutil', [
              'detach',
              tempMountDir.path,
              '-quiet',
            ]);
            tempMountDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }

      await Process.run('open', [dmgPath]);
    } catch (e) {
      throw Exception('Failed to open macOS DMG: $e');
    }
  }
}
