import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';

class _Backend implements MusicBackend {
  List<Playlist> playlists = const [];
  final tracks = <String, List<Song>>{};
  bool fails = false;
  int listCalls = 0;

  @override
  Future<List<Playlist>> getPlaylists() async {
    listCalls++;
    if (fails) throw Exception('server error');
    return playlists;
  }

  @override
  Future<Playlist> getPlaylist(String id) async {
    if (fails) throw Exception('server error');
    return playlists.firstWhere((p) => p.id == id);
  }

  @override
  Future<List<Song>> getPlaylistSongs(String playlistId) async =>
      tracks[playlistId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  const sid = 'server-1';
  late FlaxDatabase db;
  late LibraryDao dao;
  late _Backend backend;
  late LibraryRepositoryImpl repo;

  Playlist playlist(String id, {String? name, int songCount = 0}) => Playlist(
    id: id,
    serverId: sid,
    name: name ?? id,
    songCount: songCount,
    duration: songCount * 100,
  );

  Song song(String id) =>
      Song(id: id, serverId: sid, albumId: 'al1', title: 'Song $id');

  /// A server with [ids] as one playlist's tracks, fetched into the database.
  Future<void> stored(String id, List<String> ids) async {
    backend.playlists = [
      ...backend.playlists.where((p) => p.id != id),
      playlist(id, songCount: ids.length),
    ];
    backend.tracks[id] = ids.map(song).toList();
    await repo.refreshPlaylist(id);
  }

  Future<void> markDownloaded(List<String> ids) async {
    await (db.update(db.songs)..where((t) => t.id.isIn(ids))).write(
      SongsCompanion(
        localPath: const Value('/music/track'),
        downloadState: Value(DownloadState.complete.index),
      ),
    );
  }

  setUp(() {
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    backend = _Backend();
    repo = LibraryRepositoryImpl(
      dao,
      backend,
      sid,
      clock: () => DateTime.utc(2026, 11, 3),
    );
  });

  tearDown(() => db.close());

  group('the list', () {
    test('is stored, sorted by name ignoring case', () async {
      backend.playlists = [
        playlist('c', name: 'zebra'),
        playlist('a', name: 'Apple'),
        playlist('b', name: 'banana'),
      ];
      await repo.refreshPlaylists();

      final names = (await repo.watchPlaylists().first).map((p) => p.name);
      expect(names, ['Apple', 'banana', 'zebra']);
    });

    test('drops a playlist the server no longer returns, and its tracks, but '
        'keeps the downloads', () async {
      await stored('gone', ['s1', 's2']);
      await stored('kept', ['s3']);
      await markDownloaded(['s1']);

      backend.playlists = [playlist('kept', songCount: 1)];
      await repo.refreshPlaylists();

      expect((await repo.watchPlaylists().first).map((p) => p.id), ['kept']);
      expect(await repo.watchPlaylistSongs('gone').first, isEmpty);
      expect(await repo.watchDownloadedSongIds().first, {'s1'});
    });

    test('empties when the server has no playlists left', () async {
      await stored('p', ['s1']);
      backend.playlists = const [];
      await repo.refreshPlaylists();

      expect(await repo.watchPlaylists().first, isEmpty);
      expect(await repo.watchPlaylistSongs('p').first, isEmpty);
    });

    test('survives a failed refresh', () async {
      await stored('p', ['s1']);
      await repo.refreshPlaylists();
      backend.fails = true;

      await repo.refreshPlaylists();

      expect((await repo.watchPlaylists().first).map((p) => p.id), ['p']);
      expect(await repo.watchPlaylistSongs('p').first, hasLength(1));
    });

    test('an emptied playlist loses its old totals', () async {
      await stored('p', ['s1', 's2']);
      await stored('p', []);

      final p = await repo.watchPlaylist('p').first;
      expect(p!.songCount, 0);
      expect(p.duration, 0);
      expect(await repo.watchPlaylistSongs('p').first, isEmpty);
    });

    test('belongs to its server', () async {
      await stored('p', ['s1']);
      await markDownloaded(['s1']);
      await dao.replacePlaylists('server-2', const [], DateTime.utc(2026));

      expect(await repo.watchPlaylists().first, hasLength(1));
      expect(await repo.watchDownloadedPlaylists().first, hasLength(1));
    });
  });

  group('a playlist', () {
    test('keeps the server order and repeated tracks', () async {
      await stored('p', ['s3', 's1', 's3', 's2']);

      final ids = (await repo.watchPlaylistSongs('p').first).map((s) => s.id);
      expect(ids, ['s3', 's1', 's3', 's2']);
    });

    test('takes the server order again on refresh', () async {
      await stored('p', ['s1', 's2', 's3']);
      await stored('p', ['s3', 's1']);

      final ids = (await repo.watchPlaylistSongs('p').first).map((s) => s.id);
      expect(ids, ['s3', 's1']);
    });

    test('refreshing does not forget a track is downloaded', () async {
      await stored('p', ['s1']);
      await markDownloaded(['s1']);
      await stored('p', ['s1']);

      expect(await repo.watchDownloadedSongIds().first, {'s1'});
    });
  });

  group('offline', () {
    test('a playlist with no downloaded track is not listed', () async {
      await stored('uncached', ['s1']);
      await stored('cached', ['s2']);
      await markDownloaded(['s2']);

      final ids = (await repo.watchDownloadedPlaylists().first).map(
        (p) => p.id,
      );
      expect(ids, ['cached']);
    });

    test(
      'a playlist never opened is not listed, whatever is downloaded',
      () async {
        await stored('opened', ['s1']);
        await markDownloaded(['s1']);
        backend.playlists = [
          ...backend.playlists,
          playlist('never-opened', songCount: 1),
        ];
        await repo.refreshPlaylists();

        final ids = (await repo.watchDownloadedPlaylists().first).map(
          (p) => p.id,
        );
        expect(ids, ['opened']);
      },
    );

    test('a partly cached playlist is listed with the tracks it has, in '
        'playlist order', () async {
      await stored('p', ['s3', 's1', 's2', 's1']);
      await markDownloaded(['s1', 's3']);

      expect((await repo.watchDownloadedPlaylists().first), hasLength(1));
      final ids = (await repo.watchDownloadedPlaylistSongs('p').first).map(
        (s) => s.id,
      );
      expect(ids, ['s3', 's1', 's1']);
    });

    test('a queued track does not count as downloaded', () async {
      await stored('p', ['s1']);
      await dao.updateSongsDownloadState(sid, [
        's1',
      ], state: DownloadState.queued);

      expect(await repo.watchDownloadedPlaylists().first, isEmpty);
      expect(await repo.watchDownloadedPlaylistSongs('p').first, isEmpty);
    });
  });

  group('fully cached', () {
    test('needs every track', () async {
      await stored('p', ['s1', 's2']);
      await markDownloaded(['s1']);
      expect(await repo.watchDownloadedPlaylistIds().first, isEmpty);

      await markDownloaded(['s2']);
      expect(await repo.watchDownloadedPlaylistIds().first, {'p'});
    });

    test('ends when the server reports more tracks than are stored', () async {
      await stored('p', ['s1']);
      await markDownloaded(['s1']);
      expect(await repo.watchDownloadedPlaylistIds().first, {'p'});

      backend.playlists = [playlist('p', songCount: 2)];
      await repo.refreshPlaylists();
      expect(await repo.watchDownloadedPlaylistIds().first, isEmpty);
    });

    test('an empty playlist is never cached', () async {
      await stored('p', []);
      expect(await repo.watchDownloadedPlaylistIds().first, isEmpty);
    });

    test('updates as tracks finish', () async {
      await stored('p', ['s1']);
      final seen = <Set<String>>[];
      final sub = repo.watchDownloadedPlaylistIds().listen(seen.add);
      await pumpEventQueue();

      await markDownloaded(['s1']);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.last, {'p'});
    });
  });
}
