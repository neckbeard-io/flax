import 'dart:io';

class LinuxInstaller {
  /// Detects whether host is Debian/Ubuntu based (.deb) or Fedora/RHEL/openSUSE (.rpm).
  static bool isDebianBased() {
    return File('/etc/debian_version').existsSync() ||
        _osReleaseContains(['ubuntu', 'debian', 'pop', 'mint']);
  }

  static bool isRpmBased() {
    return File('/etc/fedora-release').existsSync() ||
        File('/etc/redhat-release').existsSync() ||
        _osReleaseContains(['fedora', 'rhel', 'centos', 'suse', 'opensuse']);
  }

  static bool _osReleaseContains(List<String> keywords) {
    final osRelease = File('/etc/os-release');
    if (osRelease.existsSync()) {
      try {
        final content = osRelease.readAsStringSync().toLowerCase();
        return keywords.any((k) => content.contains(k));
      } catch (_) {}
    }
    return false;
  }

  /// Opens the downloaded package (.deb or .rpm) with the system package manager (e.g. Software Center or GDebi).
  static Future<void> openPackage(String packagePath) async {
    if (!Platform.isLinux) return;

    try {
      // 1. Try xdg-open to let the desktop environment handle it
      final result = await Process.run('xdg-open', [packagePath]);
      if (result.exitCode != 0) {
        // Fallback: try opening the folder containing the package
        final parentDir = File(packagePath).parent.path;
        await Process.run('xdg-open', [parentDir]);
      }
    } catch (e) {
      throw Exception('Failed to open Linux package: $e');
    }
  }
}
