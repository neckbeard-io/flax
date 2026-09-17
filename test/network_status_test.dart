import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/services/platform/network_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NetworkStatus model tests', () {
    test('maps cellular primary correctly from native map', () {
      final status = NetworkStatus.fromMap({
        'primaryTransport': 'cellular',
        'isWifiPrimary': false,
        'isCellularPrimary': true,
        'isEthernetPrimary': false,
        'isWifiConnected': true, // Car Wi-Fi is connected in background
        'isWifiValidated': false, // Car Wi-Fi has no internet
      });

      expect(status.primaryTransport, ConnectivityResult.mobile);
      expect(status.isCellularPrimary, isTrue);
      expect(status.isWifiPrimary, isFalse);
      expect(status.isWifiConnected, isTrue);
      expect(status.isWifiValidated, isFalse);

      final list = status.toConnectivityList();
      expect(list, [ConnectivityResult.mobile]);
      expect(list.contains(ConnectivityResult.wifi), isFalse);
      expect(list.contains(ConnectivityResult.mobile), isTrue);
    });

    test('maps wifi primary correctly from native map', () {
      final status = NetworkStatus.fromMap({
        'primaryTransport': 'wifi',
        'isWifiPrimary': true,
        'isCellularPrimary': false,
        'isEthernetPrimary': false,
        'isWifiConnected': true,
        'isWifiValidated': true,
      });

      expect(status.primaryTransport, ConnectivityResult.wifi);
      expect(status.isWifiPrimary, isTrue);
      expect(status.isCellularPrimary, isFalse);
      expect(status.isWifiValidated, isTrue);

      final list = status.toConnectivityList();
      expect(list, [ConnectivityResult.wifi]);
      expect(list.contains(ConnectivityResult.wifi), isTrue);
      expect(list.contains(ConnectivityResult.mobile), isFalse);
    });

    test('maps ethernet correctly', () {
      final status = NetworkStatus.fromMap({
        'primaryTransport': 'ethernet',
        'isWifiPrimary': false,
        'isCellularPrimary': false,
        'isEthernetPrimary': true,
      });

      expect(status.primaryTransport, ConnectivityResult.ethernet);
      expect(status.isEthernetPrimary, isTrue);
      expect(status.toConnectivityList(), [ConnectivityResult.ethernet]);
    });

    test('maps none correctly', () {
      final status = NetworkStatus.fromMap({
        'primaryTransport': 'none',
        'isWifiPrimary': false,
        'isCellularPrimary': false,
      });

      expect(status.primaryTransport, ConnectivityResult.none);
      expect(status.toConnectivityList(), [ConnectivityResult.none]);
    });

    test('fromConnectivityList handles desktop fallbacks', () {
      final wifiStatus = NetworkStatus.fromConnectivityList([
        ConnectivityResult.wifi,
      ]);
      expect(wifiStatus.primaryTransport, ConnectivityResult.wifi);
      expect(wifiStatus.isWifiPrimary, isTrue);

      final mobileStatus = NetworkStatus.fromConnectivityList([
        ConnectivityResult.mobile,
      ]);
      expect(mobileStatus.primaryTransport, ConnectivityResult.mobile);
      expect(mobileStatus.isCellularPrimary, isTrue);

      final noneStatus = NetworkStatus.fromConnectivityList([
        ConnectivityResult.none,
      ]);
      expect(noneStatus.primaryTransport, ConnectivityResult.none);
      expect(noneStatus.toConnectivityList(), [ConnectivityResult.none]);
    });
  });

  group('Primary network adapter offline integration', () {
    test(
      'wireless Android Auto connection with Cellular active engages cellular offline mode',
      () async {
        // Simulates being in the car: secondary car Wi-Fi connected, but primary internet is 5G Cellular
        final carStatus = NetworkStatus.fromMap({
          'primaryTransport': 'cellular',
          'isWifiPrimary': false,
          'isCellularPrimary': true,
          'isEthernetPrimary': false,
          'isWifiConnected': true, // Car Wi-Fi
          'isWifiValidated': false, // No internet on car Wi-Fi
        });

        final container = ProviderContainer(
          overrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(carStatus.toConnectivityList()),
            ),
            connectivityProvider.overrideWith(
              (ref) => Future.value(carStatus.toConnectivityList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(connectivityStreamProvider.future);

        await container
            .read(offlineOnCellularSettingProvider.notifier)
            .set(true);

        // App correctly detects that primary adapter is Cellular (not fooled by car Wi-Fi)
        expect(container.read(isOfflineModeProvider), isTrue);
        expect(container.read(offlineReasonProvider), OfflineReason.cellular);
      },
    );

    test(
      'home Wi-Fi connection stays online even when offlineOnCellular is enabled',
      () async {
        final homeStatus = NetworkStatus.fromMap({
          'primaryTransport': 'wifi',
          'isWifiPrimary': true,
          'isCellularPrimary': false,
          'isEthernetPrimary': false,
          'isWifiConnected': true,
          'isWifiValidated': true,
        });

        final container = ProviderContainer(
          overrides: [
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(homeStatus.toConnectivityList()),
            ),
            connectivityProvider.overrideWith(
              (ref) => Future.value(homeStatus.toConnectivityList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(connectivityStreamProvider.future);

        await container
            .read(offlineOnCellularSettingProvider.notifier)
            .set(true);

        expect(container.read(isOfflineModeProvider), isFalse);
        expect(container.read(offlineReasonProvider), OfflineReason.none);
      },
    );
  });
}
