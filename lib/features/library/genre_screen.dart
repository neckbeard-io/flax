import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/genres.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// The albums tagged with one genre.
///
/// Cached like an Albums tab: the ordering is stored under the genre, so a
/// second visit draws at once and refreshes behind. Offline, it is the
/// downloaded albums in the genre.
final genreAlbumsProvider = StreamProvider.autoDispose
    .family<List<Album>, String>((ref, genre) async* {
      final isOffline = ref.watch(isOfflineModeProvider);
      final repo = ref.watch(libraryRepositoryProvider);
      if (repo == null) {
        yield const [];
        return;
      }

      final query = AlbumListQuery(AlbumListType.byGenre, genre: genre);
      if (isOffline) {
        yield* repo.watchDownloadedAlbums(query: query);
        return;
      }

      final cached = await repo.watchAlbumList(query).first;
      final refresh = repo.refreshAlbumList(query);
      // A first visit has nothing cached. Waiting for the first page keeps the
      // spinner up instead of announcing "No albums" while it is on its way.
      if (cached.isEmpty) await refresh;
      yield* repo.watchAlbumList(query);
    });

class GenreScreen extends ConsumerWidget {
  const GenreScreen({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumsAsync = ref.watch(genreAlbumsProvider(genre));
    final albums = albumsAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GenreHeader(
              genre: genre,
              albumCount: albums?.length,
              onShuffle: albums == null || albums.isEmpty
                  ? null
                  : () => _shuffle(context, ref),
            ),
            const OfflineStatusBanner(),
            Expanded(
              child: albumsAsync.when(
                data: (albums) => albums.isEmpty
                    ? Center(
                        child: Text(
                          'No albums in $genre',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : AlbumGrid(albums: albums),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A shuffle of the genre: the server's own random pick when online, the
  /// downloaded tracks in it when not.
  Future<void> _shuffle(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    final List<Song> songs;
    if (ref.read(isOfflineModeProvider)) {
      final downloaded = await repo.getDownloadedSongs();
      songs = [
        for (final s in downloaded)
          if (hasGenre(s.displayGenres, genre)) s,
      ]..shuffle();
    } else {
      songs = await repo.watchRandomSongs(genre: genre).first;
    }
    if (songs.isEmpty) return;

    await ref.read(playerProvider.notifier).playTracks(songs);
    if (context.mounted &&
        ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
      context.push('/now-playing');
    }
  }
}

/// Back, the genre's name, how many albums it has, and Shuffle.
///
/// Laid out like the album page on desktop. A phone gets an app bar's shape
/// instead: the name beside Back, then the count and Shuffle on one row.
///
/// A plain widget, apart from the providers behind it, so its layout can be
/// tested at phone and desktop widths.
class GenreHeader extends StatelessWidget {
  const GenreHeader({
    super.key,
    required this.genre,
    required this.albumCount,
    required this.onShuffle,
  });

  final String genre;

  /// Null while the albums are still loading.
  final int? albumCount;
  final VoidCallback? onShuffle;

  static const shuffleKey = Key('genre-shuffle');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = albumCount;
    final countText = Text(
      count == null ? ' ' : '$count ${count == 1 ? 'album' : 'albums'}',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final shuffle = FilledButton.icon(
      key: shuffleKey,
      onPressed: onShuffle,
      icon: const Icon(Icons.shuffle, size: 18),
      label: const Text('Shuffle'),
    );
    const back = UpBackButton(fallbackLocation: '/albums');

    if (!isDesktopLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(
              children: [
                back,
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(child: countText),
                shuffle,
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(8, 4, 8, 0), child: back),
        _desktopDetails(theme, countText, shuffle),
      ],
    );
  }

  Widget _desktopDetails(ThemeData theme, Widget countText, Widget shuffle) {
    return Padding(
      // The window controls are drawn over the top-right corner on desktop.
      padding: EdgeInsets.fromLTRB(24, 4, windowButtonsReservedWidth + 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GENRE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  genre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                countText,
              ],
            ),
          ),
          const SizedBox(width: 12),
          shuffle,
        ],
      ),
    );
  }
}
