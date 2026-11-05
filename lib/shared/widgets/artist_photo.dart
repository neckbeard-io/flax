import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';

/// An artist's photo, from the URL the server gave for it.
///
/// Read through the art store, under the URL downloads store it by. These used
/// to read `CachedNetworkImage`'s default cache, a different store that the
/// system may empty, so a downloaded artist's photo was never found offline.
/// Offline the network is never asked.
class ArtistPhoto extends ConsumerWidget {
  const ArtistPhoto({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String url;

  /// Shown while loading, and when the photo can't be had.
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOfflineModeProvider)) {
      return _StoredPhoto(url: url, fallback: fallback, fit: fit);
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: ref.watch(artCacheProvider),
      fit: fit,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _StoredPhoto extends ConsumerStatefulWidget {
  const _StoredPhoto({
    required this.url,
    required this.fallback,
    required this.fit,
  });

  final String url;
  final Widget fallback;
  final BoxFit fit;

  @override
  ConsumerState<_StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends ConsumerState<_StoredPhoto> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = _find();
  }

  @override
  void didUpdateWidget(_StoredPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _file = _find();
  }

  Future<File?> _find() async {
    try {
      return (await ref.read(artCacheProvider).getFileFromCache(widget.url))
          ?.file;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _file,
    builder: (context, snapshot) {
      final file = snapshot.data;
      if (file == null) return widget.fallback;
      return Image.file(
        file,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    },
  );
}
