import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_installers/android_installer.dart';
import 'platform_installers/linux_installer.dart';
import 'platform_installers/macos_installer.dart';
import 'platform_installers/windows_installer.dart';
import 'update_models.dart';

class UpdateService {
  static const String repoOwner = 'neckbeard-io';
  static const String repoName = 'flax';
  static const String releasesUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases';

  final Dio _dio;

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// Determines the installation method for the current host OS.
  InstallMethod detectInstallMethod() {
    if (Platform.isAndroid) {
      return InstallMethod.androidApk;
    } else if (Platform.isWindows) {
      return InstallMethod.windowsInstaller;
    } else if (Platform.isMacOS) {
      if (MacOSInstaller.isHomebrewInstall()) {
        return InstallMethod.macosHomebrew;
      }
      return InstallMethod.macosDmg;
    } else if (Platform.isLinux) {
      if (LinuxInstaller.isStandaloneTarInstall()) {
        return InstallMethod.linuxTarGz;
      } else if (LinuxInstaller.isDebianBased()) {
        return InstallMethod.linuxDeb;
      } else if (LinuxInstaller.isRpmBased()) {
        return InstallMethod.linuxRpm;
      }
      return InstallMethod.linuxTarGz;
    }
    return InstallMethod.unsupported;
  }

