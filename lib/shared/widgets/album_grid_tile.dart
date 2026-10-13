import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// One album in an art grid: square cover, download badge, and two lines of
/// label under it.
///
/// Lay it out in a cell whose height is the tile's width plus
/// `artGridLabelExtent`: the art takes the width as its height, and the labels
/// fit the fixed extent below it.
class AlbumGridTile extends StatelessWidget {
  const AlbumGridTile({
    super.key,
    required this.album,
    this.fullyCached = false,
    this.partiallyCached = false,
    this.secondLine,
  });

  final Album album;
  final bool fullyCached;
  final bool partiallyCached;

  /// What goes under the name. The album's artist, linked, when null — which
  /// is what a grid of many artists' albums wants; a page that is already one
  /// artist's passes something more useful.
  final Widget? secondLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void open() => context.push('/albums/${album.id}');

    return AlbumContextMenu(
      album: album,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: HoverArtwork(
                    onTap: open,
                    // No explicit size: CoverArtImage measures its own box and
                    // fetches to match, so a wider desktop tile pulls a
                    // correspondingly larger image.
                    child: CoverArtImage(coverArtId: album.coverArtId),
                  ),
                ),
                if (fullyCached || partiallyCached)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        fullyCached
                            ? Icons.offline_pin
                            : Icons.offline_pin_outlined,
                        size: 14,
                        color: fullyCached
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          HoverLink(
            text: album.name,
            onTap: open,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          secondLine ??
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
  }
}
