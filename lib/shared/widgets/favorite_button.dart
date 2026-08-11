import 'package:flutter/material.dart';

import 'package:flax/shared/widgets/hover_effects.dart';

/// Heart toggle for a track, album, or artist.
///
/// Subsonic calls this "starred", which collides confusingly with the separate
/// 0-5 star *rating* — they are two independent fields on the same entity. The
/// heart glyph keeps them visually distinct, matching how Navidrome clients
/// present it.
///
/// Hover comes from [HoverIcon], shared with the star rating, so a heart in the
/// mini player behaves exactly like one in an album's track list.
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

    return HoverIcon(
      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
      size: size,
      color: isFavorite
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      onTap: onToggle,
      tooltip:
          tooltip ??
          (isFavorite ? 'Remove from favorites' : 'Add to favorites'),
    );
  }
}
