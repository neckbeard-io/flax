import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/scrobble/scrobble_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class _FakeClient implements SubsonicClient {
  _FakeClient(this.server, this.scrobbled, this.pings);

  @override
  final Server server;

  /// Shared by every client the provider builds.
  final List<String> scrobbled;

  /// Reachability probes sent, shared like [scrobbled].
  final List<DateTime> pings;

  @override
  Future<void> scrobble(
    String id, {
    bool submission = true,
    DateTime? time,
  }) async => scrobbled.add(id);

  @override
  Future<String?> tryPing({Duration? timeout}) async {
    pings.add(DateTime.now());
    return null;
  }

  // Asked after a successful probe; the answer does not matter here.
  @override
  Future<SubsonicServerInfo> getServerInfo({Duration? timeout}) =>
      Completer<SubsonicServerInfo>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Servers extends ServerListNotifier {
  _Servers(Server server) {
    state = [server];
  }
}

/// The address the client talks to: switching it is what happens when the app
/// moves to the server's local address on home Wi-Fi.
final _address = StateProvider<String>((ref) => 'http://example.com');

const _server = Server(
  id: 'srv-1',
  name: 'Home',
  url: 'http://localhost:4533',
  username: 'u',
  tokenHash: 't',
  salt: 's',
  isActive: true,
);

/// Riverpod 2 refreshes a stale provider's dependencies one by one, and a
/// dependency that rebuilds notifies its listeners right then. A listener that
/// read isOfflineModeProvider at that point rebuilt it in the middle of the
/// walk over its own dependencies: "Concurrent modification during
/// iteration", thrown from AppChrome's library sync timer on a phone in the
/// background, where no frame runs the scheduled refreshes first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FlaxDatabase db;

  late List<String> scrobbled;
  late List<DateTime> pings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FlaxDatabase.memory();
    scrobbled = [];
    pings = [];
  });

  tearDown(() => db.close());

  /// The real offline mode, reachability and scrobble sync, with everything
  /// that listens in the app already listening. [inCar] starts on Android in
  /// a car with offline-in-the-car on, so offline is forced.
  ProviderContainer start({bool inCar = false}) {
    final container = ProviderContainer(
      overrides: [
        flaxDatabaseProvider.overrideWithValue(db),
        libraryDaoProvider.overrideWithValue(LibraryDao(db)),
        serverListProvider.overrideWith((ref) => _Servers(_server)),
        // Rebuilt with the server and its address, as the real client is.
        subsonicClientProvider.overrideWith((ref) {
          ref.watch(_address);
          return _FakeClient(
            ref.watch(activeServerProvider)!,
            scrobbled,
            pings,
          );
        }),
        if (inCar) ...[
          platformOfflinePolicyProvider.overrideWithValue(
            const AndroidOfflinePolicy(),
          ),
          offlineOnAndroidAutoSettingProvider.overrideWith(
            (ref) => OfflineOnAndroidAutoNotifier(initialValue: true),
          ),
        ],
        connectivityStreamProvider.overrideWith(
          (ref) => Stream.value([ConnectivityResult.wifi]),
        ),
        connectivityProvider.overrideWith(
          (ref) async => [ConnectivityResult.wifi],
        ),
        isCarConnectedProvider.overrideWith(
          (ref) => CarConnectionNotifier(inCar),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(scrobbleSyncServiceProvider);
    container.read(serverReachabilityProvider);
    return container;
  }

  test(
    'reading offline mode after a server change does not re-enter it',
    () async {
      final container = start();
      expect(container.read(isOfflineModeProvider), isFalse);

      // Any save of the server list, then a read before the scheduled refresh,
      // which is what a timer does while no frames are drawn.
      final saved = container
          .read(serverListProvider.notifier)
          .updateServer(_server.copyWith(name: 'Home (renamed)'));

      expect(() => container.read(isOfflineModeProvider), returnsNormally);
      await saved;
    },
  );

  test('a server change still sends pending plays, after it settles', () async {
    await LibraryDao(
      db,
    ).insertPendingScrobble(_server.id, 'song-1', DateTime.utc(2026, 10, 6));
    final container = start();
    container.read(isOfflineModeProvider);

    final saved = container
        .read(serverListProvider.notifier)
        .updateServer(_server.copyWith(name: 'Home (renamed)'));
    expect(scrobbled, isEmpty, reason: 'nothing is sent mid-notification');

    await saved;
    for (var i = 0; i < 100 && scrobbled.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(scrobbled, ['song-1']);
  });
  // Reachability probes as soon as forced offline lifts. Probing marks it
  // probing before the first await, and done from the listener that changed
  // reachability while offline mode, which watches it, was mid-rebuild.
  test('a car disconnecting does not re-enter offline mode', () async {
    final container = start(inCar: true);
    expect(container.read(isOfflineModeProvider), isTrue);

    container.read(isCarConnectedProvider.notifier).setCarConnected(false);
    expect(() => container.read(isOfflineModeProvider), returnsNormally);

    await Future<void>.delayed(Duration.zero);
    expect(pings, hasLength(1), reason: 'the probe still runs, just after');
    expect(container.read(isOfflineModeProvider), isFalse);
  });

  test('a new server address probes after offline mode settles', () async {
    final container = start();
    container.read(isOfflineModeProvider);
    await Future<void>.delayed(Duration.zero);
    pings.clear();

    var changes = 0;
    container.listen(serverReachabilityProvider, (_, _) => changes++);

    // Moving to the local address, then a read before the scheduled refresh:
    // AppChrome's timer, in the background.
    container.read(_address.notifier).state = 'http://192.168.2.160:4533';
    container.read(isOfflineModeProvider);
    expect(changes, 0, reason: 'reachability did not move mid-refresh');
    expect(pings, isEmpty);

    await Future<void>.delayed(Duration.zero);
    expect(pings, hasLength(1));
    expect(changes, greaterThan(0));
  });
}
