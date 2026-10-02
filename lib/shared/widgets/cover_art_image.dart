import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';
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

  /// Rounds up to the next step in [coverSizeSteps]. Above the largest step the size parameter is
  /// dropped entirely, which makes Subsonic return the original file — the right
  /// answer for a full-window hero image.
  static int? _requestSize(double logical, double devicePixelRatio) {
    final physical = (logical * devicePixelRatio).ceil();
    for (final step in coverSizeSteps) {
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
    final cache = ref.watch(artCacheProvider);
    final offline = ref.watch(isOfflineModeProvider);

    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Prefer the real box. Either axis may be unbounded (inside a scroll
        // view, say), so fall back to whichever is finite, then to `size`.
        final candidates = <double>[
          if (constraints.hasBoundedWidth) constraints.maxWidth,
          if (constraints.hasBoundedHeight) constraints.maxHeight,
          ?size,
        ];
        final logical = candidates.isEmpty
            ? 256.0
            : candidates.reduce((a, b) => math.max(a, b));

        final requestSize = _requestSize(logical, dpr);

        // Offline, the network is never asked: whatever size of this cover
        // was stored — by a download, a metadata sync, or an earlier look —
        // is used and scaled. Asking only for the exact size is why
        // downloaded art used to show on one screen and not the next.
        if (offline) {
          return _clip(
            _LocalCover(
              coverArtId: coverArtId!,
              requestSize: requestSize,
              fit: fit,
              placeholder: _placeholder(context),
            ),
          );
        }

        final uri = client.getCoverArtUri(coverArtId!, size: requestSize);
        final cacheKey = coverCacheKey(coverArtId!, requestSize);

        // Nothing for the gate to protect: show it now. Without this, scrolling
        // back over art you were just looking at stutters, which is a worse
        // artifact than the one the gate was added to fix.
        //
        // [ImageCache.containsKey] is true for decoded *or* pending entries, and
        // both are right here. Decoded means it paints this frame. Pending means a
        // request for this exact key is already in flight, so mounting adds nothing
        // to the download queue — which is the only thing the gate is rationing.
        //
        // The lookup is synchronous and cheap. CachedNetworkImageProvider's
        // identity is `(cacheKey ?? url, scale, maxHeight, maxWidth)` and
        // deliberately excludes the cache manager, so an equal provider built here
        // finds the entry CachedNetworkImage put there.
        final decoded = PaintingBinding.instance.imageCache.containsKey(
          CachedNetworkImageProvider(uri.toString(), cacheKey: cacheKey),
        );

        final image = CachedNetworkImage(
          imageUrl: uri.toString(),
          // Not the default 200-object cache — see [ArtCache].
          cacheManager: cache,
          // Keyed by the requested step, so the same art at different sizes is
          // cached separately rather than one size winning.
          cacheKey: cacheKey,
          fit: fit,
          // No fade for art that is already decoded — it is on screen this frame,
          // and fading it in is the same flicker the gate bypass exists to avoid.
          fadeInDuration: decoded
              ? Duration.zero
              : const Duration(milliseconds: 120),
          placeholder: (context, url) => _placeholder(context),
          errorWidget: (context, url, error) {
            AppLogger.w('CoverArt', 'CoverArt error for $coverArtId: $error');
            // The server could not supply this size; another stored size of
            // the same cover still beats a placeholder.
            return _LocalCover(
              coverArtId: coverArtId!,
              requestSize: requestSize,
              fit: fit,
              placeholder: _placeholder(context),
            );
          },
        );

        // Held back if this was built mid-scroll: the download queue underneath
        // is FIFO and cannot be cancelled, so a request made for a row that is
        // already gone delays the rows you stopped on. See [SettleGate]. Art
        // already in memory has no request to make, so it skips the wait.
        return SettleGate(
          bypass: decoded,
          placeholder: _placeholder(context),
          child: _clip(image),
        );
      },
    );
  }

  Widget _clip(Widget child) => borderRadius == null
      ? child
      : ClipRRect(borderRadius: borderRadius!, child: child);

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

/// A cover read from the local cache only — any stored size, scaled to fit.
class _LocalCover extends ConsumerStatefulWidget {
  const _LocalCover({
    required this.coverArtId,
    required this.requestSize,
    required this.fit,
    required this.placeholder,
  });

  final String coverArtId;
  final int? requestSize;
  final BoxFit fit;
  final Widget placeholder;

  @override
  ConsumerState<_LocalCover> createState() => _LocalCoverState();
}

class _LocalCoverState extends ConsumerState<_LocalCover> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_LocalCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverArtId != widget.coverArtId ||
        oldWidget.requestSize != widget.requestSize) {
      _resolve();
    }
  }

  void _resolve() {
    _file = CoverArtCache.findCached(
      ref.read(artCacheProvider),
      widget.coverArtId,
      preferredSize: widget.requestSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final known = CoverArtCache.knownPath(
      widget.coverArtId,
      size: widget.requestSize,
    );
    if (known != null) return _image(File(known));
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        return file == null ? widget.placeholder : _image(file);
      },
    );
  }

  Widget _image(File file) => Image.file(
    file,
    fit: widget.fit,
    // Decode at the size it is drawn, not the size it was stored: an original
    // stands in for a thumbnail without costing its full bitmap in memory.
    cacheWidth: widget.requestSize,
    gaplessPlayback: true,
    errorBuilder: (context, error, stackTrace) {
      // Evicted since it was found; stop pointing at it.
      CoverArtCache.forget(widget.coverArtId);
      return widget.placeholder;
    },
  );
}
