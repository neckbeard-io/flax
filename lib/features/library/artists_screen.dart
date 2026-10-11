import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/alphabet_scroller.dart';
import 'package:flax/shared/widgets/artist_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/mobile_downloads_pill.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Artists, read from the local database rather than the network. Issue #8.
///
/// A stream rather than a future, so this screen updates when a background
/// refresh lands and when a favorite is written anywhere else in the app —
/// without any invalidation code here.
final artistsProvider = StreamProvider<List<Artist>>((ref) async* {
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  if (isOffline) {
    yield* repo.watchDownloadedArtists();
    return;
  }

  final cached = await repo.watchArtists().first;
  if (cached.isNotEmpty) {
    yield cached;
    repo.refreshArtists().catchError((_) {});
    yield* repo.watchArtists();
    return;
  }

  final downloaded = await repo.watchDownloadedArtists().first;
  if (downloaded.isNotEmpty) {
    yield downloaded;
    repo.refreshArtists().catchError((_) {});
    yield* repo.watchArtists();
    return;
  }

  yield const [];
  repo.refreshArtists().catchError((_) {});
  yield* repo.watchArtists();
});

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  /// Stands in for every row when the list measures its row height. Rows are
  /// one height — one line of name, one of album count — which is what lets a
  /// letter jump straight to its row instead of scrolling to find it.
  static const _prototype = Artist(
    id: '',
    serverId: '',
    name: 'Artist',
    albumCount: 2,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOffline = ref.watch(isOfflineModeProvider);
    final artistsAsync = ref.watch(artistsProvider);
    final downloadedArtistIds =
        ref.watch(downloadedArtistIdsProvider).valueOrNull ?? const {};
    final anyDownloadedArtistIds =
        ref.watch(anyDownloadedArtistIdsProvider).valueOrNull ?? const {};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                isDesktopPlatform ? windowButtonsReservedWidth + 12 : 16,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Artists',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isDesktopPlatform) ...[
                    const MobileActiveDownloadsPill(),
                    const SizedBox(width: 8),
                    const OfflineModeToggle(),
                  ],
                ],
              ),
            ),
            const OfflineStatusBanner(),
            Expanded(
              child: artistsAsync.when(
                data: (artists) {
                  if (artists.isEmpty) {
                    return Center(
                      child: Text(
                        isOffline
                            ? 'No offline cached artists'
                            : 'No artists found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return AlphabetIndexedList(
                    // Indexed by what the list is sorted on: the server's sort
                    // name where it gave one, so "The Beatles" is under B.
                    sortKeys: [for (final a in artists) a.sortName ?? a.name],
                    prototypeItem: const _ArtistTile(artist: _prototype),
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      final isFullyCached = downloadedArtistIds.contains(
                        artist.id,
                      );
                      return ArtistContextMenu(
                        artist: artist,
                        child: _ArtistTile(
                          artist: artist,
                          isFullyCached: isFullyCached,
                          isPartiallyCached:
                              anyDownloadedArtistIds.contains(artist.id) &&
                              !isFullyCached,
                          onTap: () => context.push('/artists/${artist.id}'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({
    required this.artist,
    this.isFullyCached = false,
    this.isPartiallyCached = false,
    this.onTap,
  });

  final Artist artist;
  final bool isFullyCached;
  final bool isPartiallyCached;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CoverArtImage(coverArtId: artist.coverArtId, size: 48),
        ),
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${artist.albumCount} album${artist.albumCount != 1 ? 's' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFullyCached || isPartiallyCached) ...[
            Icon(
              isFullyCached ? Icons.offline_pin : Icons.offline_pin_outlined,
              color: isFullyCached
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              size: 18,
            ),
            const SizedBox(width: 8),
          ],
          if (artist.starred)
            Icon(Icons.favorite, color: theme.colorScheme.primary, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}
