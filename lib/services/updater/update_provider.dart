import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_models.dart';
import 'update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final updateNotifierProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
      final service = ref.watch(updateServiceProvider);
      return UpdateNotifier(service);
    });

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service;
  CancelToken? _cancelToken;
  Timer? _autoCheckTimer;

  static const String _prefSkippedVersionKey = 'update_skipped_version';
  static const String _prefAutoCheckKey = 'update_auto_check_enabled';

  UpdateNotifier(this._service) : super(const UpdateState()) {
    _init();
  }

  Future<void> _init() async {
    final version = await _service.getCurrentVersion();
    final method = _service.detectInstallMethod();

    state = state.copyWith(currentVersion: version, installMethod: method);

    final prefs = await SharedPreferences.getInstance();
    final autoCheck = prefs.getBool(_prefAutoCheckKey) ?? true;
    if (autoCheck) {
      checkForUpdates(silent: true);
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        _autoCheckTimer?.cancel();
        _autoCheckTimer = Timer.periodic(const Duration(hours: 4), (_) {
          checkForUpdates(silent: true);
        });
      }
    }
  }

  /// Checks GitHub for new releases.
  Future<void> checkForUpdates({bool silent = false}) async {
    if (state.isChecking || state.isDownloading || state.isInstalling) return;

    // Only switch stage to checking if not a silent background check or if no update is currently visible
    if (!silent || !state.isUpdateAvailable) {
      state = state.copyWith(stage: UpdateStage.checking, errorMessage: null);
    }

    try {
      final latest = await _service.fetchLatestRelease();
      final now = DateTime.now();

      if (latest == null) {
        state = state.copyWith(stage: UpdateStage.upToDate, lastCheckedAt: now);
        return;
      }

      final cmp = UpdateService.compareSemver(
        latest.version,
        state.currentVersion,
      );
      if (cmp > 0) {
        // New version available!
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_prefSkippedVersionKey);

        if (silent && skipped == latest.version) {
          // User asked to skip this version in background checks
          state = state.copyWith(
            stage: UpdateStage.idle,
            latestRelease: latest,
            lastCheckedAt: now,
          );
          return;
        }

        final asset = _service.findMatchingAsset(latest, state.installMethod);

        state = state.copyWith(
          stage: UpdateStage.available,
          latestRelease: latest,
          matchingAsset: asset,
          lastCheckedAt: now,
        );
      } else {
        state = state.copyWith(
          stage: UpdateStage.upToDate,
          latestRelease: latest,
          lastCheckedAt: now,
        );
      }
    } catch (e) {
      state = state.copyWith(
        stage: UpdateStage.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Starts downloading the matched update package and optionally proceeds to installation.
  Future<void> downloadUpdate({bool autoInstall = false}) async {
    final asset = state.matchingAsset;
    if (asset == null) {
      state = state.copyWith(
        stage: UpdateStage.error,
        errorMessage: 'No matching installer found for your platform.',
      );
      return;
    }

    _cancelToken = CancelToken();
    state = state.copyWith(
      stage: UpdateStage.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: asset.sizeBytes,
    );

    try {
      final localPath = await _service.downloadAsset(
        asset,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          final progress = total > 0 ? (received / total) : 0.0;
          state = state.copyWith(
            downloadProgress: progress.clamp(0.0, 1.0),
            downloadedBytes: received,
            totalBytes: total > 0 ? total : asset.sizeBytes,
          );
        },
      );

      state = state.copyWith(
        stage: UpdateStage.readyToInstall,
        localFilePath: localPath,
        downloadProgress: 1.0,
      );

      if (autoInstall) {
        await install();
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(stage: UpdateStage.available);
      } else {
        state = state.copyWith(
          stage: UpdateStage.error,
          errorMessage: 'Download failed: $e',
        );
      }
    } finally {
      _cancelToken = null;
    }
  }

  /// Cancels an active download.
  void cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
    state = state.copyWith(stage: UpdateStage.available);
  }

  /// Launches the native platform installer.
  Future<void> install() async {
    final path = state.localFilePath;
    if (path == null) {
      await downloadUpdate();
      return;
    }

    state = state.copyWith(stage: UpdateStage.installing);

    try {
      await _service.installUpdate(method: state.installMethod, filePath: path);
    } catch (e) {
      state = state.copyWith(
        stage: UpdateStage.error,
        errorMessage: 'Installation failed: $e',
      );
    }
  }

  /// Dismisses the update or marks version as skipped.
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkippedVersionKey, version);
    state = state.copyWith(stage: UpdateStage.idle);
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }
}
