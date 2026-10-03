import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/shared/widgets/art_cache.dart';

/// The cover-art store every reader goes through. Overridden in tests.
final artCacheProvider = Provider<BaseCacheManager>((ref) => ArtCache.instance);

/// Server-side thumbnail sizes, in physical pixels.
///
/// Covers are requested in steps rather than at the exact measured size, so
/// that a few pixels of layout difference — a resized window, a slightly
/// different grid — reuses a cached image instead of fetching a near-identical
/// one. Above the largest step the size is dropped and the original is used.
const coverSizeSteps = <int>[64, 128, 256, 384, 512, 768, 1024, 1536, 2048];

/// The name a cover is stored under: `cover-<id>-<size>`, or `-orig` for the
/// full-size original.
String coverCacheKey(String coverArtId, int? size) =>
    'cover-$coverArtId-${size ?? 'orig'}';

/// A stored copy of a cover and the size it was stored at, null for the
/// original.
typedef StoredCover = ({File file, int? size});

/// Finding and storing covers so a downloaded album shows its art without the
/// server.
///
/// Each size of a cover is its own cache entry, and each screen asks for the
/// step that fits its layout on this display. Online a missing size is one
/// request away. Offline it meant a cover showed only if that exact size
/// happened to be cached, which is why downloaded art came and went. Reads go
/// through [findCached], which takes the requested size if it is there and any
/// other stored size of the same cover if not.
class CoverArtCache {
  CoverArtCache._();

  /// Files found this session: cover id, then stored size (null for the
  /// original), to path.
  static final Map<String, Map<int?, String>> _known = {};

  /// A cached file for [coverArtId] already found this session, chosen the
  /// way [findCached] chooses, without touching disk. Lets synchronous code
  /// such as the media session use a cover the moment it is known.
  static String? knownPath(String coverArtId, {int? size}) {
    final known = _known[coverArtId];
    if (known == null) return null;
    for (final candidate in _candidateSizes(size)) {
      final path = known[candidate];
      if (path != null) return path;
    }
    return null;
  }

  static void _remember(String coverArtId, int? size, String path) =>
      (_known[coverArtId] ??= {})[size] = path;

  /// Sizes to try, best first: the requested size, larger sizes (they scale
  /// down cleanly), the original, then smaller sizes.
  static List<int?> _candidateSizes(int? preferredSize) {
    final larger = <int>[];
    final smaller = <int>[];
    for (final step in coverSizeSteps) {
      if (preferredSize == null || step < preferredSize) {
        smaller.add(step);
      } else if (step > preferredSize) {
        larger.add(step);
      }
    }
    return [?preferredSize, ...larger, null, ...smaller.reversed];
  }

  /// Cache keys to try for [coverArtId], best first; see [_candidateSizes].
  static List<String> candidateKeys(String coverArtId, int? preferredSize) => [
    for (final size in _candidateSizes(preferredSize))
      coverCacheKey(coverArtId, size),
  ];

  /// Whether a copy stored at [size] is at least [wanted]. The original is at
  /// least anything; only the original is at least the original.
  static bool isAtLeast(int? size, int? wanted) =>
      size == null || (wanted != null && size >= wanted);

  /// Whether a copy stored at [size] is bigger than one stored at [than].
  static bool isLarger(int? size, int? than) =>
      size != than && isAtLeast(size, than);

  /// The best stored copy of [coverArtId] and its size, or null when no size
  /// of it is cached. Never touches the network.
  static Future<StoredCover?> findStored(
    BaseCacheManager cache,
    String coverArtId, {
    int? preferredSize,
  }) async {
    for (final size in _candidateSizes(preferredSize)) {
      final info = await cache.getFileFromCache(
        coverCacheKey(coverArtId, size),
      );
      if (info == null) continue;
      _remember(coverArtId, size, info.file.path);
      return (file: info.file, size: size);
    }
    return null;
  }

  /// The best stored file for [coverArtId]; see [findStored].
  static Future<File?> findCached(
    BaseCacheManager cache,
    String coverArtId, {
    int? preferredSize,
  }) async =>
      (await findStored(cache, coverArtId, preferredSize: preferredSize))?.file;

  /// Forgets every cover found this session.
  @visibleForTesting
  static void resetForTest() => _known.clear();

  /// Drops what this session remembers about [coverArtId], e.g. after its file
  /// turned out to be gone.
  static void forget(String coverArtId) => _known.remove(coverArtId);

  /// Stores [coverArtId] for offline use at [size], unless a copy at least
  /// that size is already stored.
  ///
  /// A smaller copy does not count. The mini player stores a thumbnail the
  /// moment a track plays, before the track is cached; when any size counted,
  /// that thumbnail stopped the cover being stored at the configured quality,
  /// and offline the car's Now Playing drew the thumbnail full-screen.
  static Future<void> storeForOffline(
    BaseCacheManager cache, {
    required String coverArtId,
    required int? size,
    required Uri url,
  }) async {
    final stored = await findStored(cache, coverArtId, preferredSize: size);
    if (stored != null && isAtLeast(stored.size, size)) return;
    try {
      final info = await cache.downloadFile(
        url.toString(),
        key: coverCacheKey(coverArtId, size),
      );
      _remember(coverArtId, size, info.file.path);
    } catch (e) {
      AppLogger.w('CoverArt', 'Could not store cover $coverArtId offline: $e');
    }
  }

  static const _rekeyedPrefKey = 'flax_cover_cache_rekeyed_v1';

  /// Runs [rekeyLegacyEntries] against the real store, once per install.
  static Future<void> rekeyLegacyEntriesOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_rekeyedPrefKey) ?? false) return;
      final moved = await rekeyLegacyEntries(
        repo: ArtCache.config.repo,
        cache: ArtCache.instance,
      );
      await prefs.setBool(_rekeyedPrefKey, true);
      AppLogger.i('CoverArt', 'Re-filed $moved covers stored by request URL');
    } catch (e, st) {
      AppLogger.w(
        'CoverArt',
        'Re-filing covers failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Re-files covers that downloads used to store under their full request
  /// URL.
  ///
  /// Those URLs carried a fresh salt each time, so nothing could ever look the
  /// files up again — the art was on disk and every screen still asked the
  /// server for it. The cover id and size are in the URL's query string, which
  /// is enough to file each one under [coverCacheKey] without downloading it
  /// again. Returns how many entries were moved.
  static Future<int> rekeyLegacyEntries({
    required CacheInfoRepository repo,
    required BaseCacheManager cache,
  }) async {
    await repo.open();
    final objects = await repo.getAllObjects();
    var moved = 0;
    for (final object in objects) {
      final uri = Uri.tryParse(object.key);
      if (uri == null || !uri.path.endsWith('/rest/getCoverArt')) continue;
      final id = uri.queryParameters['id'];
      if (id == null || id.isEmpty) continue;
      final size = int.tryParse(uri.queryParameters['size'] ?? '');
      final newKey = coverCacheKey(id, size);
      try {
        final old = await cache.getFileFromCache(object.key);
        if (old != null && await cache.getFileFromCache(newKey) == null) {
          await cache.putFile(
            object.url,
            await old.file.readAsBytes(),
            key: newKey,
            maxAge: const Duration(days: 365),
            fileExtension: _extension(old.file.path),
          );
        }
        await cache.removeFile(object.key);
        moved++;
      } catch (e) {
        AppLogger.w('CoverArt', 'Could not re-file cover $id: $e');
      }
    }
    return moved;
  }

  static String _extension(String path) {
    final ext = p.extension(path);
    return ext.length > 1 ? ext.substring(1) : 'jpg';
  }
}
