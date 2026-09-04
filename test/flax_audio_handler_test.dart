import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/audio/flax_audio_handler.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

class MockLibraryRepository extends Mock implements LibraryRepository {
  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery? query) {
    return Stream.value([
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
        coverArtId: 'art_1',
        songCount: 13,
        year: 2013,
      ),
    ]);
  }

  List<Artist>? artistsOverride;

  @override
  Future<void> syncAnnotations({bool force = false}) async {}

  @override
  Future<void> refreshArtist(String? artistId, {bool force = false}) async {}

  @override
  Future<void> refreshAlbum(String? albumId, {bool force = false}) async {}

  @override
  Future<void> refreshAlbumList(
    AlbumListQuery? query, {
    bool force = false,
  }) async {}

  @override
  Stream<List<Artist>> watchArtists() {
    return Stream.value(
      artistsOverride ??
          const [
            Artist(
              id: 'art_1',
              serverId: 'srv_1',
              name: 'Daft Punk',
              albumCount: 4,
              coverArtId: 'art_cover_1',
            ),
          ],
    );
  }

  @override
  Stream<List<Album>> watchArtistAlbums(String? artistId) {
    return Stream.value([
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
        coverArtId: 'art_1',
      ),
    ]);
  }

  @override
  Stream<List<Song>> watchAlbumSongs(String? albumId) {
    return Stream.value([
      const Song(
        id: 'song_1',
        serverId: 'srv_1',
        title: 'Get Lucky',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 248,
        coverArtId: 'art_1',
        starred: true,
      ),
    ]);
  }

  @override
  Stream<Song?> watchSong(String? songId) {
    return Stream.value(
      const Song(
        id: 'song_1',
        serverId: 'srv_1',
        title: 'Get Lucky',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 248,
        coverArtId: 'art_1',
        starred: true,
      ),
    );
  }

  @override
  Stream<Album?> watchAlbum(String? albumId) {
    return Stream.value(
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
      ),
    );
  }

  @override
  Stream<Artist?> watchArtist(String? artistId) {
    return Stream.value(
      const Artist(id: 'art_1', serverId: 'srv_1', name: 'Daft Punk'),
    );
  }

  @override
  Future<List<Song>> getDownloadedSongs() async {
    return [
      const Song(
        id: 'song_cached_1',
        serverId: 'srv_1',
        title: 'Instant Crush',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 337,
      ),
    ];
  }

  @override
  Stream<List<Song>> watchSongSearch(String? query, {int limit = 20}) {
    return Stream.value([
      const Song(
        id: 'song_1',
        serverId: 'srv_1',
        title: 'Get Lucky',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 248,
      ),
    ]);
  }

  @override
  Stream<List<Album>> watchAlbumSearch(String? query, {int limit = 20}) {
    return Stream.value([
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
      ),
    ]);
  }

  @override
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query}) {
    return Stream.value([
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
      ),
    ]);
  }

  @override
  Stream<List<Artist>> watchDownloadedArtists() {
    return Stream.value(
      artistsOverride ??
          const [
            Artist(
              id: 'art_1',
              serverId: 'srv_1',
              name: 'Daft Punk',
              albumCount: 4,
              coverArtId: 'art_cover_1',
            ),
          ],
    );
  }

  @override
  Stream<List<Album>> watchDownloadedArtistAlbums(String? artistId) {
    return Stream.value([
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
        coverArtId: 'art_1',
      ),
    ]);
  }

  @override
  Stream<List<Song>> watchDownloadedAlbumSongs(String? albumId) {
    return Stream.value([
      const Song(
        id: 'song_1',
        serverId: 'srv_1',
        title: 'Get Lucky',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 248,
        coverArtId: 'art_1',
        starred: true,
      ),
    ]);
  }

  @override
  Stream<List<Song>> watchDownloadedSongSearch(
    String? query, {
    int limit = 20,
  }) {
    return Stream.value([
      const Song(
        id: 'song_cached_1',
        serverId: 'srv_1',
        title: 'Instant Crush',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 337,
      ),
    ]);
  }
}

class MockSubsonicClient extends Mock implements SubsonicClient {
  @override
  Uri getCoverArtUri(String? id, {int? size}) {
    return Uri.parse(
      'https://music.example.com/rest/getCoverArt?id=$id&size=$size',
    );
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    return [
      const Playlist(
        id: 'pl_1',
        serverId: 'srv_1',
        name: 'Driving Mix',
        songCount: 42,
        duration: 7200,
      ),
    ];
  }

  @override
  Future<List<Song>> getPlaylistSongs(String? playlistId) async {
    return [
      const Song(
        id: 'song_1',
        serverId: 'srv_1',
        title: 'Get Lucky',
        artistName: 'Daft Punk',
        albumName: 'Random Access Memories',
        duration: 248,
      ),
    ];
  }

  @override
  Future<SearchResult> getStarred() async {
    return const SearchResult();
  }

