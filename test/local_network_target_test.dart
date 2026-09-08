import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/settings/server_connection_screen.dart';
import 'package:flax/services/network/network_target_resolver.dart';

class MockNetworkInfo implements NetworkInfo {
  final String? wifiName;
  MockNetworkInfo({this.wifiName});

  @override
  Future<String?> getWifiName() async => wifiName;

  @override
  Future<String?> getWifiBSSID() async => null;

  @override
  Future<String?> getWifiIP() async => null;

  @override
  Future<String?> getWifiIPv6() async => null;

  @override
  Future<String?> getWifiSubmask() async => null;

  @override
  Future<String?> getWifiBroadcast() async => null;

  @override
  Future<String?> getWifiGatewayIP() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalNetworkConfig Model', () {
    test('default values', () {
      const config = LocalNetworkConfig();
      expect(config.enabled, isFalse);
      expect(config.targetSsids, isEmpty);
      expect(config.localHost, '');
      expect(config.localPort, 4533);
      expect(config.useHttps, isFalse);
      expect(config.trustSelfSignedCerts, isFalse);
      expect(config.fallbackToExternal, isTrue);
      expect(config.probeTimeoutMs, 1500);
      expect(config.localBaseUrl, isNull);
    });

    test('localBaseUrl resolution', () {
      // Basic HTTP
      const c1 = LocalNetworkConfig(
        enabled: true,
        localHost: '192.168.1.100',
        localPort: 4533,
      );
      expect(c1.localBaseUrl, 'http://192.168.1.100:4533');

      // HTTPS
      const c2 = LocalNetworkConfig(
        enabled: true,
        localHost: 'homelab.local',
        localPort: 8443,
        useHttps: true,
      );
      expect(c2.localBaseUrl, 'https://homelab.local:8443');

      // Host string containing port
      const c3 = LocalNetworkConfig(
        enabled: true,
        localHost: '192.168.1.50:9000',
        localPort: 4533,
      );
      expect(c3.localBaseUrl, 'http://192.168.1.50:9000');

      // Host string containing scheme and trailing slash
      const c4 = LocalNetworkConfig(
        enabled: true,
        localHost: 'http://192.168.1.50:4533/',
        useHttps: false,
      );
      expect(c4.localBaseUrl, 'http://192.168.1.50:4533');

      // Empty host
      const c5 = LocalNetworkConfig(enabled: true, localHost: '   ');
      expect(c5.localBaseUrl, isNull);
    });

    test('JSON serialization roundtrip', () {
      const original = LocalNetworkConfig(
        enabled: true,
        targetSsids: ['Home_WiFi', 'Home_5G'],
        localHost: '192.168.1.120',
        localPort: 4040,
        useHttps: true,
        trustSelfSignedCerts: true,
        fallbackToExternal: false,
        probeTimeoutMs: 2500,
      );

      final json = original.toJson();
      final restored = LocalNetworkConfig.fromJson(json);

      expect(restored.enabled, isTrue);
      expect(restored.targetSsids, ['Home_WiFi', 'Home_5G']);
      expect(restored.localHost, '192.168.1.120');
      expect(restored.localPort, 4040);
      expect(restored.useHttps, isTrue);
      expect(restored.trustSelfSignedCerts, isTrue);
      expect(restored.fallbackToExternal, isFalse);
      expect(restored.probeTimeoutMs, 2500);
      expect(restored.localBaseUrl, 'https://192.168.1.120:4040');
    });

