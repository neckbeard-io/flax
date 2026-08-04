import 'package:flutter/material.dart';

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

          final star = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: widget.size,
              color: isFilled
                  ? (isPreview ? Colors.amber[300] : Colors.amber[600])
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          );

          if (!interactive) return star;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => _setHovered(starValue),
            child: GestureDetector(
              onTap: () => widget.onRatingChanged!(
                starValue == widget.rating ? 0 : starValue,
              ),
              child: star,
            ),
          );
        }),
      ),
    );
  }
}