  @override
  Future<List<Album>> getAlbumList(
    AlbumListType? type, {
    int? count,
    int? offset,
    String? genre,
    int? fromYear,
    int? toYear,
  }) async {
    return [
      const Album(
        id: 'alb_1',
        serverId: 'srv_1',
        name: 'Random Access Memories',
        artistName: 'Daft Punk',
        coverArtId: 'art_1',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockLibraryRepository mockRepo;
  late MockSubsonicClient mockClient;
  late FlaxAudioHandler handler;

  setUp(() {
    mockRepo = MockLibraryRepository();
    mockClient = MockSubsonicClient();

    container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(mockRepo),
        subsonicClientProvider.overrideWithValue(mockClient),
        activeServerProvider.overrideWithValue(
          const Server(
            id: 'srv_1',
            name: 'Home Server',
            url: 'https://music.example.com',
            username: 'driver',
            tokenHash: 'tok',
            salt: 'salt',
          ),
        ),
      ],
    );

    handler = FlaxAudioHandler(container);
  });

  tearDown(() {
    container.dispose();
  });

  group('FlaxAudioHandler Android Auto Browse Tree', () {
    test('returns root navigation categories including mode toggle', () async {
      final root = await handler.getChildren(AudioService.browsableRootId);
      expect(root.length, equals(6));
      expect(
        root.map((e) => e.id),
        containsAll([
          FlaxAudioHandler.kRecentNode,
          FlaxAudioHandler.kArtistsNode,
          FlaxAudioHandler.kAlbumsNode,
          FlaxAudioHandler.kPlaylistsNode,
          FlaxAudioHandler.kFavoritesNode,
          'toggle_offline_mode',
        ]),
      );
      expect(root.first.title, equals('Recently Added'));
    });

    test('fetches recently added albums', () async {
      final recentSection = await handler.getChildren(
        'albums_section_recentlyAdded',
      );
      expect(recentSection.length, equals(1));
      expect(recentSection.first.title, equals('Random Access Memories'));
    });

    test('returns standard sections under albums node', () async {
      final sections = await handler.getChildren(FlaxAudioHandler.kAlbumsNode);
      expect(sections.length, equals(8));
      expect(
        sections.map((s) => s.id),
        containsAll([
          'albums_section_all',
          'albums_section_recentlyAdded',
          'albums_section_recentlyPlayed',
          'albums_section_random',
          'albums_section_mostPlayed',
          'albums_section_favorites',
          'albums_section_topRated',
          'albums_section_downloaded',
        ]),
      );
      expect(sections.first.title, equals('All'));

      final albums = await handler.getChildren('albums_section_recentlyAdded');
      expect(albums.length, equals(1));
      expect(albums.first.id, equals('album_alb_1'));
      expect(albums.first.title, equals('Random Access Memories'));
    });

    test('fetches artists list', () async {
      final artists = await handler.getChildren(FlaxAudioHandler.kArtistsNode);
      expect(artists.length, equals(1));
      expect(artists.first.id, equals('artist_art_1'));
      expect(artists.first.title, equals('Daft Punk'));
    });

    test('groups artists by A-Z letter index when count exceeds 60', () async {
      mockRepo.artistsOverride = List.generate(
        70,
        (i) => Artist(
          id: 'art_$i',
          serverId: 'srv_1',
          name: i < 35 ? 'Artist A$i' : 'Band B$i',
          albumCount: 1,
          starred: i == 0,
        ),
      );

      final categories = await handler.getChildren(
        FlaxAudioHandler.kArtistsNode,
      );
      expect(categories.length, equals(3));
      expect(categories[0].id, equals('artists_starred'));
      expect(categories[1].id, equals('artists_letter_A'));
      expect(categories[2].id, equals('artists_letter_B'));

      final letterA = await handler.getChildren('artists_letter_A');
      expect(letterA.length, equals(35));
      expect(letterA.first.title, equals('Artist A0'));
    });

    test('fetches albums by artist', () async {
      final albums = await handler.getChildren('artist_art_1');
      expect(albums.length, equals(1));
      expect(albums.first.id, equals('album_alb_1'));
      expect(albums.first.title, equals('Random Access Memories'));
    });

    test('fetches album tracks', () async {
      final tracks = await handler.getChildren('album_alb_1');
      expect(tracks.length, equals(1));
      expect(tracks.first.id, equals('song_song_1'));
      expect(tracks.first.title, equals('Get Lucky · Daft Punk'));
      expect(tracks.first.artist, equals('Daft Punk'));
    });

    test('fetches playlists and playlist tracks', () async {
      final playlists = await handler.getChildren(
        FlaxAudioHandler.kPlaylistsNode,
      );
      expect(playlists.length, equals(1));
      expect(playlists.first.id, equals('playlist_pl_1'));
      expect(playlists.first.title, equals('Driving Mix'));

      final playlistTracks = await handler.getChildren('playlist_pl_1');
      expect(playlistTracks.length, equals(1));
      expect(playlistTracks.first.title, equals('Get Lucky · Daft Punk'));
    });

    test('fetches offline downloaded tracks', () async {
      final offline = await handler.getChildren(FlaxAudioHandler.kOfflineNode);
      expect(offline.length, equals(1));
      expect(offline.first.id, equals('song_song_cached_1'));
      expect(offline.first.title, equals('Instant Crush · Daft Punk'));
    });

    test(
      'filters browse tree into downloaded views when offline mode is active',
      () async {
        container.read(offlineManualOverrideProvider.notifier).set(true);

        final root = await handler.getChildren(AudioService.browsableRootId);
        final toggleItem = root.firstWhere(
          (e) => e.id == 'toggle_offline_mode',
        );
        expect(toggleItem.title, contains('Offline'));

        final albums = await handler.getChildren(FlaxAudioHandler.kAlbumsNode);
        expect(
          albums.map((s) => s.id),
          containsAll([
            'albums_section_all',
            'albums_section_recentlyAdded',
            'albums_section_favorites',
          ]),
        );

        final artists = await handler.getChildren(
          FlaxAudioHandler.kArtistsNode,
        );
        expect(artists.length, equals(1));
        expect(artists.first.title, equals('Daft Punk'));

        final recent = await handler.getChildren(FlaxAudioHandler.kRecentNode);
        expect(recent.length, equals(1));
        expect(recent.first.title, equals('Random Access Memories'));
      },
    );

    test('auto-offline on Android Auto setting filters browse tree', () async {
      container.read(offlineOnAndroidAutoSettingProvider.notifier).set(true);

      final root = await handler.getChildren(AudioService.browsableRootId);
      final toggleItem = root.firstWhere((e) => e.id == 'toggle_offline_mode');
      expect(toggleItem.title, contains('Offline'));

      final tracks = await handler.getChildren('album_alb_1');
      expect(tracks.first.title, equals('Get Lucky · Daft Punk'));
    });
  });

  group('FlaxAudioHandler getMediaItem', () {
    test('retrieves song media item by id', () async {
      final item = await handler.getMediaItem('song_song_1');
      expect(item, isNotNull);
      expect(item!.id, equals('song_song_1'));
      expect(item.title, equals('Get Lucky · Daft Punk'));
      expect(item.artist, equals('Daft Punk'));
      expect(item.rating?.hasHeart(), isTrue);
    });

    test('retrieves album media item by id', () async {
      final item = await handler.getMediaItem('album_alb_1');
      expect(item, isNotNull);
      expect(item!.id, equals('album_alb_1'));
      expect(item.title, equals('Random Access Memories'));
    });
  });

  group('FlaxAudioHandler Model Converters', () {
    test('converts Song to MediaItem with heart rating', () {
      const song = Song(
        id: 's123',
        serverId: 'srv_1',
        title: 'Starboy',
        artistName: 'The Weeknd',
        albumName: 'Starboy',
        duration: 230,
        starred: true,
      );

      final item = FlaxAudioHandler.songToMediaItem(
        song,
        coverArtUrl: 'https://example.com/art.jpg',
      );

      expect(item.id, equals('song_s123'));
      expect(item.title, equals('Starboy · The Weeknd'));
      expect(item.displayTitle, equals('Starboy · The Weeknd'));
      expect(item.artist, equals('The Weeknd'));
      expect(item.album, equals('Starboy'));
      expect(item.duration, equals(const Duration(seconds: 230)));
      expect(item.artUri, equals(Uri.parse('https://example.com/art.jpg')));
      expect(item.rating?.hasHeart(), isTrue);
      expect(item.playable, isTrue);

      final nowPlayingItem = FlaxAudioHandler.songToMediaItem(
        song,
        coverArtUrl: 'https://example.com/art.jpg',
        forNowPlaying: true,
      );
      expect(nowPlayingItem.title, equals('Starboy'));
      expect(nowPlayingItem.displayTitle, equals('Starboy'));
    });
  });

  group('FlaxAudioHandler State Updates', () {
    test('updates playbackState, mediaItem, and queue from PlayerState', () {
      const currentSong = Song(
        id: 'song_active',
        serverId: 'srv_1',
        title: 'Harder, Better, Faster, Stronger',
        artistName: 'Daft Punk',
        albumName: 'Discovery',
        duration: 224,
      );

      final state = PlayerState(
        currentSong: currentSong,
        queue: const [currentSong],
        queueIndex: 0,
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(seconds: 224),
      );

      handler.updateFromPlayerState(state);

      expect(handler.mediaItem.value, isNotNull);
      expect(
        handler.mediaItem.value!.title,
        equals('Harder, Better, Faster, Stronger'),
      );
      expect(handler.queue.value.length, equals(1));
      expect(
        handler.queue.value.first.title,
        equals('Harder, Better, Faster, Stronger · Daft Punk'),
      );
      expect(handler.playbackState.value.playing, isTrue);
      expect(
        handler.playbackState.value.updatePosition,
        equals(const Duration(seconds: 45)),
      );
      expect(
        handler.playbackState.value.controls.any(
          (c) => c.customAction?.name == 'toggleFavorite',
        ),
        isTrue,
      );
    });
  });
}
