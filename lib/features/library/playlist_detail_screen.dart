import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/shared/widgets/album_group_header.dart';
import 'package:flax/shared/widgets/caching_snack_bar.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

final playlistDetailProvider = StreamProvider.autoDispose
    .family<Playlist?, String>((ref, id) {
      final repo = ref.watch(libraryRepositoryProvider);
      if (repo == null) return Stream.value(null);
      return repo.watchPlaylist(id);
    });

/// A playlist's tracks in playlist order. Offline, only those on the device.
///
/// Disposed with the screen, so each visit picks up edits made elsewhere.
final playlistSongsProvider = StreamProvider.autoDispose
    .family<List<Song>, String>((ref, id) async* {
      final isOffline = ref.watch(isOfflineModeProvider);
      final repo = ref.watch(libraryRepositoryProvider);
      if (repo == null) {
        yield const [];
        return;
      }

      if (isOffline) {
        yield* repo.watchDownloadedPlaylistSongs(id);
        return;
      }

      final cached = await repo.watchPlaylistSongs(id).first;
      final refresh = repo.refreshPlaylist(id);
      if (cached.isEmpty) await refresh;
      yield* repo.watchPlaylistSongs(id);
    });

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playlistAsync = ref.watch(playlistDetailProvider(playlistId));
    final songsAsync = ref.watch(playlistSongsProvider(playlistId));
    final desktop = isDesktopLayout(context);

    return Scaffold(
      body: playlistAsync.when(
        data: (playlist) {
          if (playlist == null) {
            // Not stored yet while a first fetch is under way, as when the
            // screen is opened directly.
            if (songsAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return PinnedBackBar(
              fallbackLocation: '/playlists',
              child: Center(
                child: Text(l10n?.playlistNotFound ?? 'Playlist not found'),
              ),
            );
          }
          final page = CustomScrollView(
            slivers: [
              if (desktop)
                SliverToBoxAdapter(child: _DesktopHeader(playlist: playlist))
              else
                _MobileHeader(playlist: playlist),
              songsAsync.when(
                data: (songs) => songs.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyTracks(),
                      )
                    : _Tracks(songs: songs, desktop: desktop),
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('${l10n?.error ?? 'Error'}: $e')),
                ),
              ),
            ],
          );
          if (!desktop) return page;
          return PinnedBackBar(fallbackLocation: '/playlists', child: page);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n?.error ?? 'Error'}: $e')),
      ),
    );
  }
}

/// The tracks in playlist order, with a break wherever the album changes.
class _Tracks extends StatelessWidget {
  const _Tracks({required this.songs, required this.desktop});

