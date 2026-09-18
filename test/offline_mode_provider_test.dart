import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class _FakeSubsonicClient extends Fake implements SubsonicClient {
  final bool shouldSucceed;

  _FakeSubsonicClient({this.shouldSucceed = true});

  @override
  Future<String?> tryPing({Duration? timeout}) async {
    if (shouldSucceed) return null;
    return 'Connection timed out';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineModeProvider tests', () {
    test('default state is online when server is reachable', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.wifi]),
          ),
          connectivityProvider.overrideWith(
            (ref) => Future.value([ConnectivityResult.wifi]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(connectivityStreamProvider.future);

      expect(container.read(isOfflineModeProvider), isFalse);
      expect(container.read(offlineReasonProvider), OfflineReason.none);
    });

    test(
      'no network connection triggers offline mode and noNetwork reason',
      () async {
        final container = ProviderContainer(
          overrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value([ConnectivityResult.none]),
            ),
            connectivityProvider.overrideWith(
              (ref) => Future.value([ConnectivityResult.none]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(connectivityStreamProvider.future);

        expect(container.read(isOfflineModeProvider), isTrue);
        expect(container.read(offlineReasonProvider), OfflineReason.noNetwork);
      },
    );

    test(
      'empty connectivity results triggers offline mode and noNetwork reason',
      () async {
        final container = ProviderContainer(
          overrides: [
            connectivityStreamProvider.overrideWith((ref) => Stream.value([])),
            connectivityProvider.overrideWith((ref) => Future.value([])),
          ],
        );
        addTearDown(container.dispose);
        await container.read(connectivityStreamProvider.future);

        expect(container.read(isOfflineModeProvider), isTrue);
        expect(container.read(offlineReasonProvider), OfflineReason.noNetwork);
      },
    );

    test('manual override enters offline mode', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isOfflineModeProvider), isFalse);

      await container.read(offlineManualOverrideProvider.notifier).set(true);

      expect(container.read(isOfflineModeProvider), isTrue);
      expect(container.read(offlineReasonProvider), OfflineReason.manual);

      await container.read(offlineManualOverrideProvider.notifier).set(false);

      expect(container.read(isOfflineModeProvider), isFalse);
      expect(container.read(offlineReasonProvider), OfflineReason.none);
    });

    test(
      'offline on cellular setting triggers offline when on mobile data',
      () async {
        final container = ProviderContainer(
          overrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value([ConnectivityResult.mobile]),
            ),
            connectivityProvider.overrideWith(
              (ref) => Future.value([ConnectivityResult.mobile]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(connectivityStreamProvider.future);

        // Default setting is off -> online even on cellular
        expect(container.read(isOfflineModeProvider), isFalse);

        // Enable offline on cellular setting
        await container
            .read(offlineOnCellularSettingProvider.notifier)
            .set(true);

        expect(container.read(isOfflineModeProvider), isTrue);
        expect(container.read(offlineReasonProvider), OfflineReason.cellular);
      },
    );

    test(
      'server reachability probe failure triggers offline mode and toast',
      () async {
        final fakeClient = _FakeSubsonicClient(shouldSucceed: false);
        const server = Server(
          id: 'srv-1',
          name: 'Test Server',
          url: 'http://localhost:4533',
          username: 'admin',
          tokenHash: 'secret',
          salt: 'salt123',
        );

        final container = ProviderContainer(
          overrides: [
            activeServerProvider.overrideWithValue(server),
            subsonicClientProvider.overrideWithValue(fakeClient),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(isOfflineModeProvider), isFalse);
        expect(container.read(offlineToastMessageProvider), isNull);

        final isReachable = await container
            .read(serverReachabilityProvider.notifier)
            .probeServer();

        expect(isReachable, isFalse);
        expect(container.read(isOfflineModeProvider), isTrue);
        expect(
          container.read(offlineReasonProvider),
          OfflineReason.serverUnreachable,
        );
        expect(
          container.read(offlineToastMessageProvider),
          contains('Server unreachable'),
        );
        expect(
          container.read(offlineToastMessageProvider),
          contains('Switched to Offline mode.'),
        );
      },
    );

    test(
      'auto-offline engages when Android Auto is connected and setting enabled',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(isOfflineModeProvider), isFalse);

        // Enable Android Auto setting
        await container
            .read(offlineOnAndroidAutoSettingProvider.notifier)
            .set(true);

        // Still false because car is not connected
        expect(container.read(isOfflineModeProvider), isFalse);

        // Car connects
        container.read(isCarConnectedProvider.notifier).setCarConnected(true);

        expect(container.read(isOfflineModeProvider), isTrue);
        expect(
          container.read(offlineReasonProvider),
          OfflineReason.androidAuto,
        );

        // Car disconnects
        container.read(isCarConnectedProvider.notifier).setCarConnected(false);

        expect(container.read(isOfflineModeProvider), isFalse);
        expect(container.read(offlineReasonProvider), OfflineReason.none);
      },
    );

    test('toaster can be dismissed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(offlineToastMessageProvider.notifier).show('Test message');
      expect(container.read(offlineToastMessageProvider), 'Test message');

      container.read(offlineToastMessageProvider.notifier).dismiss();
      expect(container.read(offlineToastMessageProvider), isNull);
    });

    test(
      'markReachable clears serverUnreachable state and re-enables online mode',
      () {
        const server = Server(
          id: 'srv-1',
          name: 'Test Server',
          url: 'http://localhost:4533',
          username: 'admin',
          tokenHash: 'secret',
          salt: 'salt123',
        );
        final container = ProviderContainer(
          overrides: [activeServerProvider.overrideWithValue(server)],
        );
        addTearDown(container.dispose);

        container
            .read(serverReachabilityProvider.notifier)
            .markUnreachable('Test failure');
        expect(container.read(isOfflineModeProvider), isTrue);
        expect(
          container.read(offlineReasonProvider),
          OfflineReason.serverUnreachable,
        );

        container.read(serverReachabilityProvider.notifier).markReachable();
        expect(container.read(isOfflineModeProvider), isFalse);
        expect(container.read(offlineReasonProvider), OfflineReason.none);
      },
    );

    test('VPN and other connections keep app online', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWith(
            (ref) => Stream.value([ConnectivityResult.other]),
          ),
          connectivityProvider.overrideWith(
            (ref) => Future.value([ConnectivityResult.other]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(connectivityStreamProvider.future);

      expect(container.read(isOfflineModeProvider), isFalse);
      expect(container.read(offlineReasonProvider), OfflineReason.none);
    });
  });
}
