import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file/local.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/app_in_use_provider.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
import 'package:flax/shared/widgets/cover_index.dart';

import 'helpers/fake_cache_info_repository.dart';
import 'helpers/fake_cover_store.dart';

const _sid = 'srv';

class _Client extends Mock implements SubsonicClient {
  _Client(this._server);

  final Server _server;
  final Map<String, ArtistInfo?> info = {};
  final Map<String, Lyrics?> structured = {};
  Object? lyricsError;
  final lyricsAsked = <String>[];
  final artistsAsked = <String>[];

  /// Called before each artist lookup, to change the world partway through.
  void Function()? onArtistLookup;

  @override
  Server get server => _server;

  @override
  Future<void> whenTargetChosen() async {}

  @override
  Future<String?> tryPing({Duration? timeout}) async => null;

  @override
  Uri getCoverArtUri(String? id, {int? size}) =>
      Uri.parse('https://music.example.com/rest/getCoverArt?id=$id&size=$size');

  @override
  Uri getDownloadUri(String? id) =>
      Uri.parse('https://music.example.com/rest/download?id=$id');

  @override
  Future<ArtistInfo?> getArtistInfoParsed(String? id) async {
    artistsAsked.add(id!);
    onArtistLookup?.call();
    return info[id];
  }

  @override
  Future<Lyrics?> getSongLyrics(String? songId) async => structured[songId];

  @override
  Future<String?> getLyrics({String? artist, String? title}) async {
    lyricsAsked.add(title!);
    final error = lyricsError;
    if (error != null) throw error;
    return null;
  }
}

/// Serves what a real refresh would have stored, without a server.
class _Repo extends Fake implements LibraryRepository {
  _Repo(this.dao);

  final LibraryDao dao;
  final albumsOnServer = <String, Album>{};
  final albumRefreshes = <String>[];

  @override
  Future<void> refreshAlbum(String? albumId, {bool force = false}) async {
    albumRefreshes.add(albumId!);
    final album = albumsOnServer[albumId];
    if (album != null) await dao.upsertAlbums([album], DateTime.utc(2026));
  }

  @override
  Future<void> refreshArtist(String? artistId, {bool force = false}) async {}
}

