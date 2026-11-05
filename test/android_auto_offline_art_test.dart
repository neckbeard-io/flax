import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/audio/flax_audio_handler.dart';
import 'package:flax/services/audio/media_session_art.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
import 'package:flax/shared/widgets/cover_index.dart';

import 'helpers/fake_cache_info_repository.dart';
import 'helpers/fake_cover_store.dart';

const _sid = 'srv';

const _album = Album(
  id: 'al',
  serverId: _sid,
  name: 'Album',
  artistId: 'ar',
  artistName: 'Artist',
  coverArtId: 'c-album',
);

const _artist = Artist(
  id: 'ar',
  serverId: _sid,
  name: 'Artist',
  coverArtId: 'c-artist',
  starred: true,
);

/// Known only by a photo with its own URL, not a cover id.
const _photoArtist = Artist(
  id: 'ph',
  serverId: _sid,
  name: 'Photo Artist',
  imageUrl: 'https://photos.example.com/ph.jpg',
);

const _song = Song(
  id: 's1',
  serverId: _sid,
  title: 'Song',
  artistName: 'Artist',
  albumId: 'al',
  coverArtId: 'c-album',
);

const _playlist = Playlist(
  id: 'p',
  serverId: _sid,
  name: 'Playlist',
  coverArtId: 'pl-p',
);

class _Repo extends Fake implements LibraryRepository {
  @override
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query}) =>
      Stream.value([_album]);

  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery? query) =>
      Stream.value([_album]);

  @override
  Stream<List<Artist>> watchDownloadedArtists() =>
      Stream.value([_artist, _photoArtist]);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value([_artist, _photoArtist]);

  @override
  Stream<List<Album>> watchDownloadedArtistAlbums(String? artistId) =>
      Stream.value([_album]);

  @override
  Stream<List<Album>> watchArtistAlbums(String? artistId) =>
      Stream.value([_album]);

  @override
  Stream<List<Song>> watchDownloadedAlbumSongs(String? albumId) =>
      Stream.value([_song]);

  @override
  Stream<List<Song>> watchAlbumSongs(String? albumId) => Stream.value([_song]);

  @override
  Stream<List<Playlist>> watchDownloadedPlaylists() =>
      Stream.value([_playlist]);

  @override
  Stream<List<Song>> watchDownloadedPlaylistSongs(String playlistId) =>
      Stream.value([_song]);

  @override
  Stream<List<Song>> watchDownloadedSongSearch(
    String? query, {
    int limit = 20,
  }) => Stream.value([_song]);

  @override
  Stream<Song?> watchSong(String? songId) => Stream.value(_song);

  @override
  Stream<Album?> watchAlbum(String? albumId) => Stream.value(_album);

  @override
  Future<List<Song>> getDownloadedSongs() async => [_song];

  @override
  Future<void> refreshAlbumList(
    AlbumListQuery? query, {
    bool force = false,
  }) async {}

  @override
  Future<void> refreshArtist(String? artistId, {bool force = false}) async {}

  @override
  Future<void> refreshAlbum(String? albumId, {bool force = false}) async {}

  @override
  Future<void> syncAnnotations({bool force = false}) async {}
}

class _Client extends Mock implements SubsonicClient {
  @override
  Future<void> whenTargetChosen() async {}

  @override
  Future<String?> tryPing({Duration? timeout}) async => null;

  @override
  Uri getCoverArtUri(String? id, {int? size}) =>
      Uri.parse('https://music.example.com/rest/getCoverArt?id=$id&size=$size');
}

class _Player extends StateNotifier<PlayerState> implements PlayerNotifier {
  _Player() : super(const PlayerState());

  @override
  Future<void> playTracks(List<Song> songs, {int initialIndex = 0}) async {}

  @override
  Future<void> waitForRestore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late FakeCoverStore covers;
  late ProviderContainer container;
  late FlaxAudioHandler handler;
  late int indexReads;

  Future<CoverIndex> readIndex() {
    indexReads++;
    return CoverIndex.read(
      repo: FakeCacheInfoRepository([
        for (final entry in covers.files.entries)
          coverRow(entry.key, p.basename(entry.value.path)),
      ]),
      directory: dir,
    );
  }

  void goOffline() =>
      container.read(offlineManualOverrideProvider.notifier).set(true);

  bool isRemote(Uri? uri) =>
      uri != null && (uri.isScheme('http') || uri.isScheme('https'));

