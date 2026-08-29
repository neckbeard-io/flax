import 'package:flutter/foundation.dart';

/// Installation / package management method for Flax on the current host.
enum InstallMethod {
  androidApk('Android APK', 'sideloaded'),
  windowsInstaller('Windows Installer', '.exe'),
  macosHomebrew('Homebrew Cask', 'brew'),
  macosDmg('macOS Universal DMG', '.dmg'),
  linuxDeb('Debian / Ubuntu Package', '.deb'),
  linuxRpm('Fedora / RPM Package', '.rpm'),
  linuxTarGz('Portable Linux Archive', '.tar.gz'),
  unsupported('Unsupported', 'manual');

  final String label;
  final String format;
  const InstallMethod(this.label, this.format);
}

/// Lifecycle stages of the self-update state machine.
enum UpdateStage {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  installing,
  upToDate,
  error,
}

/// Release metadata retrieved from GitHub Releases API.
@immutable
class ReleaseInfo {
  final String tagName;
  final String version;
  final String title;
  final String body;
  final String htmlUrl;
  final DateTime publishedAt;
  final bool isPrerelease;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isPrerelease,
    required this.assets,
  });

  /// Extracts the tight user-facing changelog section (before any divider).
  String get conciseChangelog {
    final divider = body.indexOf('\n---');
    if (divider != -1) {
      return body.substring(0, divider).trim();
    }
    return body.trim();
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    final assetsJson = json['assets'] as List<dynamic>? ?? [];

    return ReleaseInfo(
      tagName: tag,
      version: version,
      title: json['name'] as String? ?? tag,
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
          DateTime.now(),
      isPrerelease: json['prerelease'] as bool? ?? false,
      assets: assetsJson
          .map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Individual downloadable binary asset from a GitHub Release.
@immutable
class ReleaseAsset {
  final int id;
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;

  const ReleaseAsset({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: json['size'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }
}

/// Immutable state published to the UI and Riverpod providers.
@immutable
class UpdateState {
  final UpdateStage stage;
  final ReleaseInfo? latestRelease;
  final ReleaseAsset? matchingAsset;
  final InstallMethod installMethod;
  final String currentVersion;
  final double downloadProgress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? localFilePath;
  final String? errorMessage;
  final DateTime? lastCheckedAt;

  const UpdateState({
    this.stage = UpdateStage.idle,
    this.latestRelease,
    this.matchingAsset,
    this.installMethod = InstallMethod.unsupported,
    this.currentVersion = '0.0.0',
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localFilePath,
    this.errorMessage,
    this.lastCheckedAt,
  });

  bool get isUpdateAvailable =>
      stage == UpdateStage.available ||
      stage == UpdateStage.downloading ||
      stage == UpdateStage.readyToInstall ||
      stage == UpdateStage.installing ||
      (stage == UpdateStage.checking && matchingAsset != null);

  bool get isDownloading => stage == UpdateStage.downloading;
  bool get isReadyToInstall => stage == UpdateStage.readyToInstall;
  bool get isInstalling => stage == UpdateStage.installing;
  bool get isChecking => stage == UpdateStage.checking;

  UpdateState copyWith({
    UpdateStage? stage,
    ReleaseInfo? latestRelease,
    ReleaseAsset? matchingAsset,
    InstallMethod? installMethod,
    String? currentVersion,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? localFilePath,
    String? errorMessage,
    DateTime? lastCheckedAt,
  }) {
    return UpdateState(
      stage: stage ?? this.stage,
      latestRelease: latestRelease ?? this.latestRelease,
      matchingAsset: matchingAsset ?? this.matchingAsset,
      installMethod: installMethod ?? this.installMethod,
      currentVersion: currentVersion ?? this.currentVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}
