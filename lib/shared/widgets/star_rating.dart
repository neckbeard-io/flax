import 'package:flutter/material.dart';

import 'package:flax/shared/widgets/hover_effects.dart';

/// The 0-5 `userRating` of a track, album, or artist.
///
/// Not to be confused with the favorite heart beside it — see [FavoriteButton].
/// Subsonic calls the favorite flag "starred", so the two are easy to conflate
/// in the API and must never be conflated on screen.
class StarRating extends StatefulWidget {
  final int rating;
  final int maxRating;
  final double size;
  final ValueChanged<int>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 20,
    this.onRatingChanged,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  /// Star currently under the pointer (1-based), or 0 when not hovering.
  int _hovered = 0;

  void _setHovered(int value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = widget.onRatingChanged != null;

    // While hovering, preview the rating the click would apply.
    final shown = _hovered > 0 ? _hovered : widget.rating;

    return MouseRegion(
      onExit: (_) => _setHovered(0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.maxRating, (index) {
          final starValue = index + 1;
          final isFilled = starValue <= shown;
          final isPreview = _hovered > 0;

          final icon =
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded;
          final color = isFilled
              ? (isPreview ? Colors.amber[300]! : Colors.amber[600]!)
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

          if (!interactive) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(icon, size: widget.size, color: color),
            );
          }

          return HoverIcon(
            icon: icon,
            size: widget.size,
            color: color,
            // The run already answers "is this clickable" by filling ahead of
            // the pointer; recolouring the hovered star as well would fight
            // the preview it is showing.
            hoverColor: color,
            // Five overlapping discs in a row read as clutter, not as five
            // buttons. The preview and the lift carry it instead.
            backdrop: false,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            onHoverChanged: (hovering) {
              if (hovering) _setHovered(starValue);
            },
            onTap: () => widget.onRatingChanged!(
              // Clicking the star you are already rated at clears the rating —
              // otherwise there is no way back to unrated.
              starValue == widget.rating ? 0 : starValue,
            ),
          );
        }),
      ),
    );
  }
}
