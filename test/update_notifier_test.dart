import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/services/updater/update_service.dart';

/// Answers the releases request with one newer stable release, or fails the
/// way an unreachable GitHub does, depending on [reachable].
class _GitHub {
  bool reachable = true;

  Dio dio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!reachable) {
            handler.reject(
              DioException.connectionTimeout(
                timeout: const Duration(seconds: 15),
                requestOptions: options,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: [
                {
                  'tag_name': 'v0.6.0',
                  'name': 'flax v0.6.0',
                  'body': '### Fixed\n- Something.\n\n---\nInstall notes.',
                  'html_url':
                      'https://github.com/neckbeard-io/flax/releases/tag/v0.6.0',
                  'published_at': '2026-10-06T05:40:00Z',
                  'prerelease': false,
                  'assets': [],
                },
              ],
            ),
          );
        },
      ),
    );
    return dio;
  }
}

/// A release with an APK, whose checks and downloads each wait until the test
/// answers them.
class _SlowService extends UpdateService {
  final checks = <Completer<ReleaseInfo?>>[];
  final downloads = <({Completer<String> done, CancelToken? token})>[];
  final progress = <void Function(int, int)>[];
  int installs = 0;

  static final release = ReleaseInfo(
    tagName: 'v0.6.0',
    version: '0.6.0',
    title: 'flax v0.6.0',
    body: '',
    htmlUrl: '',
    publishedAt: DateTime(2026, 10, 6),
    isPrerelease: false,
    assets: const [
      ReleaseAsset(
        id: 1,
        name: 'flax-0.6.0-android-universal.apk',
        downloadUrl: 'https://example.invalid/flax.apk',
        sizeBytes: 1000,
        contentType: 'application/vnd.android.package-archive',
      ),
    ],
  );

  @override
  InstallMethod detectInstallMethod() => InstallMethod.androidApk;

  @override
  Future<ReleaseInfo?> fetchLatestRelease({
    UpdateChannel channel = UpdateChannel.stable,
    String? currentVersion,
  }) {
    final check = Completer<ReleaseInfo?>();
    checks.add(check);
    return check.future;
  }

  @override
  Future<String> downloadAsset(
    ReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) {
    final done = Completer<String>();
    downloads.add((done: done, token: cancelToken));
    progress.add(onProgress);
    return done.future;
  }

  @override
  Future<void> installUpdate({
    required InstallMethod method,
    required String filePath,
  }) async {
    installs++;
  }
}

