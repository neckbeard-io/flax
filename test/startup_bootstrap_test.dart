import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/app/bootstrap.dart';
import 'package:flax/app/screen_recovery.dart';
import 'package:flax/app/router.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/platform/car_connection_service.dart';

/// What has to happen before the first frame, and that none of it can stop the
/// app from starting.
///
/// The bug this guards: main() awaited SystemChrome.setPreferredOrientations
/// before runApp. Android answers that channel only while an Activity is
/// attached, and the engine is started on every process start — so when Android
/// Auto or a media button started flax, main() waited forever and the app sat
/// on its splash screen until it was killed. A try/catch around the call did
/// nothing, because nothing was ever thrown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const quick = Duration(milliseconds: 50);
  Future<void> noCache() async {}

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('finishes when the flutter/platform channel never answers', () async {
    // What Android does with no Activity attached: drops the call, no reply.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) => Completer<Object?>().future,
        );

    final state = await bootstrap(
      initAudioCache: noCache,
    ).timeout(const Duration(seconds: 2));

    expect(state.prefsLoaded, isTrue);
  });

  test('preferences that never load are given up on, not waited for', () async {
    final state = await bootstrap(
      initAudioCache: noCache,
      loadPrefs: () => Completer<SharedPreferences>().future,
      timeout: quick,
    ).timeout(const Duration(seconds: 2));

    expect(state.prefsLoaded, isFalse);
  });

  test(
    'a cache location that never resolves does not hold up the rest',
    () async {
      final state = await bootstrap(
        initAudioCache: () => Completer<void>().future,
        timeout: quick,
      ).timeout(const Duration(seconds: 2));

      expect(state.prefsLoaded, isTrue);
    },
  );

  test('a step that throws is logged, not fatal', () async {
    final state = await bootstrap(
      initAudioCache: () async => throw const FileSystemException('gone'),
    );

    expect(state.prefsLoaded, isTrue);
  });

  test('without preferences nothing is pinned to a default', () async {
    final state = await bootstrap(
      initAudioCache: noCache,
      loadPrefs: () => Completer<SharedPreferences>().future,
      timeout: quick,
    );

    // An empty server list pinned here would open setup as though the saved
    // server had been forgotten; leaving it alone lets it load itself.
    expect(state.overrides, isEmpty);
  });

  test('saved servers and offline settings reach the first frame', () async {
    const server = Server(
      id: 's1',
      name: 'Home',
      url: 'https://music.example.com',
      username: 'me',
      tokenHash: 'secret',
      salt: '',
      isActive: true,
    );
    SharedPreferences.setMockInitialValues({
      ServerListNotifier.storageKey: jsonEncode([server.toJson()]),
      'flax_offline_manual_override': true,
      lastRouteStorageKey: '/artists/abc',
    });

    final state = await bootstrap(initAudioCache: noCache);
    final container = ProviderContainer(overrides: state.overrides);
    addTearDown(container.dispose);

    expect(container.read(serverListProvider).single.id, 's1');
    expect(container.read(offlineManualOverrideProvider), isTrue);
    expect(container.read(savedRouteProvider), '/artists/abc');
  });

  test('an unusable saved route is dropped', () async {
    SharedPreferences.setMockInitialValues({lastRouteStorageKey: '/'});

    final state = await bootstrap(initAudioCache: noCache);

    expect(state.savedRoute, isNull);
  });

  test('after a failed screen the saved route is not reopened', () async {
    SharedPreferences.setMockInitialValues({
      lastRouteStorageKey: '/now-playing',
      kScreenBrokenPrefKey: true,
    });

    final state = await bootstrap(initAudioCache: noCache);

    expect(state.savedRoute, isNull);
    final again = await bootstrap(initAudioCache: noCache);
    expect(again.savedRoute, '/now-playing');
  });

  test('a connected car is known from the very first read', () async {
    // With Android Auto's offline setting on, being offline hangs on this.
    // Unknown at first, the start of every car session ran as if online and
    // went to the server before the real answer flipped it.
    SharedPreferences.setMockInitialValues({
      'flax_offline_on_android_auto': true,
    });

    final state = await bootstrap(
      initAudioCache: noCache,
      queryCarConnected: () async => true,
    );
    final container = ProviderContainer(
      overrides: [
        ...state.overrides,
        platformOfflinePolicyProvider.overrideWithValue(
          const AndroidOfflinePolicy(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isCarConnectedProvider), isTrue);
    expect(container.read(forcedOfflineProvider), isTrue);
  });

  test('a car query that never answers is given up on', () async {
    final state = await bootstrap(
      initAudioCache: noCache,
      queryCarConnected: () => Completer<bool>().future,
      timeout: quick,
    ).timeout(const Duration(seconds: 2));

    expect(state.carConnected, isFalse);
    expect(state.prefsLoaded, isTrue);
  });

  test('nothing before runApp talks to SystemChrome', () {
    // The hang was one awaited line. Phone orientation is locked natively in
    // MainActivity now; keep it out of the startup path for good.
    for (final path in ['lib/main.dart', 'lib/app/bootstrap.dart']) {
      final code = File(path)
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('SystemChrome')), reason: path);
    }
  });
}
