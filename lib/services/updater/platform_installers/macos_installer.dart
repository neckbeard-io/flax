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

  /// Opens the downloaded .dmg volume so the user can drag flax.app to /Applications.
  static Future<void> openDmg(String dmgPath) async {
    if (!Platform.isMacOS) return;

    try {
      await Process.run('open', [dmgPath]);
    } catch (e) {
      throw Exception('Failed to open macOS DMG: $e');
    }
  }
}
