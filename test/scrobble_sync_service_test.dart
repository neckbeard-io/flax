import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/scrobble/scrobble_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class _FakeSubsonicClient implements SubsonicClient {
  final List<({String id, bool submission, DateTime? time})> scrobbles = [];
  bool failNext = false;

  @override
  Future<void> scrobble(
    String id, {
    bool submission = true,
    DateTime? time,
  }) async {
    if (failNext) throw Exception('Network failure');
    scrobbles.add((id: id, submission: submission, time: time));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServerReachabilityNotifier extends StateNotifier<ServerReachability>
    implements ServerReachabilityNotifier {
  _FakeServerReachabilityNotifier(bool isReachable)
    : super(ServerReachability(isReachable: isReachable));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _testServer = Server(
  id: 'srv-1',
  name: 'Test Server',
  url: 'http://localhost:4533',
  username: 'test',
  tokenHash: 'hash',
  salt: 'salt',
  isActive: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FlaxDatabase db;
  late LibraryDao dao;
  late _FakeSubsonicClient fakeClient;

  setUp(() {
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    fakeClient = _FakeSubsonicClient();
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer({
    bool isOffline = false,
    bool isReachable = true,
  }) {
    return ProviderContainer(
      overrides: [
        flaxDatabaseProvider.overrideWithValue(db),
        libraryDaoProvider.overrideWithValue(dao),
        activeServerProvider.overrideWith((ref) => _testServer),
        subsonicClientProvider.overrideWith((ref) => fakeClient),
        isOfflineModeProvider.overrideWithValue(isOffline),
        serverReachabilityProvider.overrideWith(
          (ref) => _FakeServerReachabilityNotifier(isReachable),
        ),
      ],
    );
  }

  test(
    'drainPendingScrobbles drains in strict FIFO sequence and deletes rows',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final service = container.read(scrobbleSyncServiceProvider);

      final t1 = DateTime.utc(2026, 9, 1, 10, 0, 0);
      final t2 = DateTime.utc(2026, 9, 1, 10, 5, 0);

      await dao.insertPendingScrobble(_testServer.id, 'song-1', t1);
      await dao.insertPendingScrobble(_testServer.id, 'song-2', t2);

      final drained = await service.drainPendingScrobbles(
        rateLimit: Duration.zero,
      );
      expect(drained, 2);

      expect(fakeClient.scrobbles.length, 2);
      expect(fakeClient.scrobbles[0].id, 'song-1');
      expect(
        fakeClient.scrobbles[0].time?.millisecondsSinceEpoch,
        t1.millisecondsSinceEpoch,
      );
      expect(fakeClient.scrobbles[1].id, 'song-2');
      expect(
        fakeClient.scrobbles[1].time?.millisecondsSinceEpoch,
        t2.millisecondsSinceEpoch,
      );

      // Database is cleared
      final remaining = await dao.getPendingScrobbles(_testServer.id);
      expect(remaining, isEmpty);
    },
  );

  test('drain stops and increments attempts on network failure', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final service = container.read(scrobbleSyncServiceProvider);

    final t1 = DateTime.utc(2026, 9, 1, 10, 0, 0);
    final t2 = DateTime.utc(2026, 9, 1, 10, 5, 0);

    await dao.insertPendingScrobble(_testServer.id, 'song-1', t1);
    await dao.insertPendingScrobble(_testServer.id, 'song-2', t2);

    fakeClient.failNext = true;

    final drained = await service.drainPendingScrobbles(
      rateLimit: Duration.zero,
    );
    expect(drained, 0);

    final remaining = await dao.getPendingScrobbles(_testServer.id);
    expect(remaining.length, 2);
    expect(remaining.first.attempts, 1);
  });

  test('does not drain when offline or server unreachable', () async {
    final container = createContainer(isOffline: true);
    addTearDown(container.dispose);

    final service = container.read(scrobbleSyncServiceProvider);

    final t = DateTime.utc(2026, 9, 1, 10, 0, 0);
    await dao.insertPendingScrobble(_testServer.id, 'song-1', t);

    final drained = await service.drainPendingScrobbles(
      rateLimit: Duration.zero,
    );
    expect(drained, 0);
    expect(fakeClient.scrobbles, isEmpty);
  });

  test('enqueuePendingScrobble persists to database', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final service = container.read(scrobbleSyncServiceProvider);
    final t = DateTime.utc(2026, 9, 1, 10, 0, 0);

    await service.enqueuePendingScrobble('song-offline', t);

    final pending = await dao.getPendingScrobbles(_testServer.id);
    expect(pending.length, 1);
    expect(pending.first.songId, 'song-offline');
    expect(
      pending.first.listenedAt.millisecondsSinceEpoch,
      t.millisecondsSinceEpoch,
    );
  });
}
