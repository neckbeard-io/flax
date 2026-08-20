import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';
import 'package:flax/shared/widgets/star_rating.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

/// The album and its tracks, read from the local database. Issue #8.
///
/// Both are streams, so a favorite or a rating written anywhere — here, the
/// queue header, the mini player — lands in this screen with no invalidation.
/// The `ref.invalidate` calls these replaced existed only because each screen
/// held its own copy of the same track.
final albumDetailProvider = StreamProvider.family<Album, String>((
  ref,
  id,
) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) throw Exception('No server');

  if (!isOffline) {
    final cached = await repo.watchAlbum(id).first;
    if (cached == null) {
      await repo.refreshAlbum(id);
    } else {
      repo.refreshAlbum(id);
    }
  }

  // A null here means the album is genuinely gone from the cache, which for this
  // screen is an error rather than an empty state.
  yield* repo.watchAlbum(id).map((album) {
    if (album == null) throw Exception('Album not found');
    return album;
  });
});

final albumSongsProvider = StreamProvider.family<List<Song>, String>((
  ref,
  albumId,
) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  if (isOffline) {
    yield* repo.watchDownloadedAlbumSongs(albumId);
    return;
  }

  // Track listings only arrive with getAlbum, so unlike the album row itself
  // an empty or partial list here means "not fully fetched yet".
  final cached = await repo.watchAlbumSongs(albumId).first;
  final album = await repo.watchAlbum(albumId).first;
  final isIncomplete =
      album != null && album.songCount > 0 && cached.length < album.songCount;

  if (cached.isEmpty || isIncomplete) {
    await repo.refreshAlbum(albumId);
  } else {
    repo.refreshAlbum(albumId);
  }

  yield* repo.watchAlbumSongs(albumId);
});