void main() {
  late _GitHub github;
  late UpdateNotifier notifier;

  setUp(() async {
    // No check on startup, so each test drives the checks itself.
    SharedPreferences.setMockInitialValues({
      'update_auto_check_enabled': false,
    });
    PackageInfo.setMockInitialValues(
      appName: 'Flax',
      packageName: 'io.neckbeard.flax',
      version: '0.5.6',
      buildNumber: '1',
      buildSignature: '',
    );
    github = _GitHub();
    notifier = UpdateNotifier(UpdateService(dio: github.dio()));
    await pumpEventQueue();
  });

  tearDown(() => notifier.dispose());

  test('a successful check clears the error a failed one left', () async {
    github.reachable = false;
    await notifier.checkForUpdates();
    expect(notifier.state.stage, UpdateStage.error);
    expect(notifier.state.errorMessage, isNotNull);

    github.reachable = true;
    await notifier.checkForUpdates();
    expect(notifier.state.stage, UpdateStage.available);
    expect(notifier.state.latestRelease?.version, '0.6.0');
    expect(notifier.state.errorMessage, isNull);
  });

  test(
    'a failed check explains itself instead of dumping the exception',
    () async {
      github.reachable = false;
      await notifier.checkForUpdates();
      expect(
        notifier.state.errorMessage,
        "Couldn't reach GitHub. Check your connection and try again.",
      );
    },
  );

  test('a failed background check keeps an update already offered', () async {
    await notifier.checkForUpdates();
    expect(notifier.state.stage, UpdateStage.available);

    github.reachable = false;
    await notifier.checkForUpdates(silent: true);
    expect(notifier.state.stage, UpdateStage.available);
    expect(notifier.state.isUpdateAvailable, isTrue);
    expect(notifier.state.errorMessage, isNull);
  });

  test('a failed background check reports nothing', () async {
    final stageBefore = notifier.state.stage;

    github.reachable = false;
    await notifier.checkForUpdates(silent: true);
    expect(notifier.state.stage, stageBefore);
    expect(notifier.state.errorMessage, isNull);
  });

  test(
    'a failed background check keeps the error a manual check showed',
    () async {
      github.reachable = false;
      await notifier.checkForUpdates();
      final shown = notifier.state.errorMessage;

      await notifier.checkForUpdates(silent: true);
      expect(notifier.state.stage, UpdateStage.error);
      expect(notifier.state.errorMessage, shown);
    },
  );

  group('one download at a time', () {
    late _SlowService service;
    late UpdateNotifier slow;

    setUp(() async {
      service = _SlowService();
      slow = UpdateNotifier(service);
      await pumpEventQueue();
      final first = slow.checkForUpdates();
      service.checks.single.complete(_SlowService.release);
      await first;
      expect(slow.state.stage, UpdateStage.available);
    });

    tearDown(() => slow.dispose());

    test('a check that returns mid-download keeps showing it', () async {
      // The check flax makes on coming back to the foreground, still waiting
      // on GitHub when Update is tapped.
      final check = slow.checkForUpdates(silent: true);
      unawaited(slow.downloadUpdate(autoInstall: true));
      expect(slow.state.stage, UpdateStage.downloading);

      service.checks.last.complete(_SlowService.release);
      await check;
      expect(slow.state.stage, UpdateStage.downloading);
    });

    test('a failed check that returns mid-download keeps showing it', () async {
      final check = slow.checkForUpdates(silent: true);
      unawaited(slow.downloadUpdate(autoInstall: true));

      service.checks.last.completeError(
        DioException.connectionError(
          requestOptions: RequestOptions(path: UpdateService.releasesUrl),
          reason: 'offline',
        ),
      );
      await check;
      expect(slow.state.stage, UpdateStage.downloading);
    });

    test('tapping Update again while downloading starts nothing', () async {
      final download = slow.downloadUpdate(autoInstall: true);
      await slow.downloadUpdate(autoInstall: true);
      expect(service.downloads, hasLength(1));

      service.downloads.single.done.complete('/tmp/flax.apk');
      await download;
      expect(service.installs, 1);
    });

    test('a cancelled download cannot disturb the one after it', () async {
      unawaited(slow.downloadUpdate());
      slow.cancelDownload();
      final second = slow.downloadUpdate(autoInstall: true);
      expect(service.downloads, hasLength(2));

      // A finished report, which the progress throttle always lets through.
      service.progress.first(1000, 1000);
      service.downloads.first.done.completeError(
        DioException.requestCancelled(
          requestOptions: RequestOptions(path: ''),
          reason: 'Cancelled by user',
        ),
      );
      await pumpEventQueue();
      expect(slow.state.stage, UpdateStage.downloading);
      expect(slow.state.downloadedBytes, 0);

      service.downloads.last.done.complete('/tmp/flax.apk');
      await second;
      expect(service.installs, 1);
    });
  });

  group('describeFailure', () {
    final request = RequestOptions(path: UpdateService.releasesUrl);

    test('names a network failure without the exception text', () {
      for (final error in [
        DioException.connectionTimeout(
          timeout: Duration.zero,
          requestOptions: request,
        ),
        DioException.connectionError(
          requestOptions: request,
          reason: 'Operation timed out',
        ),
      ]) {
        expect(
          UpdateService.describeFailure(error),
          "Couldn't reach GitHub. Check your connection and try again.",
        );
      }
    });

    test('names a rate limit', () {
      final error = DioException.badResponse(
        statusCode: 403,
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 403),
      );
      expect(
        UpdateService.describeFailure(error),
        'GitHub is limiting update checks right now. Try again later.',
      );
    });

    test('passes other errors through', () {
      expect(
        UpdateService.describeFailure(const FormatException('bad json')),
        'FormatException: bad json',
      );
    });
  });
}
