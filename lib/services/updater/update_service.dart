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
      if (LinuxInstaller.isDebianBased()) {
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

  /// Checks GitHub Releases API for new versions.
  Future<ReleaseInfo?> fetchLatestRelease() async {
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

    return releases.firstOrNull;
  }

  /// Compares two semver strings (e.g. "0.4.6" vs "0.4.5"). Returns >0 if v1 > v2.
  static int compareSemver(String v1, String v2) {
    final clean1 = v1.replaceAll(RegExp(r'[^0-9.]'), '');
    final clean2 = v2.replaceAll(RegExp(r'[^0-9.]'), '');

    final parts1 = clean1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final parts2 = clean2.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final maxLen = parts1.length > parts2.length
        ? parts1.length
        : parts2.length;
    for (var i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
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
