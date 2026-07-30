import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;

        return GestureDetector(
          onTap: onRatingChanged != null
              ? () => onRatingChanged!(starValue == rating ? 0 : starValue)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: isFilled
                  ? Colors.amber[600]
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        );
      }),
    );
  }
}
