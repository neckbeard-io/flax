import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/release_group.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/features/library/album_sort.dart';
import 'package:flax/features/library/artist_songs.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/library/library_repository_impl.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// An artist's releases grouped by OpenSubsonic release type, stored, and
/// backfilled; and the songs Play loads from them. #87.
class _Backend implements MusicBackend {
  Artist? artist;
  List<Album> artistAlbums = const [];
  final albumsById = <String, Album>{};
  final songsByAlbum = <String, List<Song>>{};
  Map<String, dynamic>? scanStatus;

  int getArtistCalls = 0;
  final getAlbumCalls = <String>[];

  @override
  Future<Artist> getArtist(String id) async {
    getArtistCalls++;
    return artist!;
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => artistAlbums;

  @override
  Future<Album> getAlbum(String id) async {
    getAlbumCalls.add(id);
    return albumsById[id]!;
  }

  @override
  Future<List<Song>> getAlbumSongs(String albumId) async =>
      songsByAlbum[albumId] ?? const [];

  @override
  Future<Map<String, dynamic>?> getScanStatus() async => scanStatus;

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  const sid = 'server-1';
  const artistId = 'ar1';
  final now = DateTime.utc(2026, 10, 12, 12);

  Album album(
    String id, {
    List<String>? types,
    bool? compilation,
    int? year,
    int songCount = 2,
  }) => Album(
    id: id,
    serverId: sid,
    artistId: artistId,
    name: 'Album $id',
    year: year,
    songCount: songCount,
    releaseTypes: types,
    isCompilation: compilation,
  );

  Song song(String id, String albumId, {int track = 1}) => Song(
    id: id,
    serverId: sid,
    albumId: albumId,
    artistId: artistId,
    title: 'Song $id',
    track: track,
  );

  group('releaseGroupOf', () {
    ReleaseGroup of(List<String>? types, {bool? compilation}) =>
        releaseGroupOf(album('x', types: types, compilation: compilation));

    test('reads every combination Navidrome 0.64 was seen to send', () {
      expect(of(['album']), ReleaseGroup.albums);
      expect(of(['ep']), ReleaseGroup.epsAndSingles);
      expect(of(['single']), ReleaseGroup.epsAndSingles);
      // Alphabetized: the primary type is not first.
      expect(of(['demo', 'ep']), ReleaseGroup.other);
      expect(of(['compilation', 'ep']), ReleaseGroup.compilations);
      expect(of(['remix', 'single']), ReleaseGroup.other);
      expect(of(['album', 'live']), ReleaseGroup.live);
      expect(of(['album', 'soundtrack']), ReleaseGroup.other);
      expect(of(['album', 'compilation']), ReleaseGroup.compilations);
      expect(of(['album', 'compilation', 'demo', 'live']), ReleaseGroup.live);
      expect(of(['album', 'compilation', 'dj-mix']), ReleaseGroup.compilations);
      expect(of(['album', 'mixtape/street']), ReleaseGroup.other);
      expect(of(['other']), ReleaseGroup.other);
    });

    test('ignores case and unknown tokens', () {
      expect(of(['Album']), ReleaseGroup.albums);
      expect(of(['EP']), ReleaseGroup.epsAndSingles);
      expect(of([' Live ']), ReleaseGroup.live);
      // A tag split into letters, which is still an album.
      expect(of(['a', 'album', 'b', 'l', 'm', 'u']), ReleaseGroup.albums);
    });

    test('anything unknown or untagged is an album', () {
      expect(of(null), ReleaseGroup.albums);
      expect(of(const []), ReleaseGroup.albums);
    });

    test('the compilation flag counts, but live still wins', () {
      expect(of(['album'], compilation: true), ReleaseGroup.compilations);
      expect(of(['album', 'live'], compilation: true), ReleaseGroup.live);
    });
  });

  group('groupReleases', () {
    test('page order, input order within a group, empty groups left out', () {
      final groups = groupReleases([
        album('ep1', types: ['ep']),
        album('al1', types: ['album']),
        album('live1', types: ['album', 'live']),
        album('al2', types: ['album']),
      ]);
      expect(groups.map((g) => g.$1), [
        ReleaseGroup.albums,
        ReleaseGroup.epsAndSingles,
        ReleaseGroup.live,
      ]);
      expect(groups.first.$2.map((a) => a.id), ['al1', 'al2']);
    });

    test('discographyOrder sorts within each group', () {
      final ordered = discographyOrder([
        album('ep', types: ['ep'], year: 1990),
        album('new', types: ['album'], year: 2005),
        album('old', types: ['album'], year: 1995),
      ], AlbumSortMode.yearAsc);
      expect(ordered.map((a) => a.id), ['old', 'new', 'ep']);
    });
  });

  group('parsing', () {
    test('trims, lowercases and removes duplicates', () {
      expect(
        SubsonicClient.parseReleaseTypes({
          'releaseTypes': ['Album', ' live ', 'album', ''],
        }),
        ['album', 'live'],
      );
    });

    test('an empty list is known to be empty; no field is unknown', () {
      expect(SubsonicClient.parseReleaseTypes({'releaseTypes': []}), isEmpty);
      expect(SubsonicClient.parseReleaseTypes({}), isNull);
    });
  });

  group('top songs request', () {
    test('sends the artist id beside the name, and only when given', () async {
      final sent = <Map<String, dynamic>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent.add(options.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'subsonic-response': {
                      'status': 'ok',
                      'topSongs': {'song': <dynamic>[]},
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = SubsonicClient(
        server: const Server(
          id: 'srv',
          name: 'Home',
          url: 'https://music.example.com',
          username: 'tester',
          tokenHash: 'secret',
          salt: '',
        ),
        dio: dio,
      );

      await client.getTopSongs('Porcupine Tree', artistId: 'ar1', count: 10);
      await client.getTopSongs('Porcupine Tree');

      expect(sent[0]['artist'], 'Porcupine Tree');
      expect(sent[0]['id'], 'ar1');
      expect(sent[0]['count'], 10);
      expect(sent[1].containsKey('id'), isFalse);
    });
  });

  group('similar artists', () {
    test('those with no albums here are left out', () {
      const info = ArtistInfo(
        similarArtists: [
          SimilarArtist(id: '1', name: 'Judas Priest', albumCount: 5),
          SimilarArtist(id: '2', name: 'Bruce Dickinson', albumCount: 0),
          SimilarArtist(id: '3', name: 'Unknown count'),
        ],
      );
      expect(info.similarInLibrary.map((a) => a.name), [
        'Judas Priest',
        'Unknown count',
      ]);
    });
  });

  group('storage and backfill', () {
    late FlaxDatabase db;
    late LibraryDao dao;
    late _Backend backend;

    LibraryRepositoryImpl repo() =>
        LibraryRepositoryImpl(dao, backend, sid, clock: () => now);

    setUp(() {
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
      backend = _Backend();
    });

    tearDown(() => db.close());

    test('round-trips, and a thin record does not wipe stored types', () async {
      await dao.upsertAlbums([
        album('a', types: ['album', 'live'], compilation: false),
        album('b', types: const []),
        album('c'),
      ], now);
      final a = (await dao.watchAlbum(sid, 'a').first)!;
      expect(a.releaseTypes, ['album', 'live']);
      expect(a.isCompilation, isFalse);
      expect((await dao.watchAlbum(sid, 'b').first)!.releaseTypes, isEmpty);
      expect((await dao.watchAlbum(sid, 'c').first)!.releaseTypes, isNull);

      await dao.upsertAlbums([album('a')], now);
      final again = (await dao.watchAlbum(sid, 'a').first)!;
      expect(again.releaseTypes, ['album', 'live']);
      expect(again.isCompilation, isFalse);
    });

    test('a v4 database opens at v5 with release types unknown', () async {
      final dir = Directory.systemTemp.createTempSync('flax_release_types_');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
        dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Today's schema with a row in it, then taken back to v4: the v5
      // columns dropped and the version number rewound.
      final current = FlaxDatabase(NativeDatabase(file));
      await LibraryDao(current).upsertAlbums([album('al1')], now);
      await current.close();

      var downgraded = false;
      final upgraded = FlaxDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            if (downgraded) return;
            downgraded = true;
            raw.execute('ALTER TABLE albums DROP COLUMN release_types_json');
            raw.execute('ALTER TABLE albums DROP COLUMN is_compilation');
            raw.execute('PRAGMA user_version = 4');
          },
        ),
      );
      addTearDown(upgraded.close);
      final upgradedDao = LibraryDao(upgraded);

      final stored = (await upgradedDao.watchAlbum(sid, 'al1').first)!;
      expect(stored.releaseTypes, isNull);
      expect(stored.isCompilation, isNull);
      expect(
        await upgradedDao.artistReleaseTypesUnknown(sid, artistId),
        isTrue,
      );
    });

    test('an artist cached before release types refetches once', () async {
      backend.scanStatus = {
        'lastScan': '2026-10-01T00:00:00Z',
        'count': 100,
        'scanning': false,
      };
      backend.artist = const Artist(
        id: artistId,
        serverId: sid,
        name: 'Porcupine Tree',
        albumCount: 2,
      );
      backend.artistAlbums = [
        album('al1', types: ['album']),
        // A server that sends no types for one album: it settles as none.
        album('al2'),
      ];
      final r = repo();

      // Cached by an older flax: every album there, types unknown.
      await dao.upsertArtists([backend.artist!], now);
      await dao.upsertAlbums([album('al1'), album('al2')], now);
      await r.syncIfChanged();

      await r.refreshArtist(artistId);
      expect(backend.getArtistCalls, 1, reason: 'unknown types must refetch');
      expect((await dao.watchAlbum(sid, 'al1').first)!.releaseTypes, ['album']);
      expect((await dao.watchAlbum(sid, 'al2').first)!.releaseTypes, isEmpty);

      await r.refreshArtist(artistId);
      expect(backend.getArtistCalls, 1, reason: 'no refetch loop');
    });

    test('Play loads albums never opened, in the order given', () async {
      final r = repo();
      final albums = [album('al2'), album('al1')];
      await dao.upsertAlbums(albums, now);
      // al1 was opened before; al2 never was.
      await dao.upsertSongs([
        song('a1', 'al1'),
        song('a2', 'al1', track: 2),
      ], now);
      backend.albumsById['al2'] = album('al2');
      backend.songsByAlbum['al2'] = [
        song('b1', 'al2'),
        song('b2', 'al2', track: 2),
      ];

      final songs = await loadArtistSongs(r, albums, offline: false);

      expect(songs.map((s) => s.id), ['b1', 'b2', 'a1', 'a2']);
      expect(backend.getAlbumCalls, ['al2'], reason: 'only the missing one');
    });

    test('offline, Play loads only what is downloaded', () async {
      final r = repo();
      final albums = [album('al1')];
      await dao.upsertAlbums(albums, now);
      await dao.upsertSongs([
        song('a1', 'al1'),
        song('a2', 'al1', track: 2),
      ], now);
      await dao.updateSongDownload(
        sid,
        'a2',
        localPath: '/music/a2.flac',
        state: DownloadState.complete,
      );

      final songs = await loadArtistSongs(r, albums, offline: true);

      expect(songs.map((s) => s.id), ['a2']);
      expect(backend.getAlbumCalls, isEmpty, reason: 'nothing fetched offline');
    });
  });
}
