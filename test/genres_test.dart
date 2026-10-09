import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/genres.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// Every genre an album or track carries, kept, cached and backfilled. #134.
class _Backend implements MusicBackend {
  /// What `getAlbumList2` holds, served in pages as the real server does.
  List<Album> library = const [];

  /// A server that ignores `offset` and returns the first page every time.
  bool ignoresOffset = false;

  Album? album;
  List<Song> songs = const [];
  Map<String, dynamic>? scanStatus;

  final listOffsets = <int>[];
  int getAlbumCalls = 0;
  String? randomGenre;

  @override
  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int offset = 0,
    int count = 20,
    int? fromYear,
    int? toYear,
    String? genre,
  }) async {
    listOffsets.add(offset);
    final start = ignoresOffset ? 0 : offset;
    return library.skip(start).take(count).toList();
  }

  @override
  Future<Album> getAlbum(String id) async {
    getAlbumCalls++;
    return album!;
  }

  @override
  Future<List<Song>> getAlbumSongs(String albumId) async => songs;

  @override
  Future<Map<String, dynamic>?> getScanStatus() async => scanStatus;

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<List<Song>> getRandomSongs({int count = 20, String? genre}) async {
    randomGenre = genre;
    return songs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  const sid = 'server-1';
  late FlaxDatabase db;
  late LibraryDao dao;
  late _Backend backend;
  final now = DateTime.utc(2026, 10, 8, 12);

  LibraryRepositoryImpl repo() =>
      LibraryRepositoryImpl(dao, backend, sid, clock: () => now);

  Album album(String id, {List<String>? genres, String? genre}) => Album(
    id: id,
    serverId: sid,
    name: 'Album $id',
    songCount: 2,
    genre: genre,
    genres: genres,
  );

  Song song(
    String id, {
    String albumId = 'al1',
    List<String>? genres,
    String? genre,
  }) => Song(
    id: id,
    serverId: sid,
    albumId: albumId,
    title: 'Song $id',
    genre: genre,
    genres: genres,
  );

  setUp(() {
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    backend = _Backend();
  });

  tearDown(() => db.close());

  group('genre names', () {
    test('are trimmed, de-duplicated ignoring case, and kept in order', () {
      expect(normalizeGenres([' Rock', 'rock', '', 'Pop ', 'POP', 'Dub']), [
        'Rock',
        'Pop',
        'Dub',
      ]);
    });

    test('a single genre is never split on separators', () {
      expect(genresFromSingle('Rock & Roll'), ['Rock & Roll']);
      expect(genresFromSingle('Rock; Pop'), ['Rock; Pop']);
      expect(genresFromSingle(null), isEmpty);
    });

    test('compare as sets, ignoring case and order', () {
      expect(sameGenres(['Rock', 'Pop'], ['pop', 'ROCK']), isTrue);
      expect(sameGenres(['Rock'], ['Rock', 'Pop']), isFalse);
      expect(hasGenre(['Trip-Hop'], 'trip-hop'), isTrue);
    });
  });

  group('parsing', () {
    test('the OpenSubsonic list wins over the single genre', () {
      expect(
        SubsonicClient.parseGenres({
          'genre': 'Electronic',
          'genres': [
            {'name': 'Electronic'},
            {'name': 'Techno'},
            {'name': 'electronic'},
          ],
        }),
        ['Electronic', 'Techno'],
      );
    });

    test('falls back to the single genre', () {
      expect(SubsonicClient.parseGenres({'genre': 'Britpop'}), ['Britpop']);
    });

    test('an empty list is known to be empty', () {
      expect(SubsonicClient.parseGenres({'genres': <dynamic>[]}), isEmpty);
    });

    test('with neither field the genres are unknown', () {
      expect(SubsonicClient.parseGenres({'title': 'x'}), isNull);
    });
  });

  group('models', () {
    test('show the single genre while the list is unknown', () {
      expect(album('a', genre: 'Rock').displayGenres, ['Rock']);
      expect(album('a', genre: 'Rock', genres: ['Rock', 'Pop']).displayGenres, [
        'Rock',
        'Pop',
      ]);
      expect(album('a', genres: const []).displayGenres, isEmpty);
    });

    test('a saved queue keeps them, and an old entry reads as unknown', () {
      final saved = song('s', genre: 'Dub', genres: ['Dub', 'Reggae']);
      expect(Song.fromJson(saved.toJson()).genres, ['Dub', 'Reggae']);

      final old = saved.toJson()..remove('genres');
      final restored = Song.fromJson(old);
      expect(restored.genres, isNull);
      expect(restored.displayGenres, ['Dub']);
    });
  });

  group('storage', () {
    test('round-trips, including an empty list', () async {
      await dao.upsertAlbums([
        album('a', genres: ['Rock', 'Pop']),
        album('b', genres: const []),
        album('c'),
      ], now);

      expect((await dao.watchAlbum(sid, 'a').first)!.genres, ['Rock', 'Pop']);
      expect((await dao.watchAlbum(sid, 'b').first)!.genres, isEmpty);
      expect((await dao.watchAlbum(sid, 'c').first)!.genres, isNull);
    });

    test('a record that says nothing does not wipe stored genres', () async {
      await dao.upsertSongs([
        song('s1', genres: ['Dub']),
      ], now);
      await dao.upsertSongs([song('s1')], now);
      expect((await dao.watchSong(sid, 's1').first)!.genres, ['Dub']);
    });

    test('an album is unknown while it or any track lacks genres', () async {
      await dao.upsertAlbums([
        album('al1', genres: ['Rock']),
      ], now);
      await dao.upsertSongs([
        song('s1', genres: ['Rock']),
        song('s2'),
      ], now);
      expect(await dao.albumGenresUnknown(sid, 'al1'), isTrue);

      await dao.upsertSongs([song('s2', genres: const [])], now);
      expect(await dao.albumGenresUnknown(sid, 'al1'), isFalse);
    });

    test('settling marks only what is still unknown as none', () async {
      await dao.upsertAlbums([album('al1')], now);
      await dao.upsertSongs([
        song('s1', genres: ['Dub']),
        song('s2'),
      ], now);

      await dao.settleAlbumGenres(sid, 'al1');

      expect((await dao.watchAlbum(sid, 'al1').first)!.genres, isEmpty);
      expect((await dao.watchSong(sid, 's1').first)!.genres, ['Dub']);
      expect((await dao.watchSong(sid, 's2').first)!.genres, isEmpty);
      expect(await dao.albumGenresUnknown(sid, 'al1'), isFalse);
    });

    test('lists only downloaded albums that are missing genres', () async {
      await dao.upsertAlbums([
        album('known', genres: ['Rock']),
        album('unknown'),
        album('streamed'),
      ], now);
      await dao.upsertSongs([
        song('k1', albumId: 'known', genres: ['Rock']),
        song('u1', albumId: 'unknown'),
        song('st1', albumId: 'streamed'),
      ], now);
      for (final id in ['k1', 'u1']) {
        await dao.updateSongDownload(
          sid,
          id,
          localPath: '/music/$id.flac',
          state: DownloadState.complete,
        );
      }

      expect(await dao.downloadedAlbumIdsMissingGenres(sid), ['unknown']);
    });

    test('downloaded albums filter by genre, ignoring case', () async {
      await dao.upsertAlbums([
        album('rock', genres: ['Rock', 'Pop']),
        album('jazz', genres: ['Jazz']),
        album('legacy', genre: 'rock'),
      ], now);
      await dao.upsertSongs([
        song('r1', albumId: 'rock'),
        song('j1', albumId: 'jazz'),
        song('l1', albumId: 'legacy'),
      ], now);
      for (final id in ['r1', 'j1', 'l1']) {
        await dao.updateSongDownload(
          sid,
          id,
          localPath: '/music/$id.flac',
          state: DownloadState.complete,
        );
      }

      final rock = await dao
          .watchDownloadedAlbums(
            sid,
            const AlbumListQuery(AlbumListType.byGenre, genre: 'ROCK'),
          )
          .first;
      expect(rock.map((a) => a.id), unorderedEquals(['rock', 'legacy']));
    });
  });

  group('backfill', () {
    Map<String, dynamic> status() => {
      'lastScan': '2026-08-07T23:55:56Z',
      'count': 100,
      'scanning': false,
    };

    test('refetches an album cached before genres, past the beacon', () async {
      backend.scanStatus = status();
      backend.album = album('al1', genres: ['Rock', 'Pop']);
      backend.songs = [
        song('s1', genres: ['Rock']),
        song('s2', genres: ['Pop']),
      ];
      final r = repo();

      // Cached by an older flax: rows complete, genres unknown, beacon stored.
      await dao.upsertAlbums([album('al1', genre: 'Rock')], now);
      await dao.upsertSongs([song('s1'), song('s2')], now);
      await r.syncIfChanged();

      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1, reason: 'unknown genres must refetch');
      expect((await dao.watchAlbum(sid, 'al1').first)!.genres, ['Rock', 'Pop']);

      // Settled: an unchanged beacon suppresses the refresh again.
      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1);
    });

    test('a cached track the server no longer lists settles too', () async {
      backend.scanStatus = status();
      backend.album = album('al1', genres: ['Rock']);
      backend.songs = [
        song('s1', genres: ['Rock']),
      ];
      // s2 was cached earlier and has since left the album.
      await dao.upsertSongs([song('s1'), song('s2')], now);
      final r = repo();
      await r.syncIfChanged();

      await r.refreshAlbum('al1');
      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1, reason: 'no refetch loop');
    });

    test('an album the server tags with nothing settles as empty', () async {
      backend.scanStatus = status();
      backend.album = album('al1');
      backend.songs = [song('s1'), song('s2')];
      final r = repo();

      await r.refreshAlbum('al1');
      expect(await dao.albumGenresUnknown(sid, 'al1'), isFalse);
      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1, reason: 'no refetch loop');
    });
  });

  group('genre pages', () {
    const rock = AlbumListQuery(AlbumListType.byGenre, genre: 'Rock');

    test('page through the whole genre', () async {
      backend.library = [for (var i = 0; i < 1200; i++) album('a$i')];
      final r = repo();

      await r.refreshAlbumList(rock, force: true);
      // The first page is stored when the call returns...
      expect(
        (await dao.watchAlbumList(sid, rock).first).length,
        greaterThanOrEqualTo(500),
      );

      // ...and the rest follow behind it.
      final all = await dao
          .watchAlbumList(sid, rock)
          .firstWhere((list) => list.length == 1200)
          .timeout(const Duration(seconds: 5));
      expect(all.first.id, 'a0');
      expect(all.last.id, 'a1199');
      expect(backend.listOffsets, [0, 500, 1000]);
    });

    test('stop when the server ignores offset', () async {
      backend.library = [for (var i = 0; i < 500; i++) album('a$i')];
      backend.ignoresOffset = true;
      final r = repo();

      await r.refreshAlbumList(rock, force: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(backend.listOffsets, [0, 500]);
      expect(await dao.watchAlbumList(sid, rock).first, hasLength(500));
    });

    test('other lists still ask for one page', () async {
      backend.library = [for (var i = 0; i < 600; i++) album('a$i')];
      await repo().refreshAlbumList(
        const AlbumListQuery(AlbumListType.newest),
        force: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(backend.listOffsets, [0]);
    });

    test('shuffle asks the server for the genre', () async {
      backend.songs = [song('s1')];
      await repo().watchRandomSongs(genre: 'Rock').first;
      expect(backend.randomGenre, 'Rock');
    });
  });

  group('migration', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('flax_genres_');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      dir.deleteSync(recursive: true);
    });

    test('a v3 database opens at v4 with genres unknown', () async {
      final file = File('${dir.path}/library.sqlite');

      // Build today's schema, store rows, then take the database back to v3:
      // the genre columns dropped and the version number rewound.
      final current = FlaxDatabase(NativeDatabase(file));
      await LibraryDao(
        current,
      ).upsertAlbums([album('al1', genre: 'Trip-Hop')], now);
      await LibraryDao(current).upsertSongs([song('s1', genre: 'Dub')], now);
      await current.close();

      var downgraded = false;
      final upgraded = FlaxDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (downgraded) return;
            downgraded = true;
            raw.execute('ALTER TABLE albums DROP COLUMN genres_json');
            raw.execute('ALTER TABLE songs DROP COLUMN genres_json');
            raw.execute('PRAGMA user_version = 3');
          },
        ),
      );
      final upgradedDao = LibraryDao(upgraded);

      final stored = (await upgradedDao.watchAlbum(sid, 'al1').first)!;
      expect(stored.genres, isNull);
      expect(stored.displayGenres, ['Trip-Hop']);
      expect(await upgradedDao.albumGenresUnknown(sid, 'al1'), isTrue);

      await upgradedDao.upsertSongs([
        song('s1', genres: ['Dub', 'Reggae']),
      ], now);
      expect((await upgradedDao.watchSong(sid, 's1').first)!.genres, [
        'Dub',
        'Reggae',
      ]);
      await upgraded.close();
    });
  });
}
