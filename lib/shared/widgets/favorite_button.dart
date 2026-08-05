import 'package:flutter/material.dart';

/// Heart toggle for a track, album, or artist.
///
/// Subsonic calls this "starred", which collides confusingly with the separate
/// 0-5 star *rating* — they are two independent fields on the same entity. The
/// heart glyph keeps them visually distinct, matching how Navidrome clients
/// present it.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 18,
    this.tooltip,
  });

  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: size,
        color: isFavorite
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: size + 12,
        minHeight: size + 12,
      ),
      tooltip: tooltip ?? (isFavorite ? 'Remove from favorites' : 'Add to favorites'),
      onPressed: onToggle,
    );
  }
}
