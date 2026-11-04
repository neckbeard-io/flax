import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';

class _Backend implements MusicBackend {
  _Backend(this.playlist, this.songs);

  Playlist playlist;
  List<Song> songs;
  int fetches = 0;

  @override
  Future<Playlist> getPlaylist(String id) async {
    fetches++;
    return playlist;
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async => songs;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Finishes the first track it's given, then cancels the job, as someone
/// pressing cancel partway through does.
class _CancelsAfterFirst extends AudioCacheService {
  _CancelsAfterFirst(this.ref, this.db) : super(ref);

  final Ref ref;
  final FlaxDatabase db;
  var _calls = 0;

  @override
  Future<String?> cacheSong(
    Song song, {
    bool isPinned = true,
    TaskHandle? parentHandle,
    CancelToken? cancelToken,
    void Function(int bytesDownloaded)? onProgressDelta,
  }) async {
    if (_calls++ > 0) return null;
    await (db.update(db.songs)..where((t) => t.id.equals(song.id))).write(
      SongsCompanion(
        localPath: const Value('/music/track'),
        downloadState: Value(DownloadState.complete.index),
      ),
    );
    cancelToken?.cancel();
    return '/music/track';
  }
}

/// With no client, `cacheSong` stops at once, so these run the path up to the
/// download itself: what gets queued, under which task.
void main() {
  const sid = 'srv';
  late FlaxDatabase db;
  late LibraryDao dao;
  late _Backend backend;
  late ProviderContainer container;

  const playlist = Playlist(
    id: 'p',
    serverId: sid,
    name: 'Road trip',
    songCount: 3,
  );

  Song song(String id) =>
      Song(id: id, serverId: sid, albumId: 'al', title: 'Song $id');

  Future<Map<String, int>> states() async => {
    for (final row in await db.select(db.songs).get())
      row.id: row.downloadState,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    backend = _Backend(playlist, [song('s1'), song('s2'), song('s1')]);
    final repo = LibraryRepositoryImpl(dao, backend, sid);
    container = ProviderContainer(
      overrides: [
        libraryDaoProvider.overrideWithValue(dao),
        libraryRepositoryProvider.overrideWithValue(repo),
        subsonicClientProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AudioCacheService service() => container.read(audioCacheServiceProvider);

  test('fetches the current track list and queues each track', () async {
    await service().cachePlaylist('p', label: 'Caching "Road trip"');

    expect(backend.fetches, 1);
    expect(await states(), {
      's1': DownloadState.queued.index,
      's2': DownloadState.queued.index,
    });
    expect(await dao.watchPlaylistSongs(sid, 'p').first, hasLength(3));
  });

  test('runs as one task under the label it was given', () async {
    await service().cachePlaylist('p', label: 'Mise en cache');

    final tasks = container.read(taskRegistryProvider);
    expect(tasks, hasLength(1));
    expect(tasks.single.kind, TaskKind.audioDownload);
    expect(tasks.single.label, 'Mise en cache');
  });

  test('does not re-queue a track already downloaded', () async {
    await dao.storePlaylist(playlist, backend.songs, DateTime.utc(2026));
    await (db.update(db.songs)..where((t) => t.id.equals('s1'))).write(
      SongsCompanion(
        localPath: const Value('/music/s1'),
        downloadState: Value(DownloadState.complete.index),
      ),
    );

    await service().cachePlaylist('p', label: 'Caching');

    expect(await states(), {
      's1': DownloadState.complete.index,
      's2': DownloadState.queued.index,
    });
  });

  test('canceling keeps the tracks that finished', () async {
    final canceling = Provider((ref) => _CancelsAfterFirst(ref, db));

    await container.read(canceling).cachePlaylist('p', label: 'Caching');

    expect(await states(), {
      's1': DownloadState.complete.index,
      's2': DownloadState.none.index,
    });
    expect(await dao.watchDownloadedSongIds(sid).first, {'s1'});
  });

  test('an empty playlist starts no task', () async {
    backend.songs = const [];

    await service().cachePlaylist('p', label: 'Caching');

    expect(container.read(taskRegistryProvider), isEmpty);
  });

  test('an album still caches through the shared path', () async {
    await dao.upsertAlbums(const [
      Album(id: 'al', serverId: sid, name: 'Sleeve', songCount: 2),
    ], DateTime.utc(2026));
    await dao.upsertSongs([song('s1'), song('s2')], DateTime.utc(2026));

    await service().cacheAlbum('al');

    expect(
      container.read(taskRegistryProvider).single.label,
      'Caching "Sleeve"',
    );
    expect(await states(), {
      's1': DownloadState.queued.index,
      's2': DownloadState.queued.index,
    });
  });
}
