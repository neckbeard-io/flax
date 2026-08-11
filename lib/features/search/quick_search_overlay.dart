import 'package:flutter/material.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/search/quick_search.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

/// One row of the quick-search popup, flattened across both kinds so the
/// keyboard can walk them as a single list.
class QuickSearchItem {
  const QuickSearchItem.artist(Artist this.artist) : album = null;
  const QuickSearchItem.album(Album this.album) : artist = null;

  final Artist? artist;
  final Album? album;

  bool get isArtist => artist != null;

  /// Where selecting this row goes.
  String get route =>
      isArtist ? '/artists/${artist!.id}' : '/albums/${album!.id}';
}

/// Flattens results into the order the popup draws them: artists, then albums.
List<QuickSearchItem> quickSearchItems(QuickSearchResults results) => [
  for (final a in results.artists) QuickSearchItem.artist(a),
  for (final a in results.albums) QuickSearchItem.album(a),
];

/// The panel that drops out of the sidebar search field.
///
/// Presentational: it is handed results and a highlight, and reports taps. The
/// field owns the query, the focus and the keyboard, because those all have to
/// stay with the thing being typed into.
class QuickSearchPanel extends StatelessWidget {
  const QuickSearchPanel({
    super.key,
    required this.items,
    required this.highlighted,
    required this.onSelected,
    required this.onSearchEverything,
    required this.query,
    this.loading = false,
  });

  final List<QuickSearchItem> items;

  /// Index into [items], or -1 for nothing highlighted.
  final int highlighted;

  final ValueChanged<QuickSearchItem> onSelected;
  final VoidCallback onSearchEverything;
  final String query;
  final bool loading;

  static const double width = 380;
  static const double maxHeight = 460;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: width,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: items.isEmpty
                  ? _EmptyState(loading: loading, theme: theme)
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final first = i == 0;
                        final firstAlbum =
                            !item.isArtist && (i == 0 || items[i - 1].isArtist);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (first || firstAlbum)
                              _Heading(
                                text: item.isArtist ? 'Artists' : 'Albums',
                                theme: theme,
                              ),
                            _ResultRow(
                              item: item,
                              highlighted: i == highlighted,
                              onTap: () => onSelected(item),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Always present, so the popup never becomes a dead end — songs
            // and everything else live one keystroke away.
            _SearchEverythingRow(
              query: query,
              onTap: onSearchEverything,
              highlighted: highlighted == items.length,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading, required this.theme});

  final bool loading;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        // No spinner. Results land in a fraction of a second and one that
        // appears and vanishes between keystrokes reads as flicker.
        loading ? 'Searching…' : 'No artists or albums match',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.highlighted,
    required this.onTap,
  });

  final QuickSearchItem item;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = SizedBox(
      width: 36,
      height: 36,
      child: CoverArtImage(
        coverArtId: item.isArtist
            ? item.artist!.coverArtId
            : item.album!.coverArtId,
        size: 72,
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        // The highlight is the keyboard's cursor, so it has to be visible
        // without the pointer being anywhere near it.
        color: highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            item.isArtist
                ? ClipOval(child: art)
                : ClipRRect(borderRadius: BorderRadius.circular(4), child: art),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.isArtist ? item.artist!.name : item.album!.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!item.isArtist && item.album!.artistName != null)
                    Text(
                      item.album!.artistName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEverythingRow extends StatelessWidget {
  const _SearchEverythingRow({
    required this.query,
    required this.onTap,
    required this.highlighted,
    required this.theme,
  });

  final String query;
  final VoidCallback onTap;
  final bool highlighted;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.manage_search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search everything for "$query"',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '↵',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