class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumDetailProvider(albumId));
    final songsAsync = ref.watch(albumSongsProvider(albumId));
    final desktop = isDesktopLayout(context);

    return Scaffold(
      body: albumAsync.when(
        data: (album) => CustomScrollView(
          slivers: [
            if (desktop)
              SliverToBoxAdapter(
                child: _DesktopHeader(album: album, albumId: albumId),
              )
            else
              _MobileHeader(album: album, albumId: albumId),
            songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverMainAxisGroup(
                  slivers: [
                    if (desktop)
                      const SliverToBoxAdapter(child: _TrackTableHeader()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _TrackRow(
                          song: songs[index],
                          index: index,
                          songs: songs,
                          albumId: albumId,
                          desktop: desktop,
                        ),
                        childCount: songs.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Album-level rating and favorite.
///
/// Both write to the local database first and push to the server behind that, so
/// the glyph responds immediately and a failed push leaves the row dirty for
/// retry rather than reverting under the user.
class _AlbumActions extends ConsumerWidget {
  const _AlbumActions({
    required this.album,
    required this.albumId,
    this.size = 22,
  });

  final Album album;
  final String albumId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadedAlbumIds =
        ref.watch(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final isCached = downloadedAlbumIds.contains(album.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // No invalidate on either of these: the write lands in the database and
        // the stream carries it back here and to every other view of the same
        // album. It is also optimistic, so the glyph changes immediately rather
        // than after a round trip.
        StarRating(
          rating: album.userRating ?? 0,
          size: size,
          onRatingChanged: (rating) async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setRating(
                  EntityRef(EntityType.album, album.id),
                  rating: rating,
                );
          },
        ),
        const SizedBox(width: 8),
        FavoriteButton(
          isFavorite: album.starred,
          size: size,
          onToggle: () async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setFavorite(
                  EntityRef(EntityType.album, album.id),
                  favorite: !album.starred,
                );
          },
        ),
        const SizedBox(width: 8),
        HoverIcon(
          icon: isCached ? Icons.offline_pin : Icons.download,
          size: size,
          color: isCached
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          tooltip: isCached ? 'Remove album from cache' : 'Cache album offline',
          onTap: () {
            final cacheService = ref.read(audioCacheServiceProvider);
            if (isCached) {
              cacheService.removeCachedAlbum(album.id);
            } else {
              cacheService.cacheAlbum(album.id);
            }
          },
        ),
      ],
    );
  }
}

/// Play / Next / Last, matching the reference layout.
class _AlbumPlayActions extends ConsumerWidget {
  const _AlbumPlayActions({required this.albumId});

  final String albumId;

  List<Song> _songs(WidgetRef ref) =>
      ref.read(albumSongsProvider(albumId)).valueOrNull ?? const [];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () {
            final songs = _songs(ref);
            if (songs.isEmpty) return;
            ref
                .read(playerProvider.notifier)
                .playSong(songs.first, queue: songs, index: 0);
            if (ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
              context.push('/now-playing');
            }
          },
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Play'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(playerProvider.notifier).playNext(_songs(ref)),
          icon: const Icon(Icons.playlist_play, size: 18),
          label: const Text('Next'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(playerProvider.notifier).addToQueue(_songs(ref)),
          icon: const Icon(Icons.playlist_add, size: 18),
          label: const Text('Last'),
        ),
      ],
    );
  }
}

/// Desktop header: large square art beside the album's details.
///
/// Deliberately not the collapsing image the phone uses — a full-bleed cover
/// behind text wastes the width a desktop window has, and the art is worth
/// showing undistorted at size.
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.album, required this.albumId});

  final Album album;
  final String albumId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always present. Popping returns you to wherever you came from; with
          // nothing to pop — a deep link, or a directly launched screen — it
          // falls back to the album's artist, which is the page that contains
          // it. Hiding the button in that case left no way out at all.
          UpBackButton(
            fallbackLocation: album.artistId != null
                ? '/artists/${album.artistId}'
                : '/albums',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CoverArtImage(
                    coverArtId: album.coverArtId,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALBUM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        album.name,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (album.year != null) '${album.year}',
                          '${album.songCount} '
                              '${album.songCount == 1 ? "track" : "tracks"}',
                          formatDuration(album.duration),
                          if (album.genre != null) album.genre!,
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (album.artistName != null)
                        HoverLink(
                          text: album.artistName!,
                          onTap: album.artistId != null
                              ? () => context.push('/artists/${album.artistId}')
                              : null,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _AlbumPlayActions(albumId: albumId)),
                          _AlbumActions(album: album, albumId: albumId),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone header: the existing collapsing cover, plus the album actions.
class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.album, required this.albumId});

  final Album album;
  final String albumId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(album.name, style: const TextStyle(fontSize: 16)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                CoverArtImage(coverArtId: album.coverArtId),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (album.artistName != null)
                  HoverLink(
                    text: album.artistName!,
                    onTap: album.artistId != null
                        ? () => context.push('/artists/${album.artistId}')
                        : null,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: album.artistId != null
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (album.year != null) '${album.year}',
                    '${album.songCount} tracks',
                    formatDuration(album.duration),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _AlbumPlayActions(albumId: albumId),
                const SizedBox(height: 8),
                _AlbumActions(album: album, albumId: albumId, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Column headings for the desktop track table.
class _TrackTableHeader extends StatelessWidget {
  const _TrackTableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 32, child: Text('#', style: style)),
              const SizedBox(width: 8),
              Expanded(child: Text('TITLE', style: style)),
              SizedBox(
                width: _TrackRow.ratingWidth,
                child: Text('RATING', style: style),
              ),
              SizedBox(
                width: 56,
                child: Icon(
                  Icons.access_time,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                width: 40,
                child: Icon(
                  Icons.favorite_border,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

/// One track. On desktop this is a table row with rating and favorite columns;
/// on a phone it keeps the list-tile shape and shows only the favorite, since
/// five stars per row does not fit a narrow screen.
class _TrackRow extends ConsumerWidget {
  const _TrackRow({
    required this.song,
    required this.index,
    required this.songs,
    required this.albumId,
    required this.desktop,
  });

  final Song song;
  final int index;
  final List<Song> songs;
  final String albumId;
  final bool desktop;

  static const ratingWidth = 96.0;

  void _play(BuildContext context, WidgetRef ref) {
    ref
        .read(playerProvider.notifier)
        .playSong(song, queue: songs, index: index);
    if (ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
      context.push('/now-playing');
    }
  }

  // The old versions of these refetched the whole track list, with the comment
  // "the list is the only copy of this track, and the player may be holding a
  // separate one for the same id". That is exactly the problem the database
  // removes: there is now one row per track and every view watches it.
  Future<void> _rate(WidgetRef ref, int rating) async {
    await ref
        .read(libraryRepositoryProvider)
        ?.setRating(EntityRef(EntityType.song, song.id), rating: rating);
  }

  Future<void> _toggleFavorite(WidgetRef ref) async {
    await ref
        .read(libraryRepositoryProvider)
        ?.setFavorite(
          EntityRef(EntityType.song, song.id),
          favorite: !song.starred,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playingId = ref.watch(playerProvider).currentSong?.id;
    final isPlaying = playingId == song.id;
    final downloadedSongIds =
        ref.watch(downloadedSongIdsProvider).valueOrNull ?? const {};
    final isCached = downloadedSongIds.contains(song.id);

    if (!desktop) {
      return SongContextMenu(
        song: song,
        queue: songs,
        index: index,
        child: ListTile(
          leading: SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '${song.track ?? index + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isPlaying
                ? TextStyle(color: theme.colorScheme.primary)
                : null,
          ),
          subtitle: song.artistName != null
              ? Text(
                  song.artistName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCached) ...[
                Icon(
                  Icons.offline_pin,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                formatDuration(song.duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              FavoriteButton(
                isFavorite: song.starred,
                size: 16,
                onToggle: () => _toggleFavorite(ref),
              ),
            ],
          ),
          onTap: () => _play(context, ref),
        ),
      );
    }

    return SongContextMenu(
      song: song,
      queue: songs,
      index: index,
      child: HoverSurface(
        onTap: () => _play(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: isPlaying
                    ? Icon(
                        Icons.volume_up,
                        size: 14,
                        color: theme.colorScheme.primary,
                      )
                    : Text(
                        '${song.track ?? index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isPlaying
                                  ? theme.colorScheme.primary
                                  : null,
                              fontWeight: isPlaying ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (isCached) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.offline_pin,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    // Only when it differs from the album artist — repeating it on
                    // every row of a single-artist album is noise.
                    if (song.artistName != null &&
                        song.artistName != _albumArtist(ref))
                      Text(
                        song.artistName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: ratingWidth,
                child: StarRating(
                  rating: song.userRating ?? 0,
                  size: 14,
                  onRatingChanged: (r) => _rate(ref, r),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  formatDuration(song.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: FavoriteButton(
                  isFavorite: song.starred,
                  size: 16,
                  onToggle: () => _toggleFavorite(ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _albumArtist(WidgetRef ref) =>
      ref.read(albumDetailProvider(albumId)).valueOrNull?.artistName;
}

/// h:mm:ss, or m:ss under an hour.
String formatDuration(int seconds) {
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}
