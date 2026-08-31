import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:collection/collection.dart';
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

  // Vector icon resources for Android Auto containers and fallbacks
  static final Uri _icMusicNote = Uri.parse(
    'android.resource://com.flaxplayer.flax/drawable/ic_music_note',
  );
  static final Uri _icFavoriteHeart = Uri.parse(
    'android.resource://com.flaxplayer.flax/drawable/ic_favorite_heart',
  );
  static final Uri _icStarRating = Uri.parse(
    'android.resource://com.flaxplayer.flax/drawable/ic_star_rating',
  );
  static final Uri _icAlbumCollection = Uri.parse(
    'android.resource://com.flaxplayer.flax/drawable/ic_album_collection',
  );
  static final Uri _icArtistAvatar = Uri.parse(
    'android.resource://com.flaxplayer.flax/drawable/ic_artist_avatar',
  );

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
        hasSong: false,
        position: Duration.zero,
        buffering: false,
      ),
    );
    try {
      _library?.syncAnnotations(force: true);
    } catch (_) {}
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

      final item = songToMediaItem(
        song,
        coverArtUrl: artUrl,
        forNowPlaying: true,
      );
      if (mediaItem.value?.id != item.id ||
          mediaItem.value?.rating != item.rating) {
        mediaItem.add(item);
      }
    } else {
      if (mediaItem.value != null) {
        mediaItem.add(null);
      }
    }

    // Map queue only when queue structure actually changes to avoid IPC thrashing on seek
    final currentQueueIds = queue.value.map((m) => m.id).toList();
    final newQueueIds = state.queue.map((s) => 'song_${s.id}').toList();
    if (!const ListEquality().equals(currentQueueIds, newQueueIds)) {
      final queueItems = state.queue.map((s) {
        final artUrl = client != null && s.coverArtId != null
            ? client.getCoverArtUri(s.coverArtId!, size: 300).toString()
            : null;
        return songToMediaItem(s, coverArtUrl: artUrl);
      }).toList();
      queue.add(queueItems);
    }

    playbackState.add(
      _buildPlaybackState(
        isPlaying: state.isPlaying,
        hasSong: song != null,
        position: state.position,
        buffering: state.buffering,
        queueIndex: state.queueIndex,
        shuffle: state.shuffle,
        repeatMode: state.repeatMode,
        starred: song?.starred ?? false,
      ),
    );
  }

  static const _actionToggleFavorite = 'toggleFavorite';
  static const _actionToggleShuffle = 'toggleShuffle';

  PlaybackState _buildPlaybackState({
    required bool isPlaying,
    required bool hasSong,
    required Duration position,
    required bool buffering,
    int? queueIndex,
    bool shuffle = false,
    RepeatMode repeatMode = RepeatMode.off,
    bool starred = false,
  }) {
    final customControls = <MediaControl>[
      if (hasSong)
        MediaControl.custom(
          androidIcon: starred
              ? 'drawable/ic_action_favorite_filled'
              : 'drawable/ic_action_favorite_border',
          label: starred ? 'Favorite' : 'Add to Favorites',
          name: _actionToggleFavorite,
        ),
      if (hasSong)
        MediaControl.custom(
          androidIcon: shuffle
              ? 'drawable/ic_action_shuffle_on'
              : 'drawable/ic_action_shuffle_off',
          label: shuffle ? 'Shuffle On' : 'Shuffle Off',
          name: _actionToggleShuffle,
        ),
    ];

    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        ...customControls,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
        MediaAction.custom,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: buffering
          ? AudioProcessingState.buffering
          : (hasSong ? AudioProcessingState.ready : AudioProcessingState.idle),
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
          var albums = await library
              .watchAlbumList(const AlbumListQuery(AlbumListType.newest))
              .first;
          if (albums.isEmpty) {
            try {
              await library.refreshAlbumList(
                const AlbumListQuery(AlbumListType.newest),
              );
              albums = await library
                  .watchAlbumList(const AlbumListQuery(AlbumListType.newest))
                  .first;
            } catch (e) {
              AppLogger.w(
                'AudioHandler',
                'refreshAlbumList(newest) failed: $e',
              );
            }
          }
          if (albums.isEmpty) {
            try {
              albums = await client.getAlbumList(
                AlbumListType.newest,
                count: 30,
              );
            } catch (e) {
              AppLogger.e(
                'AudioHandler',
                'client.getAlbumList(newest) failed: $e',
              );
            }
          }
          return albums
              .take(30)
              .map((a) => albumToMediaItem(a, client))
              .toList();

        case kArtistsNode:
          try {
            await library.syncAnnotations(force: true);
          } catch (e) {
            AppLogger.w('AudioHandler', 'syncAnnotations failed: $e');
          }

          var artists = await library.watchArtists().first;
          if (artists.isEmpty) {
            try {
              await library.refreshArtists();
              artists = await library.watchArtists().first;
            } catch (e) {
              AppLogger.w('AudioHandler', 'refreshArtists failed: $e');
            }
          }
          if (artists.isEmpty) {
            try {
              artists = await client.getArtists();
            } catch (e) {
              AppLogger.e('AudioHandler', 'client.getArtists failed: $e');
            }
          }

          var starredArtists = artists.where((a) => a.starred).toList();
          if (starredArtists.isEmpty) {
            try {
              final res = await client.getStarred();
              if (res.artists.isNotEmpty) {
                starredArtists = res.artists;
              }
            } catch (_) {}
          }

          if (artists.length <= 60) {
            AppLogger.i(
              'AudioHandler',
              'kArtistsNode (<=60): returning ${artists.length} items',
            );
            return artists.map((a) => artistToMediaItem(a, client)).toList();
          }

          // If library has many artists (> 60), group by A-Z index to stay safely
          // under Android's 1MB Binder IPC transaction limit and avoid driver distraction.
          final items = <MediaItem>[];

          final firstStarred = starredArtists.isNotEmpty
              ? starredArtists.first
              : null;
          final starredArtUri = firstStarred?.coverArtId != null
              ? client.getCoverArtUri(firstStarred!.coverArtId!, size: 400)
              : (firstStarred?.imageUrl != null
                    ? Uri.tryParse(firstStarred!.imageUrl!)
                    : _icFavoriteHeart);

          // ALWAYS show Favorite Artists at the top of the Artists tab
          items.add(
            MediaItem(
              id: 'artists_starred',
              title: '❤️ Favorite Artists',
              displayTitle: '❤️ Favorite Artists',
              displaySubtitle: starredArtists.isNotEmpty
                  ? '${starredArtists.length} ${starredArtists.length == 1 ? 'artist' : 'artists'}'
                  : '0 artists',
              artUri: starredArtUri,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
          );

          final letterCounts = <String, int>{};
          for (final a in artists) {
            final name = (a.sortName ?? a.name).trim();
            final char = name.isNotEmpty ? name[0].toUpperCase() : '#';
            final key = RegExp(r'[A-Z]').hasMatch(char) ? char : '#';
            letterCounts[key] = (letterCounts[key] ?? 0) + 1;
          }

          final sortedKeys = letterCounts.keys.toList()
            ..sort((a, b) {
              if (a == '#') return 1;
              if (b == '#') return -1;
              return a.compareTo(b);
            });

          for (final letter in sortedKeys) {
            final count = letterCounts[letter]!;
            final firstArtistInLetter = artists.firstWhereOrNull((a) {
              final name = (a.sortName ?? a.name).trim();
              if (name.isEmpty) return letter == '#';
              final char = name[0].toUpperCase();
              if (letter == '#') return !RegExp(r'[A-Z]').hasMatch(char);
              return char == letter;
            });
            final letterArtUri = firstArtistInLetter?.coverArtId != null
                ? client.getCoverArtUri(
                    firstArtistInLetter!.coverArtId!,
                    size: 400,
                  )
                : (firstArtistInLetter?.imageUrl != null
                      ? Uri.tryParse(firstArtistInLetter!.imageUrl!)
                      : _icArtistAvatar);

            items.add(
              MediaItem(
                id: 'artists_letter_$letter',
                title: letter,
                displayTitle: letter,
                displaySubtitle: '$count ${count == 1 ? 'artist' : 'artists'}',
                artUri: letterArtUri,
                playable: false,
                extras: const {
                  AndroidContentStyle.browsableHintKey:
                      AndroidContentStyle.gridItemHintValue,
                },
              ),
            );
          }

          AppLogger.i(
            'AudioHandler',
            'kArtistsNode (>60): returning ${items.length} letter/favorite categories',
          );
          return items;

        case kAlbumsNode:
          Future<Uri?> getLeadArt(AlbumListType type, {Uri? fallback}) async {
            final query = AlbumListQuery(type);
            var list = await library.watchAlbumList(query).first;
            if (list.isEmpty && query.isCacheable) {
              try {
                await library.refreshAlbumList(query);
                list = await library.watchAlbumList(query).first;
              } catch (_) {}
            }
            if (list.isEmpty) {
              try {
                list = await client.getAlbumList(type, count: 10);
              } catch (_) {}
            }
            for (final a in list) {
              if (a.coverArtId != null) {
                return client.getCoverArtUri(a.coverArtId!, size: 400);
              }
            }
            return fallback;
          }

          final leadArts = await Future.wait([
            getLeadArt(
              AlbumListType.alphabeticalByName,
              fallback: _icAlbumCollection,
            ),
            getLeadArt(AlbumListType.newest, fallback: _icMusicNote),
            getLeadArt(AlbumListType.recent, fallback: _icMusicNote),
            getLeadArt(AlbumListType.random, fallback: _icAlbumCollection),
            getLeadArt(AlbumListType.frequent, fallback: _icMusicNote),
            getLeadArt(AlbumListType.starred, fallback: _icFavoriteHeart),
            getLeadArt(AlbumListType.highest, fallback: _icStarRating),
          ]);

          final allArt = leadArts[0] ?? _icAlbumCollection;
          final recentArt = leadArts[1] ?? _icMusicNote;
          final recentlyPlayedArt = leadArts[2] ?? recentArt;
          final randomArt = leadArts[3] ?? _icAlbumCollection;
          final mostPlayedArt = leadArts[4] ?? _icMusicNote;
          final starredArt = leadArts[5] ?? _icFavoriteHeart;
          final topRatedArt = leadArts[6] ?? _icStarRating;

          final downloadedAlbums = await library.watchDownloadedAlbums().first;
          Uri? downloadedArt;
          for (final a in downloadedAlbums) {
            if (a.coverArtId != null) {
              downloadedArt = client.getCoverArtUri(a.coverArtId!, size: 400);
              break;
            }
          }
          downloadedArt ??= _icMusicNote;

          return [
            MediaItem(
              id: 'albums_section_all',
              title: 'All',
              displayTitle: 'All',
              displaySubtitle: 'Alphabetical discography',
              artUri: allArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_recentlyAdded',
              title: 'Recently Added',
              displayTitle: 'Recently Added',
              displaySubtitle: 'Newest additions',
              artUri: recentArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_recentlyPlayed',
              title: 'Recently Played',
              displayTitle: 'Recently Played',
              displaySubtitle: 'Recently listened',
              artUri: recentlyPlayedArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_random',
              title: 'Random',
              displayTitle: 'Random',
              displaySubtitle: 'Surprise mix',
              artUri: randomArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_mostPlayed',
              title: 'Most Played',
              displayTitle: 'Most Played',
              displaySubtitle: 'Frequently listened',
              artUri: mostPlayedArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_favorites',
              title: '❤️ Favorites',
              displayTitle: '❤️ Favorites',
              displaySubtitle: 'Favorite albums',
              artUri: starredArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_topRated',
              title: '⭐ Top Rated',
              displayTitle: '⭐ Top Rated',
              displaySubtitle: 'Highest rated albums',
              artUri: topRatedArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
            MediaItem(
              id: 'albums_section_downloaded',
              title: 'Downloaded',
              displayTitle: 'Downloaded',
              displaySubtitle: 'Available offline',
              artUri: downloadedArt,
              playable: false,
              extras: const {
                AndroidContentStyle.browsableHintKey:
                    AndroidContentStyle.gridItemHintValue,
              },
            ),
          ];

        case kPlaylistsNode:
          final playlists = await client.getPlaylists();
          return playlists
              .take(50)
              .map((p) => playlistToMediaItem(p, client))
              .toList();

        case kFavoritesNode:
          try {
            await library.syncAnnotations(force: true);
          } catch (_) {}
          var starredAlbums = await library
              .watchAlbumList(const AlbumListQuery(AlbumListType.starred))
              .first;
          if (starredAlbums.isEmpty) {
            try {
              await library.refreshAlbumList(
                const AlbumListQuery(AlbumListType.starred),
              );
              starredAlbums = await library
                  .watchAlbumList(const AlbumListQuery(AlbumListType.starred))
                  .first;
            } catch (e) {
              AppLogger.w(
                'AudioHandler',
                'refreshAlbumList(starred) failed: $e',
              );
            }
          }
          if (starredAlbums.isEmpty) {
            try {
              starredAlbums = await client.getAlbumList(
                AlbumListType.starred,
                count: 30,
              );
            } catch (e) {
              AppLogger.e(
                'AudioHandler',
                'client.getAlbumList(starred) failed: $e',
              );
            }
          }
          return starredAlbums
              .take(50)
              .map((a) => albumToMediaItem(a, client))
              .toList();

        case kOfflineNode:
          final downloadedSongs = await library.getDownloadedSongs();
          return downloadedSongs
              .take(100)
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

      // Dynamic sub-nodes (artists_starred, artists_letter_*, artist_{id}, album_{id}, playlist_{id})
      if (parentMediaId == 'artists_starred') {
        try {
          await library.syncAnnotations(force: true);
        } catch (_) {}
        var artists = await library.watchArtists().first;
        if (artists.isEmpty) {
          try {
            artists = await client.getArtists();
          } catch (_) {}
        }
        var starred = artists.where((a) => a.starred).take(80).toList();
        if (starred.isEmpty) {
          try {
            final res = await client.getStarred();
            if (res.artists.isNotEmpty) {
              starred = res.artists.take(80).toList();
            }
          } catch (e) {
            AppLogger.e(
              'AudioHandler',
              'client.getStarred fallback failed: $e',
            );
          }
        }
        AppLogger.i(
          'AudioHandler',
          'artists_starred: returning ${starred.length} items',
        );
        return starred.map((a) => artistToMediaItem(a, client)).toList();
      }

      if (parentMediaId.startsWith('artists_letter_')) {
        final letter = parentMediaId.substring(15);
        var artists = await library.watchArtists().first;
        if (artists.isEmpty) {
          try {
            artists = await client.getArtists();
          } catch (_) {}
        }
        final matching = artists
            .where((a) {
              final name = (a.sortName ?? a.name).trim();
              if (name.isEmpty) return letter == '#';
              final char = name[0].toUpperCase();
              if (letter == '#') {
                return !RegExp(r'[A-Z]').hasMatch(char);
              }
              return char == letter;
            })
            .take(80);
        AppLogger.i(
          'AudioHandler',
          'artists_letter_$letter: returning ${matching.length} items',
        );
        return matching.map((a) => artistToMediaItem(a, client)).toList();
      }

      if (parentMediaId.startsWith('albums_section_')) {
        final section = parentMediaId.substring(15);
        return _getAlbumSection(section, library, client);
      }

      if (parentMediaId.startsWith('albums_letter_')) {
        final letter = parentMediaId.substring(14);
        var albums = await library
            .watchAlbumList(
              const AlbumListQuery(AlbumListType.alphabeticalByName),
            )
            .first;
        if (albums.isEmpty) {
          try {
            albums = await client.getAlbumList(
              AlbumListType.alphabeticalByName,
              count: 100,
            );
          } catch (_) {}
        }
        final matching = albums
            .where((a) {
              final name = a.name.trim();
              if (name.isEmpty) return letter == '#';
              final char = name[0].toUpperCase();
              if (letter == '#') return !RegExp(r'[A-Z]').hasMatch(char);
              return char == letter;
            })
            .take(80);
        AppLogger.i(
          'AudioHandler',
          'albums_letter_$letter: returning ${matching.length} items',
        );
        return matching.map((a) => albumToMediaItem(a, client)).toList();
      }

      if (parentMediaId.startsWith('artist_')) {
        final artistId = parentMediaId.substring(7);
        try {
          await library.refreshArtist(artistId);
        } catch (e) {
          AppLogger.w('AudioHandler', 'refreshArtist failed: $e');
        }
        var albums = await library.watchArtistAlbums(artistId).first;
        if (albums.isEmpty) {
          try {
            albums = await client.getArtistAlbums(artistId);
          } catch (e) {
            AppLogger.e('AudioHandler', 'client.getArtistAlbums failed: $e');
          }
        }
        AppLogger.i(
          'AudioHandler',
          'artist_$artistId: returning ${albums.length} albums',
        );
        return albums.map((a) => albumToMediaItem(a, client)).toList();
      }

      if (parentMediaId.startsWith('album_')) {
        final albumId = parentMediaId.substring(6);
        try {
          await library.refreshAlbum(albumId);
        } catch (e) {
          AppLogger.w('AudioHandler', 'refreshAlbum failed: $e');
        }
        var songs = await library.watchAlbumSongs(albumId).first;
        if (songs.isEmpty) {
          try {
            songs = await client.getAlbumSongs(albumId);
          } catch (e) {
            AppLogger.e('AudioHandler', 'client.getAlbumSongs failed: $e');
          }
        }
        AppLogger.i(
          'AudioHandler',
          'album_$albumId: returning ${songs.length} songs',
        );
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

  Future<List<MediaItem>> _getAlbumSection(
    String section,
    LibraryRepository library,
    SubsonicClient client,
  ) async {
    if (section == 'downloaded') {
      final albums = await library.watchDownloadedAlbums().first;
      AppLogger.i(
        'AudioHandler',
        'albums_section_downloaded: returning ${albums.length} albums',
      );
      return albums.take(50).map((a) => albumToMediaItem(a, client)).toList();
    }

    final listType = switch (section) {
      'recentlyAdded' => AlbumListType.newest,
      'recentlyPlayed' => AlbumListType.recent,
      'random' => AlbumListType.random,
      'mostPlayed' => AlbumListType.frequent,
      'favorites' => AlbumListType.starred,
      'topRated' => AlbumListType.highest,
      _ => AlbumListType.alphabeticalByName,
    };

    if (section == 'favorites') {
      try {
        await library.syncAnnotations(force: true);
      } catch (_) {}
    }

    final query = AlbumListQuery(listType);
    var albums = await library.watchAlbumList(query).first;

    if (albums.isEmpty && query.isCacheable) {
      try {
        await library.refreshAlbumList(query);
        albums = await library.watchAlbumList(query).first;
      } catch (e) {
        AppLogger.w('AudioHandler', 'refreshAlbumList($section) failed: $e');
      }
    }

    if (albums.isEmpty) {
      try {
        albums = await client.getAlbumList(listType, count: 50);
      } catch (e) {
        AppLogger.e('AudioHandler', 'client.getAlbumList($section) failed: $e');
      }
    }

    if (section == 'all' && albums.length > 60) {
      final letterCounts = <String, int>{};
      for (final a in albums) {
        final name = a.name.trim();
        final char = name.isNotEmpty ? name[0].toUpperCase() : '#';
        final key = RegExp(r'[A-Z]').hasMatch(char) ? char : '#';
        letterCounts[key] = (letterCounts[key] ?? 0) + 1;
      }

      final sortedKeys = letterCounts.keys.toList()
        ..sort((a, b) {
          if (a == '#') return 1;
          if (b == '#') return -1;
          return a.compareTo(b);
        });

      return sortedKeys.map((letter) {
        final count = letterCounts[letter]!;
        final firstAlbumInLetter = albums.firstWhereOrNull((a) {
          final name = a.name.trim();
          if (name.isEmpty) return letter == '#';
          final char = name[0].toUpperCase();
          if (letter == '#') return !RegExp(r'[A-Z]').hasMatch(char);
          return char == letter;
        });
        final letterArt = firstAlbumInLetter?.coverArtId != null
            ? client.getCoverArtUri(firstAlbumInLetter!.coverArtId!, size: 400)
            : _icAlbumCollection;

        return MediaItem(
          id: 'albums_letter_$letter',
          title: letter,
          displayTitle: letter,
          displaySubtitle: '$count ${count == 1 ? 'album' : 'albums'}',
          artUri: letterArt,
          playable: false,
          extras: const {
            AndroidContentStyle.browsableHintKey:
                AndroidContentStyle.gridItemHintValue,
          },
        );
      }).toList();
    }

    AppLogger.i(
      'AudioHandler',
      'albums_section_$section: returning ${albums.length} albums',
    );
    return albums.take(50).map((a) => albumToMediaItem(a, client)).toList();
  }

  List<MediaItem> _getRootCategories() {
    return [
      MediaItem(
        id: kRecentNode,
        title: 'Recently Added',
        artUri: _icMusicNote,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.gridItemHintValue,
        },
      ),
      MediaItem(
        id: kArtistsNode,
        title: 'Artists',
        artUri: _icArtistAvatar,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.gridItemHintValue,
        },
      ),
      MediaItem(
        id: kAlbumsNode,
        title: 'Albums',
        artUri: _icAlbumCollection,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.gridItemHintValue,
        },
      ),
      MediaItem(
        id: kPlaylistsNode,
        title: 'Playlists',
        artUri: _icMusicNote,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.listItemHintValue,
        },
      ),
      MediaItem(
        id: kFavoritesNode,
        title: 'Favorites',
        artUri: _icFavoriteHeart,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.gridItemHintValue,
        },
      ),
      MediaItem(
        id: kOfflineNode,
        title: 'Downloaded / Offline',
        artUri: _icMusicNote,
        playable: false,
        extras: const {
          AndroidContentStyle.browsableHintKey:
              AndroidContentStyle.listItemHintValue,
        },
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
        var songs = await library.watchAlbumSongs(albumId).first;
        if (songs.isEmpty) {
          try {
            await library.refreshAlbum(albumId);
            songs = await library.watchAlbumSongs(albumId).first;
          } catch (_) {}
          if (songs.isEmpty && client != null) {
            songs = await client.getAlbumSongs(albumId);
          }
        }
        if (songs.isNotEmpty) {
          await _player.playTracks(songs, initialIndex: 0);
        }
      } else if (mediaId.startsWith('artist_')) {
        final artistId = mediaId.substring(7);
        var albums = await library.watchArtistAlbums(artistId).first;
        if (albums.isEmpty) {
          try {
            await library.refreshArtist(artistId);
            albums = await library.watchArtistAlbums(artistId).first;
          } catch (_) {}
          if (albums.isEmpty && client != null) {
            albums = await client.getArtistAlbums(artistId);
          }
        }
        if (albums.isNotEmpty) {
          var firstAlbumSongs = await library
              .watchAlbumSongs(albums.first.id)
              .first;
          if (firstAlbumSongs.isEmpty && client != null) {
            firstAlbumSongs = await client.getAlbumSongs(albums.first.id);
          }
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
      } else if (mediaId.startsWith('albums_section_')) {
        final section = mediaId.substring(15);
        if (client != null) {
          final items = await _getAlbumSection(section, library, client);
          if (items.isNotEmpty) {
            await playFromMediaId(items.first.id);
          }
        }
      } else if (mediaId.startsWith('albums_letter_')) {
        final items = await getChildren(mediaId);
        if (items.isNotEmpty) {
          await playFromMediaId(items.first.id);
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
    if (library == null || client == null || query.trim().isEmpty) {
      return const [];
    }

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

  Future<void> _activateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      AppLogger.w('AudioHandler', 'Failed to activate AudioSession: $e');
    }
  }

  @override
  Future<void> play() async {
    await _activateAudioSession();
    await _player.play();
  }

  @override
  Future<void> pause() async => _player.pause();

  @override
  Future<void> stop() async => _player.pause();

  @override
  Future<void> skipToNext() async => _player.next();

  @override
  Future<void> skipToPrevious() async => _player.previous();

  @override
  Future<void> seek(Duration position) async {
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: position,
      ),
    );
    await _player.seek(position);
  }

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
    if (name == _actionToggleFavorite) {
      await _player.toggleCurrentSongStarred();
      return true;
    } else if (name == _actionToggleShuffle) {
      _player.toggleShuffle();
      return true;
    }
    return super.customAction(name, extras);
  }

  // ── Converters ─────────────────────────────────────────────────────────────

  static String? _formatAudioQuality(Song song) {
    final format = (song.suffix ?? song.contentType?.split('/').last ?? '')
        .toUpperCase();
    if (format.isEmpty) return null;

    if (format == 'FLAC' || format == 'ALAC' || format == 'WAV') {
      if (song.sampleRate != null && song.sampleRate! > 0) {
        final kHz = (song.sampleRate! / 1000).toStringAsFixed(
          song.sampleRate! % 1000 == 0 ? 0 : 1,
        );
        if (song.bitDepth != null && song.bitDepth! > 0) {
          return '$format ${song.bitDepth}/$kHz';
        }
        return '$format ${kHz}kHz';
      }
      return '$format Lossless';
    }
    if (song.bitRate != null && song.bitRate! > 0) {
      return '$format ${song.bitRate}k';
    }
    return format;
  }

  static MediaItem songToMediaItem(
    Song song, {
    String? coverArtUrl,
    bool forNowPlaying = false,
  }) {
    final quality = forNowPlaying ? _formatAudioQuality(song) : null;

    final subtitleParts = <String>[
      if (song.artistName != null && song.artistName!.isNotEmpty)
        song.artistName!,
      if (song.albumName != null && song.albumName!.isNotEmpty) song.albumName!,
      if (quality != null && quality.isNotEmpty) quality,
    ];
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' · ')
        : null;

    final fullTitle =
        (!forNowPlaying &&
            song.artistName != null &&
            song.artistName!.isNotEmpty)
        ? '${song.title} · ${song.artistName}'
        : song.title;

    return MediaItem(
      id: 'song_${song.id}',
      album: song.albumName ?? '',
      title: fullTitle,
      artist: song.artistName ?? '',
      displayTitle: fullTitle,
      displaySubtitle: subtitle,
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
        ? client.getCoverArtUri(album.coverArtId!, size: 400).toString()
        : null;

    final subtitleParts = <String>[
      if (album.artistName != null && album.artistName!.isNotEmpty)
        album.artistName!,
      if (album.year != null) '${album.year}',
    ];
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' · ')
        : null;

    return MediaItem(
      id: 'album_${album.id}',
      album: album.name,
      title: album.name,
      artist: album.artistName ?? '',
      displayTitle: album.name,
      displaySubtitle: subtitle,
      artUri: coverUrl != null ? Uri.tryParse(coverUrl) : null,
      playable: false,
      extras: {
        'albumId': album.id,
        'songCount': album.songCount,
        'year': album.year,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    );
  }

  static MediaItem artistToMediaItem(Artist artist, SubsonicClient client) {
    final coverUrl = artist.coverArtId != null
        ? client.getCoverArtUri(artist.coverArtId!, size: 400).toString()
        : artist.imageUrl;

    final subtitle = artist.albumCount > 0
        ? '${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}'
        : null;

    return MediaItem(
      id: 'artist_${artist.id}',
      title: artist.name,
      artist: artist.name,
      displayTitle: artist.name,
      displaySubtitle: subtitle,
      artUri: coverUrl != null ? Uri.tryParse(coverUrl) : null,
      playable: false,
      extras: {
        'artistId': artist.id,
        'albumCount': artist.albumCount,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.gridItemHintValue,
      },
    );
  }

  static MediaItem playlistToMediaItem(
    Playlist playlist, [
    SubsonicClient? client,
  ]) {
    final coverUrl = playlist.coverArtId != null && client != null
        ? client.getCoverArtUri(playlist.coverArtId!, size: 400).toString()
        : null;

    return MediaItem(
      id: 'playlist_${playlist.id}',
      title: playlist.name,
      displayTitle: playlist.name,
      displaySubtitle: '${playlist.songCount} songs',
      artUri: coverUrl != null ? Uri.tryParse(coverUrl) : null,
      playable: false,
      extras: {
        'playlistId': playlist.id,
        'songCount': playlist.songCount,
        'duration': playlist.duration,
        AndroidContentStyle.browsableHintKey:
            AndroidContentStyle.listItemHintValue,
      },
    );
  }
}
