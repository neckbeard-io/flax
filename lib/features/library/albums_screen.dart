import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_filter.dart';
import 'package:flax/shared/widgets/album_grid_tile.dart';
import 'package:flax/shared/widgets/alphabet_scroller.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/mobile_downloads_pill.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
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
  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield const [];
    return;
  }

  final query = AlbumListQuery(filter.listType);

  if (isOffline || filter == AlbumFilter.downloaded) {
    yield* repo.watchDownloadedAlbums(query: query);
    return;
  }

  // Random has no cached ordering to read, so its stream does its own fetch.
  // Asking for a refresh as well would fetch twice.
  if (!query.isCacheable) {
    yield* repo.watchAlbumList(query);
    return;
  }

  final cached = await repo.watchAlbumList(query).first;
  if (cached.isNotEmpty) {
    yield cached;
    repo.refreshAlbumList(query).catchError((_) {});
    yield* repo.watchAlbumList(query);
    return;
  }

  final downloaded = await repo.watchDownloadedAlbums(query: query).first;
  if (downloaded.isNotEmpty) {
    yield downloaded;
    repo.refreshAlbumList(query).catchError((_) {});
    yield* repo.watchAlbumList(query);
    return;
  }

  yield const [];
  repo.refreshAlbumList(query).catchError((_) {});
  yield* repo.watchAlbumList(query);
});

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(albumFilterProvider);
    final isOffline = ref.watch(isOfflineModeProvider);
    final albumsAsync = ref.watch(albumsProvider(filter));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // The window controls are drawn over this corner on desktop, so the title
              // reserves their width. On mobile, we provide the OfflineModeToggle in the header.
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                isDesktopPlatform ? WindowControlsInset.of(context) + 12 : 16,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Albums',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isOffline) ...[
                    HoverIcon(
                      icon: Icons.refresh,
                      color: theme.colorScheme.onSurfaceVariant,
                      tooltip: 'Refresh albums',
                      onTap: () {
                        final query = AlbumListQuery(filter.listType);
                        ref
                            .read(libraryRepositoryProvider)
                            ?.refreshAlbumList(query, force: true);
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!isDesktopPlatform) ...[
                    const MobileActiveDownloadsPill(),
                    const SizedBox(width: 8),
                    const OfflineModeToggle(),
                  ],
                ],
              ),
            ),
            const OfflineStatusBanner(),
            AlbumFilterTabs(
              selected: filter,
              onSelected: (f) {
                if (f == filter) {
                  // Re-tapping the active tab forces a fresh fetch from the server.
                  final query = AlbumListQuery(f.listType);
                  ref
                      .read(libraryRepositoryProvider)
                      ?.refreshAlbumList(query, force: true);
                } else {
                  ref.read(albumFilterProvider.notifier).state = f;
                }
              },
            ),
            Expanded(
              child: albumsAsync.when(
                data: (albums) => albums.isEmpty
                    ? Center(
                        child: Text(
                          isOffline
                              ? 'No offline cached albums'
                              : filter.emptyMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final query = AlbumListQuery(filter.listType);
                          await ref
                              .read(libraryRepositoryProvider)
                              ?.refreshAlbumList(query, force: true);
                        },
                        child: AlbumGrid(
                          albums: albums,
                          indexBy: albumIndexKey(filter, offline: isOffline),
                        ),
                      ),
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

/// What a tab's albums are sorted on, for the A–Z index, or null for a tab
/// not sorted by name.
///
/// All, online, is the server's alphabetical list, which leaves a leading
/// "The" off ("The Wall" is among the W's). Downloaded albums, and All while
/// offline, come from the local database sorted on the name as written.
String Function(Album)? albumIndexKey(
  AlbumFilter filter, {
  required bool offline,
}) {
  if (filter.listType != AlbumListType.alphabeticalByName) return null;
  if (filter == AlbumFilter.downloaded || offline) return (a) => a.name;
  return (a) => withoutLeadingArticle(a.name);
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
///
/// With [indexBy] — what the albums are sorted on — a grid of at least
/// [kAlphabetIndexMinItems] albums gets the A–Z index. Leave it null for any
/// order that is not by name: letters mean nothing on Recently Added.
class AlbumGrid extends ConsumerStatefulWidget {
  const AlbumGrid({super.key, required this.albums, this.indexBy});

  final List<Album> albums;
  final String Function(Album album)? indexBy;

  @override
  ConsumerState<AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends ConsumerState<AlbumGrid> {
  static const _spacing = 12.0;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the row holding [letter]'s first album to the top. Every row is
  /// one height, so its offset is its number times that height.
  ///
  /// The furthest it can go is worked out here too, not read from the scroll
  /// position: a grid that grew below the rows on screen — the rest of a
  /// genre arriving after its first 500 — keeps its old length there until it
  /// next scrolls, and clamping to that stopped every letter at the 500th.
  void _jumpTo(
    String letter,
    Map<String, int> firstRows, {
    required int columns,
    required double rowExtent,
    required EdgeInsets padding,
  }) {
    final index = rowForLetter(letter, firstRows);
    if (index == null || !_scroll.hasClients) return;
    final rows = (widget.albums.length / columns).ceil();
    final length =
        padding.vertical + rows * rowExtent + math.max(0, rows - 1) * _spacing;
    final furthest = math.max(0.0, length - _scroll.position.viewportDimension);
    final offset = padding.top + (index ~/ columns) * (rowExtent + _spacing);
    _scroll.jumpTo(offset.clamp(0.0, furthest));
  }

  @override
  Widget build(BuildContext context) {
    final albums = widget.albums;
    final maxExtent = artGridExtent(context);
    final labelExtent = artGridLabelExtent(context);
    final downloadedAlbumIds =
        ref.watch(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final anyDownloadedAlbumIds =
        ref.watch(anyDownloadedAlbumIdsProvider).valueOrNull ?? const {};
    final indexBy = widget.indexBy;
    final indexed = indexBy != null && albums.length >= kAlphabetIndexMinItems;
    // The strip sits over the right edge, so the tiles stop short of it.
    final padding = EdgeInsets.fromLTRB(
      12,
      12,
      indexed ? kAlphabetScrollerWidth + 4 : 12,
      12,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        // The tile's height is derived from its width rather than from a fixed
        // childAspectRatio. A ratio cannot say "square art plus two lines": it
        // gave the art whatever was left over, which was taller than it was
        // wide, and CoverArtImage's BoxFit.cover then cropped every sleeve.
        final tileWidth = artGridTileWidth(width, maxExtent, _spacing);
        final rowExtent = tileWidth + labelExtent;

        final grid = GridView.builder(
          controller: _scroll,
          padding: padding,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: rowExtent,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final isFullyCached = downloadedAlbumIds.contains(album.id);
            return AlbumGridTile(
              album: album,
              fullyCached: isFullyCached,
              partiallyCached:
                  anyDownloadedAlbumIds.contains(album.id) && !isFullyCached,
            );
          },
        );
        if (!indexed) return grid;

        final firstRows = firstRowByLetter([
          for (final album in albums) indexBy(album),
        ]);
        return AlphabetScroller(
          available: firstRows.keys.toSet(),
          onLetter: (letter) => _jumpTo(
            letter,
            firstRows,
            columns: artGridColumns(width, maxExtent, _spacing),
            rowExtent: rowExtent,
            padding: padding,
          ),
          child: grid,
        );
      },
    );
  }
}
