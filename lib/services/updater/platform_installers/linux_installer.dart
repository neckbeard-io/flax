import 'dart:io';
import 'package:path/path.dart' as p;

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

  /// Checks if Flax is running from a standalone curl installation (~/.local/share/flax or /opt/flax).
  static bool isStandaloneTarInstall() {
    if (!Platform.isLinux) return false;
    final exe = Platform.resolvedExecutable;
    return exe.contains('.local/share/flax') ||
        exe.contains('/opt/flax') ||
        File(
          '${Platform.environment['HOME']}/.local/share/flax/flax',
        ).existsSync();
  }

  /// Opens or installs the downloaded package (.deb, .rpm, or .tar.gz).
  static Future<void> openPackage(String packagePath) async {
    if (!Platform.isLinux) return;

    try {
      // 1. Direct in-place upgrade for standalone tar.gz installs
      if (packagePath.endsWith('.tar.gz')) {
        final home = Platform.environment['HOME'] ?? '';
        final destDir = Directory('$home/.local/share/flax');
        if (destDir.existsSync()) {
          final stagingDir = await Directory.systemTemp.createTemp(
            'flax-linux-update-',
          );
          final tarRes = await Process.run('tar', [
            '-xzf',
            packagePath,
            '-C',
            stagingDir.path,
            '--strip-components=1',
          ]);
          if (tarRes.exitCode == 0) {
            final scriptFile = File(p.join(stagingDir.path, 'update.sh'));
            final currentPid = pid;
            final targetDirPath = destDir.path;

            await scriptFile.writeAsString('''#!/bin/bash
PID=$currentPid
STAGING_DIR="${stagingDir.path}"
TARGET_DIR="$targetDirPath"

while kill -0 "\$PID" 2>/dev/null; do
  sleep 0.1
done
sleep 0.2

rm -rf "\$TARGET_DIR"/*
cp -r "\$STAGING_DIR"/* "\$TARGET_DIR"/
rm -rf "\$STAGING_DIR"

"\$TARGET_DIR/flax" &
''');
            await Process.run('chmod', ['+x', scriptFile.path]);
            await Process.start('/bin/bash', [
              scriptFile.path,
            ], mode: ProcessStartMode.detached);
            await Future.delayed(const Duration(milliseconds: 100));
            exit(0);
          }
        }
      }

      // 2. Try pkexec dpkg or rpm for native packages
      if (packagePath.endsWith('.deb')) {
        final res = await Process.run('pkexec', ['dpkg', '-i', packagePath]);
        if (res.exitCode == 0) {
          await Process.start('flax', [], mode: ProcessStartMode.detached);
          exit(0);
        }
      } else if (packagePath.endsWith('.rpm')) {
        final res = await Process.run('pkexec', ['rpm', '-Uvh', packagePath]);
        if (res.exitCode == 0) {
          await Process.start('flax', [], mode: ProcessStartMode.detached);
          exit(0);
        }
      }

      // 3. Fallback: try xdg-open to let the desktop environment handle it
      final result = await Process.run('xdg-open', [packagePath]);
      if (result.exitCode != 0) {
        final parentDir = File(packagePath).parent.path;
        await Process.run('xdg-open', [parentDir]);
      }
    } catch (e) {
      throw Exception('Failed to open Linux package: $e');
    }
  }
}
