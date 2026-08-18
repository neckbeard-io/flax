import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_filter.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Albums for one tab.
///
/// A family rather than one provider re-fetching on every tab change: switching
/// back to a tab you already looked at should be instant, and Random in
/// particular should show the same shuffle you were just browsing rather than
/// reshuffling under you.
final albumsProvider = StreamProvider.family<List<Album>, AlbumFilter>((
  ref,
  filter,
) async* {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  final query = AlbumListQuery(filter.listType);

  // Random has no cached ordering to read, so its stream does its own fetch.
  // Asking for a refresh as well would fetch twice.
  if (!query.isCacheable) {
    yield* repo.watchAlbumList(query);
    return;
  }

  final cached = await repo.watchAlbumList(query).first;
  if (cached.isEmpty) {
    // Nothing cached for this tab yet, so stay loading rather than showing the
    // tab's empty message — "No albums" for a library that has plenty reads as
    // a failure.
    await repo.refreshAlbumList(query);
  } else {
    repo.refreshAlbumList(query);
  }

  yield* repo.watchAlbumList(query);
});

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(albumFilterProvider);
    final albumsAsync = ref.watch(albumsProvider(filter));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // The window controls are drawn over this corner, so the title
              // reserves their width rather than sliding under them once the
              // window is narrow.
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                windowButtonsReservedWidth + 12,
                4,
              ),
              child: Text(
                'Albums',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            AlbumFilterTabs(
              selected: filter,
              onSelected: (f) =>
                  ref.read(albumFilterProvider.notifier).state = f,
            ),
            Expanded(
              child: albumsAsync.when(
                data: (albums) => albums.isEmpty
                    ? Center(
                        child: Text(
                          filter.emptyMessage,
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
}

/// The row of tabs above the grid.
///
/// Wraps rather than scrolling horizontally, deliberately. Albums is the screen
/// the app now opens on, and a horizontal scrollable across the top of it would
/// make `BackSwipeTracker` stand down for any swipe that started there — the
/// same rule that keeps the old Home shelves from being mistaken for a back
/// gesture. Seven tabs also do not fit one line at phone widths.
class AlbumFilterTabs extends StatelessWidget {
  const AlbumFilterTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AlbumFilter selected;
  final ValueChanged<AlbumFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final filter in AlbumFilter.values)
            _FilterTab(
              filter: filter,
              selected: filter == selected,
              onTap: () => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final AlbumFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return HoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          filter.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Grid of album tiles, identical whichever tab is open.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({super.key, required this.albums});

  final List<Album> albums;

  static const _spacing = 12.0;
  static const _padding = EdgeInsets.all(12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxExtent = artGridExtent(context);
    final labelExtent = artGridLabelExtent(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The tile's height is derived from its width rather than from a fixed
        // childAspectRatio. A ratio cannot say "square art plus two lines": it
        // gave the art whatever was left over, which was taller than it was
        // wide, and CoverArtImage's BoxFit.cover then cropped every sleeve.
        final tileWidth = artGridTileWidth(
          constraints.maxWidth - _padding.horizontal,
          maxExtent,
          _spacing,
        );

        return GridView.builder(
          padding: _padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: tileWidth + labelExtent,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumContextMenu(
              album: album,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: HoverArtwork(
                      onTap: () => context.push('/albums/${album.id}'),
                      // No explicit size: CoverArtImage measures its own box and
                      // fetches to match, so a wider desktop tile pulls a
                      // correspondingly larger image.
                      child: CoverArtImage(coverArtId: album.coverArtId),
                    ),
                  ),
                  const SizedBox(height: 6),
                  HoverLink(
                    text: album.name,
                    onTap: () => context.push('/albums/${album.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  HoverLink(
                    text: album.artistName ?? '',
                    onTap: album.artistId != null
                        ? () => context.push('/artists/${album.artistId}')
                        : null,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
