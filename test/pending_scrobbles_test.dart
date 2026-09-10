import 'package:flutter_test/flutter_test.dart';

import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';

void main() {
  late FlaxDatabase db;
  late LibraryDao dao;
  const serverId = 'srv-test';

  setUp(() {
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'inserts and retrieves pending scrobbles in strict FIFO order',
    () async {
      final t1 = DateTime.utc(2026, 9, 1, 10, 0, 0);
      final t2 = DateTime.utc(2026, 9, 1, 10, 5, 0);
      final t3 = DateTime.utc(2026, 9, 1, 10, 10, 0);

      // Insert out of chronological order
      await dao.insertPendingScrobble(serverId, 'song-2', t2);
      await dao.insertPendingScrobble(serverId, 'song-1', t1);
      await dao.insertPendingScrobble(serverId, 'song-3', t3);

      final pending = await dao.getPendingScrobbles(serverId);
      expect(pending.length, 3);
      expect(pending[0].songId, 'song-1');
      expect(pending[1].songId, 'song-2');
      expect(pending[2].songId, 'song-3');
      expect(pending[0].attempts, 0);
    },
  );

  test('increments attempts on failed drain attempt', () async {
    final t = DateTime.utc(2026, 9, 1, 12, 0, 0);
    final id = await dao.insertPendingScrobble(serverId, 'song-1', t);

    await dao.incrementPendingScrobbleAttempts(id);
    await dao.incrementPendingScrobbleAttempts(id);

    final pending = await dao.getPendingScrobbles(serverId);
    expect(pending.length, 1);
    expect(pending.first.attempts, 2);
  });

  test('deletes confirmed pending scrobble', () async {
    final t = DateTime.utc(2026, 9, 1, 12, 0, 0);
    final id = await dao.insertPendingScrobble(serverId, 'song-1', t);

    await dao.deletePendingScrobble(id);

    final pending = await dao.getPendingScrobbles(serverId);
    expect(pending, isEmpty);
  });

  test('prunes poisoned scrobbles after exceeding max attempts', () async {
    final t1 = DateTime.utc(2026, 9, 1, 12, 0, 0);
    final t2 = DateTime.utc(2026, 9, 1, 12, 5, 0);

    final id1 = await dao.insertPendingScrobble(serverId, 'song-bad', t1);
    await dao.insertPendingScrobble(serverId, 'song-good', t2);

    for (int i = 0; i < 5; i++) {
      await dao.incrementPendingScrobbleAttempts(id1);
    }

    final pruned = await dao.pruneFailedPendingScrobbles(maxAttempts: 5);
    expect(pruned, 1);

    final remaining = await dao.getPendingScrobbles(serverId);
    expect(remaining.length, 1);
    expect(remaining.first.songId, 'song-good');
  });

  test('watches pending scrobbles count for active server', () async {
    final t = DateTime.utc(2026, 9, 1, 12, 0, 0);
    expect(await dao.watchPendingScrobblesCount(serverId).first, 0);

    final id = await dao.insertPendingScrobble(serverId, 'song-1', t);
    expect(await dao.watchPendingScrobblesCount(serverId).first, 1);

    await dao.deletePendingScrobble(id);
    expect(await dao.watchPendingScrobblesCount(serverId).first, 0);
  });
}
