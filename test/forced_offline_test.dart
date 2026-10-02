import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

const _server = Server(
  id: 'srv',
  name: 'Home',
  url: 'https://music.example.com',
  username: 'me',
  tokenHash: 'secret',
  salt: '',
  isActive: true,
);

/// Counts pings, and always reports the server as down so a probe never goes
/// on to anything else.
class CountingClient extends SubsonicClient {
  CountingClient() : super(server: _server);

  int pings = 0;

  @override
  Future<String?> tryPing({Duration? timeout}) async {
    pings++;
    return 'unreachable';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor({
    required PlatformOfflinePolicy policy,
    required CountingClient client,
    bool manual = false,
    bool autoOfflineInCar = false,
    bool carConnected = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        platformOfflinePolicyProvider.overrideWithValue(policy),
        subsonicClientProvider.overrideWithValue(client),
        connectivityStreamProvider.overrideWith(
          (ref) => Stream.value([ConnectivityResult.wifi]),
        ),
        connectivityProvider.overrideWith(
          (ref) async => [ConnectivityResult.wifi],
        ),
        offlineManualOverrideProvider.overrideWith(
          (ref) => OfflineManualNotifier(initialValue: manual),
        ),
        offlineOnAndroidAutoSettingProvider.overrideWith(
          (ref) => OfflineOnAndroidAutoNotifier(initialValue: autoOfflineInCar),
        ),
        carConnectionServiceProvider.overrideWith((ref) {
          final service = CarConnectionService(
            initiallyConnected: carConnected,
          );
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('forced offline', () {
    test('the manual toggle forces it', () {
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: CountingClient(),
        manual: true,
      );
      expect(c.read(forcedOfflineProvider), isTrue);
    });

    test('Android Auto with the setting forces it, from the first read', () {
      // The car state is seeded at startup; with it unknown the first moments
      // of a car start used to run as if online.
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: CountingClient(),
        autoOfflineInCar: true,
        carConnected: true,
      );
      expect(c.read(forcedOfflineProvider), isTrue);
      expect(c.read(isOfflineModeProvider), isTrue);
    });

    test('the setting alone, with no car, does not', () {
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: CountingClient(),
        autoOfflineInCar: true,
      );
      expect(c.read(forcedOfflineProvider), isFalse);
    });

    test('never on desktop, where there is no car to connect', () {
      final c = containerFor(
        policy: const MacOsOfflinePolicy(),
        client: CountingClient(),
        autoOfflineInCar: true,
        carConnected: true,
      );
      expect(c.read(forcedOfflineProvider), isFalse);
    });
  });

  group('reachability while offline is forced', () {
    test('a probe does not reach the server', () async {
      final client = CountingClient();
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: client,
        autoOfflineInCar: true,
        carConnected: true,
      );

      await c.read(serverReachabilityProvider.notifier).probeServer();

      expect(client.pings, 0);
    });

    test('without it, a probe still asks the server', () async {
      final client = CountingClient();
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: client,
      );

      await c.read(serverReachabilityProvider.notifier).probeServer();

      expect(client.pings, 1);
    });

    test('lifting it checks the server again', () async {
      final client = CountingClient();
      final c = containerFor(
        policy: const AndroidOfflinePolicy(),
        client: client,
        manual: true,
      );
      c.read(serverReachabilityProvider);

      await c.read(offlineManualOverrideProvider.notifier).set(false);
      await pumpEventQueue();

      expect(client.pings, 1);
    });
  });

  test('cover art URLs are the same on every call', () {
    // They are cache keys. A fresh salt per call made every one unique, so
    // nothing — Android Auto included — could ever find a cover in cache.
    final client = SubsonicClient(server: _server);
    expect(
      client.getCoverArtUri('al-1', size: 512),
      client.getCoverArtUri('al-1', size: 512),
    );
    expect(
      client.getCoverArtUri('al-1', size: 512),
      isNot(client.getCoverArtUri('al-1', size: 256)),
    );
  });
}
