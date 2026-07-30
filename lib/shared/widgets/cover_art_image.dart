import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/server_provider.dart';

class CoverArtImage extends ConsumerWidget {
  final String? coverArtId;
  final double? size;
  final BorderRadius? borderRadius;

  const CoverArtImage({
    super.key,
    this.coverArtId,
    this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(subsonicClientProvider);

    if (coverArtId == null || client == null) {
      return _placeholder(context);
    }

    final requestSize = size != null ? (size! * 2).toInt() : null;
    final uri = client.getCoverArtUri(
      coverArtId!,
      size: requestSize,
    );

    return CachedNetworkImage(
      imageUrl: uri.toString(),
      cacheKey: 'cover-$coverArtId-$requestSize',
      fit: BoxFit.cover,
      placeholder: (context, url) => _placeholder(context),
      errorWidget: (context, url, error) {
        developer.log('CoverArt error for $coverArtId: $error', name: 'CoverArtImage');
        developer.log('URL: $url', name: 'CoverArtImage');
        return _placeholder(context);
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = size != null ? (size! * 0.4).clamp(16.0, 48.0) : 24.0;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note,
          color: theme.colorScheme.onSurfaceVariant,
          size: iconSize,
        ),
      ),
    );
  }
}