class _AudioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    [1, 2, 3, 4],
    200,
    headers: {
      Headers.contentLengthHeader: ['4'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlaxDatabase db;
  late LibraryDao dao;
  late _Repo repo;
  late _Client client;
  late FakeCoverStore covers;
  late Directory dir;
  late Directory base;
  late List<ConnectivityResult> network;
  late bool inUse;
  late ProviderContainer container;
  late AudioCacheService service;

  const server = Server(
    id: _sid,
    name: 'Home',
    url: 'https://music.example.com',
    username: 'driver',
    tokenHash: 'tok',
    salt: 'salt',
  );

  /// The size the default configuration stores album and artist art at.
  final size = MetadataQuality.medium.requestSize;

  Future<CoverIndex> readIndex() {
    final rows = [
      for (final entry in covers.files.entries)
        coverRow(entry.key, p.basename(entry.value.path)),
    ];
    return CoverIndex.read(repo: FakeCacheInfoRepository(rows), directory: dir);
  }

  /// A fresh service: as after a restart, with no memory of an earlier repair.
  ProviderContainer build() {
    final fresh = ProviderContainer(
      overrides: [
        libraryDaoProvider.overrideWithValue(dao),
        libraryRepositoryProvider.overrideWithValue(repo),
        subsonicClientProvider.overrideWithValue(client),
        activeServerProvider.overrideWithValue(server),
        artCacheProvider.overrideWithValue(covers),
        coverIndexReaderProvider.overrideWithValue(readIndex),
        connectivityProvider.overrideWith((ref) async => network),
        appInUseProvider.overrideWith((ref) => inUse),
        audioCacheServiceProvider.overrideWith(
          (ref) => AudioCacheService(
            ref,
            dio: Dio()..httpClientAdapter = _AudioAdapter(),
          ),
        ),
      ],
    );
    addTearDown(fresh.dispose);
    return fresh;
  }

  Future<void> download(
    String id, {
    String? albumId,
    String? artistId,
    String? coverArtId,
  }) async {
    await dao.upsertSongs([
      Song(
        id: id,
        serverId: _sid,
        title: 'Song $id',
        artistName: 'Artist',
        albumId: albumId,
        artistId: artistId,
        coverArtId: coverArtId,
      ),
    ], DateTime.utc(2026));
    await dao.updateSongDownload(
      _sid,
      id,
      localPath: '/music/$id',
      state: DownloadState.complete,
    );
  }

  Future<void> storeAlbum(String id, {String? artistId, String? coverArtId}) =>
      dao.upsertAlbums([
        Album(
          id: id,
          serverId: _sid,
          name: id,
          artistId: artistId,
          coverArtId: coverArtId,
        ),
      ], DateTime.utc(2026));

  Future<void> storeArtist(
    String id, {
    String? biography,
    String? coverArtId,
    String? imageUrl,
  }) => dao.upsertArtists([
    Artist(
      id: id,
      serverId: _sid,
      name: id,
      biography: biography,
      coverArtId: coverArtId,
      imageUrl: imageUrl,
    ),
  ], DateTime.utc(2026));

  File lyricsFile(String id) =>
      File(p.join(base.path, 'lyrics', _sid, '$id.lrc'));

  /// Marks [id]'s lyrics as already dealt with.
  void lyricsDone(String id) {
    lyricsFile(id)
      ..createSync(recursive: true)
      ..writeAsStringSync('');
  }

  void storeCover(String id, {int? at}) =>
      covers.add(coverCacheKey(id, at ?? size));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    repo = _Repo(dao);
    client = _Client(server);
    dir = Directory.systemTemp.createTempSync('lineage_covers');
    base = Directory.systemTemp.createTempSync('lineage_base');
    covers = FakeCoverStore(const LocalFileSystem().directory(dir.path));
    AudioCacheService.cachedBasePath = base.path;
    CoverArtCache.resetForTest();
    network = [ConnectivityResult.wifi];
    inUse = true;
    container = build();
    service = container.read(audioCacheServiceProvider);
  });

  tearDown(() async {
    AudioCacheService.cachedBasePath = null;
    await db.close();
    dir.deleteSync(recursive: true);
    base.deleteSync(recursive: true);
  });

  group('a repair', () {
    test('fetches everything a downloaded track is missing', () async {
      await download('s1', albumId: 'al', artistId: 'ar', coverArtId: 'c-song');
      await storeAlbum('al', artistId: 'ar', coverArtId: 'c-album');
      await storeArtist('ar', coverArtId: 'c-artist');
      client.info['ar'] = const ArtistInfo(
        biography: 'Their story',
        largeImageUrl: 'https://photos.example.com/ar.jpg',
      );

      await service.repairOfflineLineage();

      expect(
        covers.downloaded,
        containsAll([
          coverCacheKey('c-song', size),
          coverCacheKey('c-album', size),
          coverCacheKey('c-artist', size),
          'https://photos.example.com/ar.jpg',
        ]),
      );
      final artist = await dao.watchArtist(_sid, 'ar').first;
      expect(artist?.biography, 'Their story');
      expect(client.lyricsAsked, ['Song s1']);
    });

    test('fetches a record the album never got, and what it names', () async {
      await download('s1', albumId: 'al');
      lyricsDone('s1');
      repo.albumsOnServer['al'] = const Album(
        id: 'al',
        serverId: _sid,
        name: 'al',
        artistId: 'ar',
        coverArtId: 'c-album',
      );
      await storeArtist('ar', biography: 'Bio');

      await service.repairOfflineLineage();

      expect(repo.albumRefreshes, ['al']);
      expect(covers.downloaded, [coverCacheKey('c-album', size)]);
    });

    test('covers the album\'s artist when the track has its own', () async {
      await download('s1', albumId: 'al', artistId: 'guest');
      lyricsDone('s1');
      await storeAlbum('al', artistId: 'various');
      await storeArtist('guest', biography: 'Bio');
      await storeArtist('various');
      client.info['various'] = const ArtistInfo(biography: 'Many hands');

      await service.repairOfflineLineage();

      expect(client.artistsAsked, ['various']);
    });

    test('stores a cached playlist\'s own cover', () async {
      await download('s1');
      lyricsDone('s1');
      await dao.storePlaylist(
        const Playlist(
          id: 'p',
          serverId: _sid,
          name: 'p',
          songCount: 1,
          coverArtId: 'pl-p',
        ),
        [const Song(id: 's1', serverId: _sid, title: 'Song s1')],
        DateTime.utc(2026),
      );
      await dao.updateSongDownload(
        _sid,
        's1',
        localPath: '/music/s1',
        state: DownloadState.complete,
      );

      await service.repairOfflineLineage();

      expect(covers.downloaded, [coverCacheKey('pl-p', size)]);
    });

    test('asks for nothing when nothing is missing', () async {
      await download('s1', albumId: 'al', artistId: 'ar', coverArtId: 'c-song');
      await storeAlbum('al', artistId: 'ar', coverArtId: 'c-song');
      await storeArtist('ar', biography: 'Bio', coverArtId: 'c-artist');
      storeCover('c-song');
      storeCover('c-artist');
      lyricsDone('s1');

      expect(await service.repairOfflineLineage(), 0);

      expect(covers.downloaded, isEmpty);
      expect(client.artistsAsked, isEmpty);
      expect(client.lyricsAsked, isEmpty);
    });

    test('doesn\'t take a thumbnail for the stored cover', () async {
      await download('s1', coverArtId: 'c-song');
      lyricsDone('s1');
      storeCover('c-song', at: 128);

      await service.repairOfflineLineage();

      expect(covers.downloaded, [coverCacheKey('c-song', size)]);
    });

    test('accepts a larger copy as the stored cover', () async {
      await download('s1', coverArtId: 'c-song');
      lyricsDone('s1');
      storeCover('c-song', at: 2048);

      expect(await service.repairOfflineLineage(), 0);
    });

    test('ignores tracks that aren\'t downloaded', () async {
      await dao.upsertSongs([
        const Song(
          id: 's1',
          serverId: _sid,
          title: 'Streamed',
          coverArtId: 'c-song',
        ),
      ], DateTime.utc(2026));

      expect(await service.repairOfflineLineage(), 0);
    });
  });

  group('what a repair learned', () {
    test('a failed artist lookup leaves the biography to ask again', () async {
      await download('s1', artistId: 'ar');
      lyricsDone('s1');
      await storeArtist('ar');

      await service.repairOfflineLineage();

      final artist = await dao.watchArtist(_sid, 'ar').first;
      expect(artist?.biography, isNull);

      client.info['ar'] = const ArtistInfo(biography: 'Found it');
      await build().read(audioCacheServiceProvider).repairOfflineLineage();

      expect((await dao.watchArtist(_sid, 'ar').first)?.biography, 'Found it');
    });

    test('an artist with no biography is asked about once', () async {
      await download('s1', artistId: 'ar');
      lyricsDone('s1');
      await storeArtist('ar');
      client.info['ar'] = const ArtistInfo();

      await service.repairOfflineLineage();
      await build().read(audioCacheServiceProvider).repairOfflineLineage();

      expect((await dao.watchArtist(_sid, 'ar').first)?.biography, '');
      expect(client.artistsAsked, ['ar']);
    });

    test(
      'a biography recorded empty before this fix is rechecked once',
      () async {
        await download('s1', artistId: 'ar');
        lyricsDone('s1');
        await storeArtist('ar', biography: '');
        client.info['ar'] = const ArtistInfo(biography: 'There was one');

        await service.repairOfflineLineage();
        expect(
          (await dao.watchArtist(_sid, 'ar').first)?.biography,
          'There was one',
        );

        await storeArtist('ar', biography: '');
        await build().read(audioCacheServiceProvider).repairOfflineLineage();

        expect(client.artistsAsked, ['ar']);
      },
    );

    test('lyrics the server doesn\'t have are asked about once', () async {
      await download('s1');

      await service.repairOfflineLineage();
      await build().read(audioCacheServiceProvider).repairOfflineLineage();

      expect(client.lyricsAsked, ['Song s1']);
      expect(lyricsFile('s1').readAsStringSync(), '');
    });

    test('a failed lyrics request is tried again', () async {
      await download('s1');
      client.lyricsError = DioException(
        requestOptions: RequestOptions(path: '/rest/getLyrics'),
      );

      await service.repairOfflineLineage();
      expect(lyricsFile('s1').existsSync(), isFalse);

      client.lyricsError = null;
      await build().read(audioCacheServiceProvider).repairOfflineLineage();

      expect(client.lyricsAsked, ['Song s1', 'Song s1']);
      expect(lyricsFile('s1').existsSync(), isTrue);
    });

    test(
      'a server that refuses the lyrics call counts as having none',
      () async {
        await download('s1');
        client.lyricsError = const SubsonicException(
          code: 70,
          message: 'not found',
        );

        await service.repairOfflineLineage();

        expect(lyricsFile('s1').existsSync(), isTrue);
      },
    );
  });

  group('a repair holds off', () {
    setUp(() => download('s1', coverArtId: 'c-song'));

    Future<void> expectNothingFetched() async {
      expect(await service.repairOfflineLineage(), 0);
      expect(covers.downloaded, isEmpty);
      expect(client.lyricsAsked, isEmpty);
    }

    test('offline', () async {
      container.read(offlineManualOverrideProvider.notifier).set(true);
      await expectNothingFetched();
    });

    test('on cellular', () async {
      network = [ConnectivityResult.mobile];
      await expectNothingFetched();
    });

    test('while nobody is using flax', () async {
      inUse = false;
      await expectNothingFetched();
    });

    test('runs on cellular plus Wi-Fi', () async {
      network = [ConnectivityResult.mobile, ConnectivityResult.wifi];
      expect(await service.repairOfflineLineage(), greaterThan(0));
    });

    test('comes back when the network does', () async {
      network = [ConnectivityResult.mobile];
      await service.repairOfflineLineage();

      network = [ConnectivityResult.wifi];
      await service.repairOfflineLineage();

      expect(covers.downloaded, [coverCacheKey('c-song', size)]);
    });

    test('runs again only after a while', () async {
      await service.repairOfflineLineage();
      covers.downloaded.clear();
      await download('s2', coverArtId: 'c-other');

      expect(await service.repairOfflineLineage(), 0);
      expect(covers.downloaded, isEmpty);
    });

    test('stops when the car goes offline, and picks up again', () async {
      await download('s2', artistId: 'a1');
      await download('s3', artistId: 'a2');
      await storeArtist('a1');
      await storeArtist('a2');
      client.onArtistLookup = () {
        container.read(offlineManualOverrideProvider.notifier).set(true);
      };

      await service.repairOfflineLineage();
      final asked = client.lyricsAsked.length;
      expect(asked, lessThan(3));

      client.onArtistLookup = null;
      container.read(offlineManualOverrideProvider.notifier).set(false);
      await service.repairOfflineLineage();

      expect(client.lyricsAsked.toSet(), {'Song s1', 'Song s2', 'Song s3'});
    });
  });

  group('a download', () {
    /// Metadata fetches run behind the download.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 100));

    test('stores the album\'s artist when the track has its own', () async {
      const song = Song(
        id: 's1',
        serverId: _sid,
        title: 'Song s1',
        albumId: 'al',
        artistId: 'guest',
      );
      await dao.upsertSongs([song], DateTime.utc(2026));
      await storeAlbum('al', artistId: 'various');
      await storeArtist('guest');
      await storeArtist('various');

      await service.cacheSong(song);
      await settle();

      expect(client.artistsAsked.toSet(), {'guest', 'various'});
    });

    test('asks once for an album whose artist is the track\'s', () async {
      const song = Song(
        id: 's1',
        serverId: _sid,
        title: 'Song s1',
        albumId: 'al',
        artistId: 'ar',
      );
      await dao.upsertSongs([song], DateTime.utc(2026));
      await storeAlbum('al', artistId: 'ar');
      await storeArtist('ar');

      await service.cacheSong(song);
      await settle();

      expect(client.artistsAsked, ['ar']);
    });
  });
}
