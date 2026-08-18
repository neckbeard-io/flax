import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The on-disk cache for cover art, sized for a music library rather than for
/// `flutter_cache_manager`'s defaults.
///
/// **Why this is not the default manager.** `CachedNetworkImage` with no manager
/// uses `DefaultCacheManager`, which is `Config('libCachedImageData')` — and
/// [Config] defaults to **200 cache objects**. Two hundred files is a handful of
/// screens: one desktop album grid is two dozen at 512px, and every artist
/// avatar, track thumbnail and header image competes for the same two hundred
/// slots. Art that scrolled past is evicted and fetched again next time.
///
/// **What re-fetching actually costs, measured against a real Navidrome server.**
/// Once the server holds an artist's image, a thumbnail is ~300–550ms; a screenful
/// of eighteen lands in about half a second. But the *first* time an artist's art
/// is asked for, the server has to resolve it, and that cost is much larger —
/// eighteen first-time artists took 4.4 seconds, after which every later size of
/// the same artists was back to the ~500ms figure. So evicting art is not just a
/// repeated round trip; it risks re-paying the expensive path for anything the
/// server has also forgotten. Keeping art is worth far more than the disk.
///
/// The download concurrency is deliberately left at [FileService]'s default of 10.
/// Raising it to 20 was tried and measured no better once the server-side warmth
/// was controlled for, and these requests make a small self-hosted server do real
/// work — a client that opens fifty sockets to be first is not being a good guest.
///
/// 4000 objects at cover-art sizes is a few hundred megabytes at worst, in the OS
/// cache directory, which the system may reclaim and a user can clear. A stale
/// period of a year rather than 30 days keeps a library you browse seasonally from
/// going cold.
///
/// Its own cache key, not the default `libCachedImageData`, so the settings here
/// govern a store that only flax writes.
class ArtCache {
  ArtCache._();

  static const key = 'flaxArtCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 50000,
    ),
  );

  /// Widens Flutter's *decoded* image cache, which is a different cache from the
  /// one above and the reason scrolling back to art you just looked at could
  /// still stutter.
  ///
  /// [ImageCache] defaults to 100 MiB. A 512px album cover decodes to roughly
  /// 512 × 512 × 4 = 1 MB of bitmap, so about a hundred covers fill it — less
  /// than a couple of screens of the desktop grid. Past that, scrolling back up
  /// re-reads the file and decodes it again, which is work we already did.
  ///
  /// The bytes are real resident memory, not disk, which is why the desktop and
  /// phone numbers differ. Flutter still evicts under pressure; this only raises
  /// the ceiling.
  ///
  /// Call once, before `runApp`.
  static void configureDecodedImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    cache.maximumSizeBytes = (desktop ? 256 : 96) << 20;
    // Thumbnails are small enough that the byte budget, not the count, should be
    // what evicts: 4000 avatars at 128px is well under the desktop budget.
    cache.maximumSize = 2000;
  }
}
