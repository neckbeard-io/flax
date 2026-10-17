import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/network/network_target_resolver.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// A network whose SSID read never answers, or answers nothing.
class _NetworkInfo implements NetworkInfo {
  _NetworkInfo({this.hang = false});
  final bool hang;

  @override
  Future<String?> getWifiName() =>
      hang ? Completer<String?>().future : Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<String?>.value();
}

/// Launch used to send its first requests to the remote address before the
/// local one was chosen, and work started then stayed there (#170).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer local;
  var localRequests = 0;

  setUpAll(() async {
    // The test binding answers every HTTP request with a 400; these talk to a
    // real loopback server.
    HttpOverrides.global = null;
    local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    local.listen((request) {
      localRequests++;
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
          }),
        )
        ..close();
    });
  });

  tearDownAll(() => local.close(force: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    localRequests = 0;
  });

  Server server({String host = '127.0.0.1', int? port, int probeMs = 1500}) =>
      Server(
        id: 'srv-1',
        name: 'Home',
        url: 'http://127.0.0.1:1',
        username: 'user',
        tokenHash: 'token',
        salt: 'salt',
        isActive: true,
        localNetworkConfig: LocalNetworkConfig(
          enabled: true,
          localHost: host,
          localPort: port ?? local.port,
          probeTimeoutMs: probeMs,
        ),
      );

  ProviderContainer containerFor(
    List<Server> servers, {
    List<ConnectivityResult> network = const [ConnectivityResult.ethernet],
    NetworkInfo? info,
  }) {
    final container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith((ref) async => network),
        networkInfoProvider.overrideWithValue(info ?? _NetworkInfo()),
        serverListProvider.overrideWith(
          (ref) => ServerListNotifier(initialServers: servers),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('firstEvaluation', () {
    test('completes once the local address has been chosen', () async {
      final container = containerFor([server()]);
      final resolver = container.read(networkTargetResolverProvider.notifier);

      await resolver.firstEvaluation;

      final state = container.read(networkTargetResolverProvider);
      expect(state.activeTarget, EndpointTargetType.local);
      expect(state.serverId, 'srv-1');
      expect(
        resolver.chosenBaseUrlFor('srv-1'),
        'http://127.0.0.1:${local.port}',
      );
      expect(resolver.chosenBaseUrlFor('srv-2'), isNull);
    });

    test('gives up after its bound, starting on the remote address', () async {
      // Wi-Fi whose SSID never comes back, and a 200ms probe: the bound is
      // 700ms, well under the 2.5s cap.
      final container = containerFor(
        [server(probeMs: 200)],
        network: const [ConnectivityResult.wifi],
        info: _NetworkInfo(hang: true),
      );
      final resolver = container.read(networkTargetResolverProvider.notifier);

      final clock = Stopwatch()..start();
      await resolver.firstEvaluation;

      expect(clock.elapsedMilliseconds, lessThan(2000));
      expect(
        container.read(networkTargetResolverProvider).effectiveBaseUrl,
        'http://127.0.0.1:1',
      );
    });

    test('completes at once with no server', () async {
      final container = containerFor(const []);
      await container
          .read(networkTargetResolverProvider.notifier)
          .firstEvaluation
          .timeout(const Duration(milliseconds: 100));
    });
  });

  group('the client', () {
    test('waits for the decision, then sends to the chosen address', () async {
      final chosen = Completer<void>();
      final client = SubsonicClient(
        server: server(),
        // Where a client built before the switch points: nothing listens.
        customBaseUrl: 'http://127.0.0.1:1',
        targetChosen: () => chosen.future,
        currentBaseUrl: () => 'http://127.0.0.1:${local.port}',
      );

      final ping = client.ping();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(localRequests, 0, reason: 'nothing is sent before the decision');

      chosen.complete();
      expect(await ping, isTrue);
      expect(localRequests, 1);
    });

    test(
      'the provider client of a launch sync reaches the local address',
      () async {
        final container = containerFor([server()]);
        // Read at once, as AppChrome's launch sync does, before any decision.
        final client = container.read(subsonicClientProvider)!;

        // The remote address refuses connections, so a ping that answers went
        // to the local one.
        expect(await client.ping(), isTrue);
      },
    );
  });
}
