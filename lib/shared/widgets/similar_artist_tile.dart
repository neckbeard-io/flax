import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// A similar artist: picture over name, both opening the artist.
///
/// Now Playing's artist panel draws [size] 80 with rounded corners; the artist
/// page draws larger circles.
class SimilarArtistTile extends StatelessWidget {
  const SimilarArtistTile({
    super.key,
    required this.artist,
    this.onTap,
    this.size = 80,
    this.circular = false,
  });

  final SimilarArtist artist;
  final VoidCallback? onTap;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: HoverArtwork(
              onTap: onTap,
              borderRadius: BorderRadius.circular(circular ? size / 2 : 8),
              child: _buildArtwork(artist.coverArtId),
            ),
          ),
          const SizedBox(height: 6),
          HoverLink(
            text: artist.name,
            maxLines: 2,
            onTap: onTap,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.2,
              fontWeight: circular ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(String? coverArtId) {
    final fallback = CoverArtImage(size: size);
    if (coverArtId == null || coverArtId.isEmpty) return fallback;
    if (coverArtId.startsWith('http://') || coverArtId.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: coverArtId,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      );
    }
    return CoverArtImage(coverArtId: coverArtId, size: size);
  }
}