  /// Gets the currently installed app version (e.g. "0.4.5").
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.4.5';
    }
  }

  /// Checks GitHub Releases API for new versions based on the selected [channel].
  Future<ReleaseInfo?> fetchLatestRelease({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      releasesUrl,
      options: Options(
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Flax-UpdateChecker',
        },
      ),
    );

    final data = response.data;
    if (data == null || data.isEmpty) return null;

    // Filter for the latest valid release
    final releases = data
        .whereType<Map<String, dynamic>>()
        .map(ReleaseInfo.fromJson)
        .toList();

    if (channel == UpdateChannel.stable) {
      return releases.firstWhereOrNull(
        (r) => !r.isPrerelease && !r.tagName.toLowerCase().contains('-dev'),
      );
    } else {
      return releases.firstOrNull;
    }
  }

  /// Compares two semver strings (e.g. "0.5.6-dev.1" vs "0.5.5" or "0.5.6").
  /// Adheres to SemVer 2.0 precedence:
  /// - Higher core version (major.minor.patch) takes precedence regardless of prerelease.
  /// - A normal version has higher precedence than a pre-release of the same core version.
  /// - Pre-release identifiers are compared lexicographically / numerically.
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, and 0 if v1 == v2.
  static int compareSemver(String v1, String v2) {
    final parsed1 = _parseSemver(v1);
    final parsed2 = _parseSemver(v2);

    // 1. Compare core versions (major, minor, patch)
    for (var i = 0; i < 3; i++) {
      final p1 = parsed1.core[i];
      final p2 = parsed2.core[i];
      if (p1 != p2) return p1.compareTo(p2);
    }

    // 2. Core versions are identical. Check pre-release presence.
    final pre1 = parsed1.prerelease;
    final pre2 = parsed2.prerelease;

    if (pre1 == null && pre2 == null) return 0;
    // A version without a pre-release tag has higher precedence than one with a pre-release
    if (pre1 == null && pre2 != null) return 1;
    if (pre1 != null && pre2 == null) return -1;

    // 3. Both have pre-release identifiers (e.g. "dev.1" vs "dev.2")
    final parts1 = pre1!.split('.');
    final parts2 = pre2!.split('.');
    final minLen = parts1.length < parts2.length
        ? parts1.length
        : parts2.length;

    for (var i = 0; i < minLen; i++) {
      final part1 = parts1[i];
      final part2 = parts2[i];

      final num1 = int.tryParse(part1);
      final num2 = int.tryParse(part2);

      if (num1 != null && num2 != null) {
        if (num1 != num2) return num1.compareTo(num2);
      } else if (num1 != null && num2 == null) {
        return -1; // numeric identifiers have lower precedence than non-numeric
      } else if (num1 == null && num2 != null) {
        return 1;
      } else {
        final cmp = part1.compareTo(part2);
        if (cmp != 0) return cmp;
      }
    }

    return parts1.length.compareTo(parts2.length);
  }

  static ({List<int> core, String? prerelease}) _parseSemver(String version) {
    var raw = version.trim();
    if (raw.startsWith('v') || raw.startsWith('V')) {
      raw = raw.substring(1);
    }
    // Remove build metadata after '+'
    final plusIdx = raw.indexOf('+');
    if (plusIdx != -1) {
      raw = raw.substring(0, plusIdx);
    }

    final dashIdx = raw.indexOf('-');
    final String coreStr;
    final String? prerelease;
    if (dashIdx != -1) {
      coreStr = raw.substring(0, dashIdx);
      prerelease = raw.substring(dashIdx + 1);
    } else {
      coreStr = raw;
      prerelease = null;
    }

    final parts = coreStr
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }

    return (core: parts.take(3).toList(), prerelease: prerelease);
  }

  /// Finds the matching downloadable asset for the given install method.
  ReleaseAsset? findMatchingAsset(ReleaseInfo release, InstallMethod method) {
    final assets = release.assets;

    switch (method) {
      case InstallMethod.androidApk:
        return assets.firstWhereOrNull(
          (a) =>
              a.name.endsWith('-android-universal.apk') ||
              a.name.endsWith('.apk'),
        );
      case InstallMethod.windowsInstaller:
        return assets.firstWhereOrNull(
          (a) =>
              a.name.endsWith('-windows-x64-setup.exe') ||
              a.name.endsWith('.exe'),
        );
      case InstallMethod.macosDmg:
      case InstallMethod.macosHomebrew:
        return assets.firstWhereOrNull(
          (a) =>
              a.name.endsWith('-macos-universal.dmg') ||
              a.name.endsWith('.dmg'),
        );
      case InstallMethod.linuxDeb:
        return assets.firstWhereOrNull(
          (a) => a.name.endsWith('-linux-amd64.deb') || a.name.endsWith('.deb'),
        );
      case InstallMethod.linuxRpm:
        return assets.firstWhereOrNull(
          (a) =>
              a.name.endsWith('-linux-x86_64.rpm') || a.name.endsWith('.rpm'),
        );
      case InstallMethod.linuxTarGz:
        return assets.firstWhereOrNull(
          (a) =>
              a.name.endsWith('-linux-x64.tar.gz') ||
              a.name.endsWith('.tar.gz'),
        );
      case InstallMethod.unsupported:
        return null;
    }
  }

  /// Downloads the specified asset with real-time byte progress.
  Future<String> downloadAsset(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(tempDir.path, asset.name);

    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    await _dio.download(
      asset.downloadUrl,
      targetPath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Accept': 'application/octet-stream',
          'User-Agent': 'Flax-UpdateChecker',
        },
      ),
    );

    return targetPath;
  }

  /// Triggers the platform-specific installation or upgrade process.
  Future<void> installUpdate({
    required InstallMethod method,
    required String filePath,
  }) async {
    switch (method) {
      case InstallMethod.androidApk:
        await AndroidInstaller.installApk(filePath);
      case InstallMethod.windowsInstaller:
        await WindowsInstaller.launchInstaller(filePath);
      case InstallMethod.macosDmg:
        await MacOSInstaller.openDmg(filePath);
      case InstallMethod.macosHomebrew:
        // For Homebrew, user runs `brew upgrade --cask flax`
        break;
      case InstallMethod.linuxDeb:
      case InstallMethod.linuxRpm:
      case InstallMethod.linuxTarGz:
        await LinuxInstaller.openPackage(filePath);
      case InstallMethod.unsupported:
        throw UnsupportedError(
          'Automatic update not supported on this platform',
        );
    }
  }
}

extension _IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
