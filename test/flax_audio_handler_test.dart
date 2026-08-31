import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flax/core/providers/library_provider.dart';
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

  @override
  Stream<List<Artist>> watchArtists() {
    return Stream.value([
      const Artist(
        id: 'art_1',
        serverId: 'srv_1',
        name: 'Daft Punk',
        albumCount: 4,
        coverArtId: 'art_cover_1',
      ),
    ]);
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
    test('returns root navigation categories', () async {
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
          FlaxAudioHandler.kOfflineNode,
        ]),
      );
      expect(root.first.title, equals('Recently Added'));
    });

    test('fetches recently added albums', () async {
      final recent = await handler.getChildren(FlaxAudioHandler.kRecentNode);
      expect(recent.length, equals(1));
      expect(recent.first.id, equals('album_alb_1'));
      expect(recent.first.title, equals('Random Access Memories'));
      expect(recent.first.artist, equals('Daft Punk'));
    });

    test('fetches artists list', () async {
      final artists = await handler.getChildren(FlaxAudioHandler.kArtistsNode);
      expect(artists.length, equals(1));
      expect(artists.first.id, equals('artist_art_1'));
      expect(artists.first.title, equals('Daft Punk'));
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
      expect(tracks.first.title, equals('Get Lucky'));
      expect(tracks.first.duration, equals(const Duration(seconds: 248)));
      expect(tracks.first.playable, isTrue);
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
      expect(playlistTracks.first.title, equals('Get Lucky'));
    });

    test('fetches offline downloaded tracks', () async {
      final offline = await handler.getChildren(FlaxAudioHandler.kOfflineNode);
      expect(offline.length, equals(1));
      expect(offline.first.id, equals('song_song_cached_1'));
      expect(offline.first.title, equals('Instant Crush'));
    });
  });

  group('FlaxAudioHandler getMediaItem', () {
    test('retrieves song media item by id', () async {
      final item = await handler.getMediaItem('song_song_1');
      expect(item, isNotNull);
      expect(item!.id, equals('song_song_1'));
      expect(item.title, equals('Get Lucky'));
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
      expect(item.title, equals('Starboy'));
      expect(item.artist, equals('The Weeknd'));
      expect(item.album, equals('Starboy'));
      expect(item.duration, equals(const Duration(seconds: 230)));
      expect(item.artUri, equals(Uri.parse('https://example.com/art.jpg')));
      expect(item.rating?.hasHeart(), isTrue);
      expect(item.playable, isTrue);
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
      expect(handler.playbackState.value.playing, isTrue);
      expect(
        handler.playbackState.value.updatePosition,
        equals(const Duration(seconds: 45)),
      );
    });
  });
}
