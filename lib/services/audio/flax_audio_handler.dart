import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// Android Auto & background media session handler for Flax.
///
/// Implements Android `MediaBrowserServiceCompat` to provide the vehicle
/// dashboard with a browse tree (Recent, Artists, Albums, Playlists, Favorites,
/// Offline) and integrates transport controls with [PlayerNotifier].
class FlaxAudioHandler extends BaseAudioHandler {
  final ProviderContainer _container;

  // Root category node identifiers for Android Auto
  static const String kRootId = 'flax_root';
  static const String kRecentNode = 'recent';
  static const String kArtistsNode = 'artists';
  static const String kAlbumsNode = 'albums';
  static const String kPlaylistsNode = 'playlists';
  static const String kFavoritesNode = 'favorites';
  static const String kOfflineNode = 'offline';

  FlaxAudioHandler(this._container) {
    _init();
  }

  void _init() {
    AppLogger.i('AudioHandler', 'FlaxAudioHandler initialized');
    playbackState.add(
      _buildPlaybackState(
        isPlaying: false,
        position: Duration.zero,
        buffering: false,
      ),
    );
  }

  LibraryRepository? get _library => _container.read(libraryRepositoryProvider);
  SubsonicClient? get _client => _container.read(subsonicClientProvider);
  PlayerNotifier get _player => _container.read(playerProvider.notifier);

  /// Synchronizes playback state from [PlayerNotifier] to the car media session.
  void updateFromPlayerState(PlayerState state) {
    final song = state.currentSong;
    final client = _client;

    if (song != null) {
      final artUrl = client != null && song.coverArtId != null
          ? client.getCoverArtUri(song.coverArtId!, size: 600).toString()
          : null;

      final item = songToMediaItem(song, coverArtUrl: artUrl);
      if (mediaItem.value?.id != item.id) {
        mediaItem.add(item);
      }
    } else {
      if (mediaItem.value != null) {
        mediaItem.add(null);
      }
    }

    // Map queue
    final queueItems = state.queue.map((s) {
      final artUrl = client != null && s.coverArtId != null
          ? client.getCoverArtUri(s.coverArtId!, size: 300).toString()
          : null;
      return songToMediaItem(s, coverArtUrl: artUrl);
    }).toList();
    queue.add(queueItems);

    playbackState.add(
      _buildPlaybackState(
        isPlaying: state.isPlaying,
        position: state.position,
        buffering: state.buffering,
        queueIndex: state.queueIndex,
        shuffle: state.shuffle,
        repeatMode: state.repeatMode,
        starred: song?.starred ?? false,
      ),
    );
  }

