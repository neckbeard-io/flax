import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/shared/widgets/art_cache.dart';
import 'package:flax/shared/widgets/settle_gate.dart';

/// Cover art for an album, artist, or track.
///
/// The fetched resolution is derived from how large the image is actually laid
/// out, multiplied by the device pixel ratio — not from a number passed by the
/// call site. Those numbers were tuned for a phone-width grid and left desktop
/// art visibly soft: the album grid asked for 360px and then drew it across
/// ~560 physical pixels, upscaling every tile.
class CoverArtImage extends ConsumerWidget {
  const CoverArtImage({
    super.key,
    this.coverArtId,
    this.size,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String? coverArtId;

  /// Fallback edge length in logical pixels, used only when the widget is laid
  /// out unbounded and the real size cannot be measured. Call sites that sit
  /// inside a sized box can leave this null.
  final double? size;

  final BorderRadius? borderRadius;

  /// How to fit the image. [BoxFit.cover] fills the box and crops, which suits
  /// square album art; artist photos are often not square, so a hero image may
  /// want [BoxFit.contain] to avoid cropping into a face.
  final BoxFit fit;

  /// Server-side thumbnails are requested in steps rather than at the exact
  /// measured size, so that a few pixels of layout difference — a resized
  /// window, a slightly different grid — reuses a cached image instead of
  /// fetching a near-identical one.
  static const _steps = <int>[64, 128, 256, 384, 512, 768, 1024, 1536, 2048];

  /// Rounds up to the next step. Above the largest step the size parameter is
  /// dropped entirely, which makes Subsonic return the original file — the right
  /// answer for a full-window hero image.
  static int? _requestSize(double logical, double devicePixelRatio) {
    final physical = (logical * devicePixelRatio).ceil();
    for (final step in _steps) {
      if (physical <= step) return step;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(subsonicClientProvider);
    if (coverArtId == null || client == null) {
      return _placeholder(context);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Prefer the real box. Either axis may be unbounded (inside a scroll
        // view, say), so fall back to whichever is finite, then to `size`.
        final candidates = <double>[
          if (constraints.hasBoundedWidth) constraints.maxWidth,
          if (constraints.hasBoundedHeight) constraints.maxHeight,
          if (size != null) size!,
        ];
        final logical = candidates.isEmpty
            ? 256.0
            : candidates.reduce((a, b) => math.max(a, b));

        final requestSize = _requestSize(logical, dpr);
        final uri = client.getCoverArtUri(coverArtId!, size: requestSize);

        final image = CachedNetworkImage(
          imageUrl: uri.toString(),
          // Not the default 200-object cache — see [ArtCache].
          cacheManager: ArtCache.instance,
          // Keyed by the requested step, so the same art at different sizes is
          // cached separately rather than one size winning.
          cacheKey: 'cover-$coverArtId-${requestSize ?? "orig"}',
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (context, url) => _placeholder(context),
          errorWidget: (context, url, error) {
            developer.log(
              'CoverArt error for $coverArtId: $error',
              name: 'CoverArtImage',
            );
            return _placeholder(context);
          },
        );

        // Held back if this was built mid-fling: the download queue underneath
        // is FIFO and cannot be cancelled, so a request made for a row that is
        // already gone delays the rows you stopped on. See [SettleGate].
        return SettleGate(
          placeholder: _placeholder(context),
          child: borderRadius == null
              ? image
              : ClipRRect(borderRadius: borderRadius!, child: image),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = size != null ? (size! * 0.4).clamp(16.0, 48.0) : 24.0;
    final box = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note,
          color: theme.colorScheme.onSurfaceVariant,
          size: iconSize,
        ),
      ),
    );
    if (borderRadius == null) return box;
    return ClipRRect(borderRadius: borderRadius!, child: box);
  }
}
