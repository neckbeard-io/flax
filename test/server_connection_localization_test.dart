import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/settings/server_connection_screen.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/network/network_target_resolver.dart';

/// Holds [fixed] instead of probing the network.
class _FixedResolver extends NetworkTargetResolver {
  _FixedResolver(super.ref, NetworkTargetState fixed) {
    state = fixed;
  }

  @override
  Future<void> evaluate({bool force = false}) async {}
}

final _server = Server(
  id: 'srv',
  name: 'Heimserver',
  url: 'https://music.example.com',
  username: 'alice',
  tokenHash: 'pw',
  salt: '',
  isActive: true,
  localNetworkConfig: const LocalNetworkConfig(
    enabled: true,
    targetSsids: ['Home_Mesh'],
    localHost: '192.168.1.20',
  ),
);

Widget _german(Widget home, {NetworkTargetState? target}) => ProviderScope(
  overrides: [
    serverListProvider.overrideWith(
      (ref) => ServerListNotifier(initialServers: [_server]),
    ),
    if (target != null)
      networkTargetResolverProvider.overrideWith(
        (ref) => _FixedResolver(ref, target),
      ),
  ],
  child: MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Flax',
      packageName: 'io.neckbeard.flax',
      version: '0.6.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the connection screen is German from top to bottom', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(_german(const ServerConnectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Serververbindung'), findsOneWidget);
    expect(find.text('Zertifikate überprüfen'), findsOneWidget);
    expect(find.text('Lokales Netzwerkziel'), findsOneWidget);

    // German runs longest; every section has to lay out at phone width.
    await tester.scrollUntilVisible(
      find.text('Prüf-Zeitlimit'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ziel-WLANs (SSIDs)'), findsOneWidget);
    expect(find.text('Home_Mesh'), findsOneWidget);
  });

  testWidgets('the probe result is described in German', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      _german(
        const ServerConnectionScreen(),
        target: const NetworkTargetState(
          activeTarget: EndpointTargetType.local,
          effectiveBaseUrl: 'http://192.168.1.20:4533',
          currentSsid: 'Home_Mesh',
          isLocalConfigured: true,
          isLocalReachable: true,
          status: NetworkTargetStatus.connectedLocal,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lokales LAN'), findsOneWidget);
    expect(
      find.text('Direkt über das lokale Netzwerk verbunden (Home_Mesh)'),
      findsOneWidget,
    );
    expect(find.text('Verbundenes WLAN: Home_Mesh'), findsOneWidget);
  });

  testWidgets('Settings describes the servers in German', (tester) async {
    // The narrowest desktop window, which still gets the phone layout. At
    // 390pt the Theme row overflows in every Latin-script language (#153).
    tester.view.physicalSize = const Size(460, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _german(
        const SettingsScreen(),
        target: const NetworkTargetState(
          activeTarget: EndpointTargetType.external,
          effectiveBaseUrl: 'https://music.example.com',
          currentSsid: 'Cafe',
          isLocalConfigured: true,
          isLocalReachable: false,
          status: NetworkTargetStatus.localUnreachableFallback,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server & Verbindung'), findsOneWidget);
    expect(find.text('Lokales Netzwerkziel'), findsOneWidget);
    expect(
      find.text('In „Cafe“ nicht erreichbar · Verbindung über extern'),
      findsOneWidget,
    );
    expect(find.byTooltip('Verbindungseinstellungen'), findsOneWidget);
    expect(find.text('Server hinzufügen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