    test('Server model serialization includes LocalNetworkConfig', () {
      final server = Server(
        id: 'srv-1',
        name: 'Home Server',
        url: 'https://music.remote.com',
        username: 'alice',
        tokenHash: 'pw',
        salt: 'salt',
        localNetworkConfig: const LocalNetworkConfig(
          enabled: true,
          targetSsids: ['MyHomeWifi'],
          localHost: '192.168.1.200',
          localPort: 4533,
        ),
      );

      final json = server.toJson();
      final restored = Server.fromJson(json);

      expect(restored.localNetworkConfig.enabled, isTrue);
      expect(restored.localNetworkConfig.targetSsids, ['MyHomeWifi']);
      expect(restored.localNetworkConfig.localHost, '192.168.1.200');
      expect(
        restored.localNetworkConfig.localBaseUrl,
        'http://192.168.1.200:4533',
      );
    });
  });

  group('NetworkTargetResolver', () {
    test('sanitizes Wi-Fi SSIDs correctly', () async {
      final container = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(
            MockNetworkInfo(wifiName: '"MyHomeNetwork"'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final resolver = container.read(networkTargetResolverProvider.notifier);
      final ssid = await resolver.getCurrentSsid();
      expect(ssid, 'MyHomeNetwork');

      final unknownContainer = ProviderContainer(
        overrides: [
          networkInfoProvider.overrideWithValue(
            MockNetworkInfo(wifiName: '<unknown ssid>'),
          ),
        ],
      );
      addTearDown(unknownContainer.dispose);

      final unknownResolver = unknownContainer.read(
        networkTargetResolverProvider.notifier,
      );
      expect(await unknownResolver.getCurrentSsid(), isNull);
    });
  });

  group('ServerConnectionScreen Widgets', () {
    testWidgets(
      'Screen renders and adapts on mobile phone dimensions without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final testServer = Server(
          id: 'test-srv',
          name: 'Homelab Navidrome',
          url: 'https://music.example.com',
          username: 'admin',
          tokenHash: 'token',
          salt: 's',
          isActive: true,
          localNetworkConfig: const LocalNetworkConfig(
            enabled: true,
            targetSsids: ['Home_Mesh', 'Home_IoT'],
            localHost: '192.168.1.150',
            localPort: 4533,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              serverListProvider.overrideWith(
                (ref) => ServerListNotifier(initialServers: [testServer]),
              ),
            ],
            child: const MaterialApp(home: ServerConnectionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Screen title and elements render properly
        expect(find.text('Server Connection'), findsOneWidget);
        expect(find.text('Homelab Navidrome'), findsOneWidget);
        expect(find.text('Local Network Target'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Home_Mesh'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Home_Mesh'), findsOneWidget);
        expect(find.text('Home_IoT'), findsOneWidget);

        // Verify no overflow by asserting all buttons & inputs render within bounds
        final titleFinder = find.text('Server Connection');
        expect(titleFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Toggling enabled switch and adding manual SSID updates state',
      (tester) async {
        final testServer = Server(
          id: 'test-srv-2',
          name: 'Test Server',
          url: 'https://remote.music.io',
          username: 'user',
          tokenHash: 'pw',
          salt: 's',
          isActive: true,
          localNetworkConfig: const LocalNetworkConfig(
            enabled: false,
            targetSsids: [],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              serverListProvider.overrideWith(
                (ref) => ServerListNotifier(initialServers: [testServer]),
              ),
            ],
            child: const MaterialApp(home: ServerConnectionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Initially disabled
        expect(find.text('Enable Local LAN Endpoint'), findsOneWidget);
        expect(find.text('Local Endpoint Settings'), findsNothing);

        // Tap enable switch
        final switchFinder = find.widgetWithText(
          SwitchListTile,
          'Enable Local LAN Endpoint',
        );
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Now settings are revealed
        expect(find.text('Local Endpoint Settings'), findsOneWidget);
        expect(find.text('Local IP / Hostname'), findsOneWidget);

        // Scroll to manual SSID input field
        final ssidField = find.widgetWithText(
          TextField,
          'Add Wi-Fi SSID manually',
        );
        await tester.scrollUntilVisible(
          ssidField,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(ssidField, findsOneWidget);
        await tester.enterText(ssidField, 'OfficeWiFi_5G');
        await tester.tap(find.byTooltip('Add SSID'));
        await tester.pumpAndSettle();

        expect(find.text('OfficeWiFi_5G'), findsOneWidget);
      },
    );
  });
}