  PlaybackState _buildPlaybackState({
    required bool isPlaying,
    required Duration position,
    required bool buffering,
    int? queueIndex,
    bool shuffle = false,
    RepeatMode repeatMode = RepeatMode.off,
    bool starred = false,
  }) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: buffering
          ? AudioProcessingState.buffering
          : (isPlaying
                ? AudioProcessingState.ready
                : AudioProcessingState.idle),
      playing: isPlaying,
      updatePosition: position,
      bufferedPosition: position,
      speed: 1.0,
      queueIndex: queueIndex,
      shuffleMode: shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: repeatMode == RepeatMode.one
          ? AudioServiceRepeatMode.one
          : (repeatMode == RepeatMode.all
                ? AudioServiceRepeatMode.all
                : AudioServiceRepeatMode.none),
    );
  }

  // ── Android Auto MediaBrowserService Hierarchy ─────────────────────────────

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    AppLogger.d('AudioHandler', 'getChildren parentMediaId: $parentMediaId');
    final library = _library;
    final client = _client;

    if (library == null || client == null) {
      return const [];
    }

    try {
      if (parentMediaId == AudioService.browsableRootId ||
          parentMediaId == kRootId ||
          parentMediaId == '/' ||
          parentMediaId.isEmpty) {
        return _getRootCategories();
      }

      switch (parentMediaId) {
        case kRecentNode:
          final albums = await library
              .watchAlbumList(const AlbumListQuery(AlbumListType.newest))
              .first;
          return albums
              .take(30)
              .map((a) => albumToMediaItem(a, client))
              .toList();

        case kArtistsNode:
          final artists = await library.watchArtists().first;
          return artists.map((a) => artistToMediaItem(a, client)).toList();

        case kAlbumsNode:
          final albums = await library
              .watchAlbumList(
                const AlbumListQuery(AlbumListType.alphabeticalByName),
              )
              .first;
          return albums
              .take(50)
              .map((a) => albumToMediaItem(a, client))
              .toList();

        case kPlaylistsNode:
          final playlists = await client.getPlaylists();
          return playlists.map((p) => playlistToMediaItem(p)).toList();

        case kFavoritesNode:
          final starredAlbums = await library
              .watchAlbumList(const AlbumListQuery(AlbumListType.starred))
              .first;
          return starredAlbums.map((a) => albumToMediaItem(a, client)).toList();

        case kOfflineNode:
          final downloadedSongs = await library.getDownloadedSongs();
          return downloadedSongs
              .map(
                (s) => songToMediaItem(
                  s,
                  coverArtUrl: s.coverArtId != null
                      ? client
                            .getCoverArtUri(s.coverArtId!, size: 300)
                            .toString()
                      : null,
                ),
              )
              .toList();
      }

      // Dynamic sub-nodes (artist_{id}, album_{id}, playlist_{id})
      if (parentMediaId.startsWith('artist_')) {
        final artistId = parentMediaId.substring(7);
        final albums = await library.watchArtistAlbums(artistId).first;
        return albums.map((a) => albumToMediaItem(a, client)).toList();
      }

      if (parentMediaId.startsWith('album_')) {
        final albumId = parentMediaId.substring(6);
        final songs = await library.watchAlbumSongs(albumId).first;
        return songs
            .map(
              (s) => songToMediaItem(
                s,
                coverArtUrl: s.coverArtId != null
                    ? client.getCoverArtUri(s.coverArtId!, size: 300).toString()
                    : null,
              ),
            )
            .toList();
      }

      if (parentMediaId.startsWith('playlist_')) {
        final playlistId = parentMediaId.substring(9);
        final songs = await client.getPlaylistSongs(playlistId);
        return songs
            .map(
              (s) => songToMediaItem(
                s,
                coverArtUrl: s.coverArtId != null
                    ? client.getCoverArtUri(s.coverArtId!, size: 300).toString()
                    : null,
              ),
            )
            .toList();
      }
    } catch (e, st) {
      AppLogger.e(
        'AudioHandler',
        'Error in getChildren for $parentMediaId',
        error: e,
        stackTrace: st,
      );
    }

    return const [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final client = _client;
    final library = _library;
    if (client == null || library == null) return null;

    if (mediaId.startsWith('song_')) {
      final songId = mediaId.substring(5);
      final song = await library.watchSong(songId).first;
      if (song != null) {
        return songToMediaItem(
          song,
          coverArtUrl: song.coverArtId != null
              ? client.getCoverArtUri(song.coverArtId!, size: 300).toString()
              : null,
        );
      }
    } else if (mediaId.startsWith('album_')) {
      final albumId = mediaId.substring(6);
      final album = await library.watchAlbum(albumId).first;
      if (album != null) {
        return albumToMediaItem(album, client);
      }
    } else if (mediaId.startsWith('artist_')) {
      final artistId = mediaId.substring(7);
      final artist = await library.watchArtist(artistId).first;
      if (artist != null) {
        return artistToMediaItem(artist, client);
      }
    }

    return null;
  }

  List<MediaItem> _getRootCategories() {
    return const [
      MediaItem(id: kRecentNode, title: 'Recently Added', playable: false),
      MediaItem(id: kArtistsNode, title: 'Artists', playable: false),
      MediaItem(id: kAlbumsNode, title: 'Albums', playable: false),
      MediaItem(id: kPlaylistsNode, title: 'Playlists', playable: false),
      MediaItem(id: kFavoritesNode, title: 'Favorites', playable: false),
      MediaItem(
        id: kOfflineNode,
        title: 'Downloaded / Offline',
        playable: false,
      ),
    ];
  }

  // ── Playback & Selection Triggers ──────────────────────────────────────────

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    await playFromMediaId(mediaItem.id);
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    AppLogger.i('AudioHandler', 'playFromMediaId: $mediaId');
    final library = _library;
    final client = _client;
    if (library == null) return;

    try {
      if (mediaId.startsWith('song_')) {
        final songId = mediaId.substring(5);
        final song = await library.watchSong(songId).first;
        if (song != null) {
          if (song.albumId != null) {
            final albumSongs = await library
                .watchAlbumSongs(song.albumId!)
                .first;
            final idx = albumSongs.indexWhere((s) => s.id == song.id);
            await _player.playTracks(
              albumSongs,
              initialIndex: idx >= 0 ? idx : 0,
            );
          } else {
            await _player.playTracks([song], initialIndex: 0);
          }
        }
      } else if (mediaId.startsWith('album_')) {
        final albumId = mediaId.substring(6);
        final songs = await library.watchAlbumSongs(albumId).first;
        if (songs.isNotEmpty) {
          await _player.playTracks(songs, initialIndex: 0);
        }
      } else if (mediaId.startsWith('artist_')) {
        final artistId = mediaId.substring(7);
        final albums = await library.watchArtistAlbums(artistId).first;
        if (albums.isNotEmpty) {
          final firstAlbumSongs = await library
              .watchAlbumSongs(albums.first.id)
              .first;
          if (firstAlbumSongs.isNotEmpty) {
            await _player.playTracks(firstAlbumSongs, initialIndex: 0);
          }
        }
      } else if (mediaId.startsWith('playlist_')) {
        final playlistId = mediaId.substring(9);
        if (client != null) {
          final songs = await client.getPlaylistSongs(playlistId);
          if (songs.isNotEmpty) {
            await _player.playTracks(songs, initialIndex: 0);
          }
        }
      } else if (mediaId == kFavoritesNode) {
        final starredAlbums = await library
            .watchAlbumList(const AlbumListQuery(AlbumListType.starred))
            .first;
        if (starredAlbums.isNotEmpty) {
          final songs = await library
              .watchAlbumSongs(starredAlbums.first.id)
              .first;
          if (songs.isNotEmpty) {
            await _player.playTracks(songs, initialIndex: 0);
          }
        }
      } else if (mediaId == kOfflineNode) {
        final downloadedSongs = await library.getDownloadedSongs();
        if (downloadedSongs.isNotEmpty) {
          await _player.playTracks(downloadedSongs, initialIndex: 0);
        }
      }
    } catch (e, st) {
      AppLogger.e(
        'AudioHandler',
        'Failed to play from mediaId $mediaId',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    AppLogger.i('AudioHandler', 'Voice/Text search query: $query');
    final library = _library;
    final client = _client;
    if (library == null || client == null || query.trim().isEmpty)
      return const [];

    try {
      final matchingSongs = await library
          .watchSongSearch(query, limit: 20)
          .first;
      if (matchingSongs.isNotEmpty) {
        await _player.playTracks(matchingSongs, initialIndex: 0);
        return matchingSongs
            .map(
              (s) => songToMediaItem(
                s,
                coverArtUrl: s.coverArtId != null
                    ? client.getCoverArtUri(s.coverArtId!, size: 300).toString()
                    : null,
              ),
            )
            .toList();
      }

      final matchingAlbums = await library
          .watchAlbumSearch(query, limit: 5)
          .first;
      if (matchingAlbums.isNotEmpty) {
        final songs = await library
            .watchAlbumSongs(matchingAlbums.first.id)
            .first;
        if (songs.isNotEmpty) {
          await _player.playTracks(songs, initialIndex: 0);
          return matchingAlbums
              .map((a) => albumToMediaItem(a, client))
              .toList();
        }
      }
    } catch (e, st) {
      AppLogger.e(
        'AudioHandler',
        'Search playback failed for $query',
        error: e,
        stackTrace: st,
      );
    }
    return const [];
  }

  // ── Transport Controls ─────────────────────────────────────────────────────

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async => _player.pause();

  @override
  Future<void> skipToNext() async => _player.next();

  @override
  Future<void> skipToPrevious() async => _player.previous();

  @override
  Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async => _player.playTrackAt(index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shouldShuffle =
        shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    if (_container.read(playerProvider).shuffle != shouldShuffle) {
      _player.toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final targetMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => RepeatMode.all,
      _ => RepeatMode.off,
    };
    _player.setRepeatMode(targetMode);
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'toggleFavorite') {
      await _player.toggleCurrentSongStarred();
    }
    return super.customAction(name, extras);
  }

  // ── Converters ─────────────────────────────────────────────────────────────

  static MediaItem songToMediaItem(Song song, {String? coverArtUrl}) {
    return MediaItem(
      id: 'song_${song.id}',
      album: song.albumName ?? '',
      title: song.title,
      artist: song.artistName ?? '',
      duration: Duration(seconds: song.duration),
      artUri: coverArtUrl != null ? Uri.tryParse(coverArtUrl) : null,
      playable: true,
      rating: song.starred
          ? const Rating.newHeartRating(true)
          : const Rating.newHeartRating(false),
      extras: {
        'songId': song.id,
        'serverId': song.serverId,
        'albumId': song.albumId,
        'artistId': song.artistId,
        'track': song.track,
        'starred': song.starred,
      },
    );
  }

  static MediaItem albumToMediaItem(Album album, SubsonicClient client) {
    final coverUrl = album.coverArtId != null
        ? client.getCoverArtUri(album.coverArtId!, size: 300).toString()
        : null;

    return MediaItem(
      id: 'album_${album.id}',
      album: album.name,
      title: album.name,
      artist: album.artistName ?? '',
      artUri: coverUrl != null ? Uri.tryParse(coverUrl) : null,
      playable: true,
      extras: {
        'albumId': album.id,
        'songCount': album.songCount,
        'year': album.year,
      },
    );
  }

  static MediaItem artistToMediaItem(Artist artist, SubsonicClient client) {
    final coverUrl = artist.coverArtId != null
        ? client.getCoverArtUri(artist.coverArtId!, size: 300).toString()
        : null;

    return MediaItem(
      id: 'artist_${artist.id}',
      title: artist.name,
      artist: artist.name,
      artUri: coverUrl != null ? Uri.tryParse(coverUrl) : null,
      playable: true,
      extras: {'artistId': artist.id, 'albumCount': artist.albumCount},
    );
  }

  static MediaItem playlistToMediaItem(Playlist playlist) {
    return MediaItem(
      id: 'playlist_${playlist.id}',
      title: playlist.name,
      playable: true,
      extras: {
        'playlistId': playlist.id,
        'songCount': playlist.songCount,
        'duration': playlist.duration,
      },
    );
  }
}