  final List<Song> songs;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final groups = groupByAlbum(songs);
    return SliverMainAxisGroup(
      slivers: [
        if (desktop)
          const SliverToBoxAdapter(child: TrackTableHeader(genreColumn: false)),
        for (final (i, group) in groups.indexed) ...[
          SliverToBoxAdapter(
            // Room for larger art than the queue's narrow panel.
            child: AlbumGroupHeader(
              group: group,
              coverSize: desktop ? 64 : 48,
              padding: EdgeInsets.fromLTRB(
                desktop ? 24 : 16,
                16,
                desktop ? 24 : 16,
                desktop ? 8 : 6,
              ),
              detailsBelow: desktop,
            ),
          ),
          _groupTracks(
            group,
            groups.take(i).fold(0, (sum, g) => sum + g.songs.length),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _groupTracks(AlbumGroup group, int start) => SliverList(
    delegate: SliverChildBuilderDelegate((context, index) {
      final song = group.songs[index];
      return TrackRow(
        song: song,
        // Where the track sits in the whole playlist, which is what plays
        // from here.
        index: start + index,
        songs: songs,
        number: song.track ?? index + 1,
        albumArtist: group.artistName,
        desktop: desktop,
      );
    }, childCount: group.songs.length),
  );
}

class _EmptyTracks extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          ref.watch(isOfflineModeProvider)
              ? l10n?.noCachedPlaylistTracks ??
                    'No tracks from this playlist are cached'
              : l10n?.playlistEmpty ?? 'This playlist has no tracks',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Play / Next / Last, each acting on the whole playlist, as on an album.
class _PlayActions extends ConsumerWidget {
  const _PlayActions({required this.playlistId});

  final String playlistId;

  List<Song> _songs(WidgetRef ref) =>
      ref.read(playlistSongsProvider(playlistId)).valueOrNull ?? const [];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
          label: Text(l10n?.play ?? 'Play'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(playerProvider.notifier).playNext(_songs(ref)),
          icon: const Icon(Icons.playlist_play, size: 18),
          label: Text(l10n?.queueNext ?? 'Next'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(playerProvider.notifier).addToQueue(_songs(ref)),
          icon: const Icon(Icons.playlist_add, size: 18),
          label: Text(l10n?.queueLast ?? 'Last'),
        ),
      ],
    );
  }
}

/// Cache, complete or remove, as on an album. Nothing can download offline, so
/// the actions that would are hidden there.
class _CacheActions extends ConsumerWidget {
  const _CacheActions({required this.playlist, this.size = 22});

  final Playlist playlist;
  final double size;

  void _cache(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final message =
        l10n?.cachingPlaylist(playlist.name) ?? 'Caching "${playlist.name}"...';
    ref
        .read(audioCacheServiceProvider)
        .cachePlaylist(playlist.id, label: message);
    showCachingSnackBar(context, message: message);
  }

  void _remove(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.read(audioCacheServiceProvider).removeCachedPlaylist(playlist.id);
    showCacheRemovedSnackBar(
      context,
      message:
          l10n?.removedPlaylistFromCache(playlist.name) ??
          'Removed "${playlist.name}" from offline cache',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isOffline = ref.watch(isOfflineModeProvider);
    final fullyCached =
        ref
            .watch(downloadedPlaylistIdsProvider)
            .valueOrNull
            ?.contains(playlist.id) ??
        false;
    final hasCachedTracks =
        ref
            .watch(anyDownloadedPlaylistIdsProvider)
            .valueOrNull
            ?.contains(playlist.id) ??
        false;

    if (fullyCached) {
      return HoverIcon(
        icon: Icons.offline_pin,
        size: size,
        color: theme.colorScheme.primary,
        tooltip: l10n?.removePlaylistFromCache ?? 'Remove playlist from cache',
        onTap: () => _remove(context, ref),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isOffline)
          HoverIcon(
            icon: hasCachedTracks
                ? Icons.download_for_offline_outlined
                : Icons.download,
            size: size,
            color: hasCachedTracks
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            tooltip: hasCachedTracks
                ? l10n?.completePlaylistCaching ?? 'Complete playlist caching'
                : l10n?.cachePlaylistOffline ?? 'Cache playlist offline',
            onTap: () => _cache(context, ref),
          ),
        if (hasCachedTracks) ...[
          if (!isOffline) const SizedBox(width: 8),
          HoverIcon(
            icon: Icons.delete_outline,
            size: size,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: l10n?.removeCachedTracks ?? 'Remove cached tracks',
            onTap: () => _remove(context, ref),
          ),
        ],
      ],
    );
  }
}

String _summary(BuildContext context, Playlist playlist) {
  final l10n = AppLocalizations.of(context);
  final count =
      l10n?.trackCount(playlist.songCount) ??
      '${playlist.songCount} ${playlist.songCount == 1 ? 'track' : 'tracks'}';
  return '$count · ${formatDuration(playlist.duration)}';
}

/// Desktop header: large square art beside the details, as on an album.
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final coverSize = (constraints.maxWidth * 0.3).clamp(160.0, 240.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: coverSize,
                height: coverSize,
                child: CoverArtImage(
                  coverArtId: playlist.coverArtId,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.playlistHeading ?? 'PLAYLIST',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.name,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _summary(context, playlist),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PlayActions(playlistId: playlist.id),
                        _CacheActions(playlist: playlist),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Phone header: the collapsing cover, as on an album.
class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(playlist.name, style: const TextStyle(fontSize: 16)),
            background: Stack(
              fit: StackFit.expand,
              children: [
                CoverArtImage(coverArtId: playlist.coverArtId),
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
                Text(
                  _summary(context, playlist),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                _PlayActions(playlistId: playlist.id),
                const SizedBox(height: 8),
                _CacheActions(playlist: playlist, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