  /// Every row Android Auto can reach from the root.
  Future<List<MediaItem>> wholeTree() async {
    final seen = <String>{};
    final rows = <MediaItem>[];
    Future<void> walk(String parent, int depth) async {
      if (depth > 6 || !seen.add(parent)) return;
      for (final row in await handler.getChildren(parent)) {
        rows.add(row);
        if (row.playable != true) await walk(row.id, depth + 1);
      }
    }

    await walk(AudioService.browsableRootId, 0);
    return rows;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('car_art');
    covers = FakeCoverStore(const LocalFileSystem().directory(dir.path));
    CoverArtCache.resetForTest();
    indexReads = 0;
    container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(_Repo()),
        subsonicClientProvider.overrideWithValue(_Client()),
        activeServerProvider.overrideWithValue(
          const Server(
            id: _sid,
            name: 'Home',
            url: 'https://music.example.com',
            username: 'driver',
            tokenHash: 'tok',
            salt: 'salt',
          ),
        ),
        artCacheProvider.overrideWithValue(covers),
        coverIndexReaderProvider.overrideWithValue(readIndex),
        playerProvider.overrideWith((ref) => _Player()),
      ],
    );
    handler = FlaxAudioHandler(container, android: true);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  group('offline', () {
    test('no row anywhere in the tree carries a URL', () async {
      goOffline();

      final rows = await wholeTree();

      expect(rows.map((r) => r.id), containsAll(['album_al', 'artist_ar']));
      expect(rows.where((r) => isRemote(r.artUri)).map((r) => r.id), isEmpty);
    });

    test('a row uses its stored cover, at any stored size', () async {
      final file = covers.add(coverCacheKey('c-album', 2048));
      goOffline();

      final row = (await wholeTree()).firstWhere((r) => r.id == 'album_al');

      expect(row.artUri, mediaSessionArtUri(file.path, android: true));
      expect(row.artUri!.isScheme('content'), isTrue);
    });

    test('a cover not on the device gets a placeholder graphic', () async {
      goOffline();

      final rows = await wholeTree();
      String art(String id) =>
          rows.firstWhere((r) => r.id == id).artUri.toString();

      expect(art('album_al'), contains('drawable/ic_album_collection'));
      expect(art('artist_ar'), contains('drawable/ic_artist_avatar'));
      expect(art('playlist_p'), contains('drawable/ic_music_note'));
    });

    test('an artist photo stored under its URL is found', () async {
      final file = covers.add(_photoArtist.imageUrl!);
      goOffline();

      final row = (await wholeTree()).firstWhere((r) => r.id == 'artist_ph');

      expect(row.artUri, mediaSessionArtUri(file.path, android: true));
    });

    test('a photo not stored gets a placeholder, not its URL', () async {
      goOffline();

      final row = (await wholeTree()).firstWhere((r) => r.id == 'artist_ph');

      expect(row.artUri.toString(), contains('drawable/ic_artist_avatar'));
    });

    test('rows survive an unreadable index, still without a URL', () async {
      final broken = ProviderContainer(
        parent: container,
        overrides: [
          coverIndexReaderProvider.overrideWithValue(
            () async => throw StateError('no index'),
          ),
        ],
      );
      addTearDown(broken.dispose);
      broken.read(offlineManualOverrideProvider.notifier).set(true);

      final rows = await FlaxAudioHandler(
        broken,
        android: true,
      ).getChildren(FlaxAudioHandler.kPlaylistsNode);

      expect(rows.single.artUri.toString(), contains('drawable/ic_music_note'));
    });

    test('voice search results carry no URL', () async {
      goOffline();

      final rows = await handler.search('song');

      expect(rows, isNotEmpty);
      expect(rows.where((r) => isRemote(r.artUri)), isEmpty);
    });

    test('the queue carries no URL', () async {
      goOffline();

      handler.updateFromPlayerState(
        const PlayerState(queue: [_song], queueIndex: 0, currentSong: _song),
      );
      expect(
        handler.queue.value.single.artUri.toString(),
        contains('drawable'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(handler.queue.value.where((r) => isRemote(r.artUri)), isEmpty);
    });

    test(
      'the queue picks up the stored cover once the index is read',
      () async {
        final file = covers.add(coverCacheKey('c-album', 512));
        goOffline();

        handler.updateFromPlayerState(
          const PlayerState(queue: [_song], queueIndex: 0, currentSong: _song),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          handler.queue.value.single.artUri,
          mediaSessionArtUri(file.path, android: true),
        );
      },
    );
  });

  group('online', () {
    test('a stored cover still beats asking the server', () async {
      final file = covers.add(coverCacheKey('c-album', 512));

      final rows = await handler.getChildren(FlaxAudioHandler.kRecentNode);

      expect(rows.single.artUri, mediaSessionArtUri(file.path, android: true));
    });

    test('a cover not stored yet comes from the server', () async {
      final rows = await handler.getChildren(FlaxAudioHandler.kArtistsNode);
      final row = rows.firstWhere((r) => r.id == 'artist_ar');

      expect(isRemote(row.artUri), isTrue);
    });

    test('a page of rows reads the index once, and reuses it', () async {
      await handler.getChildren(FlaxAudioHandler.kRecentNode);
      await handler.getChildren(FlaxAudioHandler.kRecentNode);

      expect(indexReads, 1);
    });
  });

  group('Now Playing never gets a server URL on Android', () {
    test('when a track starts', () async {
      await handler.playFromMediaId('song_s1');

      expect(isRemote(handler.mediaItem.value?.artUri), isFalse);
    });

    test('when a track starts, then takes the stored cover', () async {
      final file = covers.add(coverCacheKey('c-album', 768));

      await handler.playFromMediaId('song_s1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        handler.mediaItem.value?.artUri,
        mediaSessionArtUri(file.path, android: true),
      );
    });

    test('when a track is prepared', () async {
      await handler.prepareFromMediaId('song_s1');

      expect(isRemote(handler.mediaItem.value?.artUri), isFalse);
    });

    test('when an album is prepared', () async {
      await handler.prepareFromMediaId('album_al');

      expect(isRemote(handler.mediaItem.value?.artUri), isFalse);
      expect(handler.queue.value.where((r) => isRemote(r.artUri)), isEmpty);
    });
  });
}
