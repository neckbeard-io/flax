import 'package:flax/domain/enums.dart';

/// When cached data is allowed to be believed. Issue #8.
///
/// The primary mechanism is **not** a TTL. Subsonic exposes a scan beacon —
/// `getScanStatus` returns `lastScan` and a song `count` in 285 bytes — and if
/// neither has moved since the last sync then no library content changed,
/// provably. TTLs are the fallback for servers whose beacon cannot be trusted,
/// and the ceiling for user annotations, which the beacon cannot see at all.
///
/// Two independent change domains, and only one has a beacon:
///
/// - **Library content** — new albums, retagged files, deletions. Changes only
///   when the server scans. Fully covered.
/// - **Annotations** — stars, ratings, play counts. Change when someone hearts
///   a track in the web UI or plays it on a phone. `lastScan` does not move,
///   and Subsonic has no "annotations modified since" call. These reconcile
///   opportunistically instead.
abstract final class SyncPolicy {
  /// Album orderings that reorder as the library grows.
  static const volatileList = Duration(hours: 1);

  /// Orderings that only change when the library itself does.
  static const stableList = Duration(hours: 24);

  /// Track listings effectively never change once an album is tagged.
  static const albumDetail = Duration(days: 7);

  static const artistDetail = Duration(days: 7);

  static const playlists = Duration(hours: 1);

  /// `getStarred2` measured at ~2s against a real server — a small payload but
  /// an expensive query. On app focus or an explicit refresh, never a timer.
  static const starred = Duration(minutes: 30);

  /// How long the beacon's verdict is trusted before it is asked again.
  static const beaconCheck = Duration(minutes: 5);

  static Duration forList(AlbumListType type) => switch (type) {
    AlbumListType.newest ||
    AlbumListType.recent ||
    AlbumListType.frequent => volatileList,
    // Never reaches a TTL check — it is not cached at all.
    AlbumListType.random => Duration.zero,
    _ => stableList,
  };

  /// True when [fetchedAt] is old enough that [ttl] has expired.
  ///
  /// A null [fetchedAt] means nothing has ever been fetched, which is stale by
  /// definition rather than fresh — getting that backwards is how a cold cache
  /// renders as an empty library.
  static bool isStale(DateTime? fetchedAt, Duration ttl, DateTime now) {
    if (fetchedAt == null) return true;
    return now.difference(fetchedAt) >= ttl;
  }
}

/// What the beacon told us. Tri-state on purpose.
///
/// "The server did not answer" is not the same as "nothing changed", and
/// collapsing the two breaks in one direction or the other: treat unknown as
/// unchanged and the cache never refreshes again; treat it as changed and the
/// TTL is bypassed on every single read, which is what a fallback is for.
enum BeaconVerdict {
  /// Proven unchanged. Skip the refresh however stale the cache looks.
  unchanged,

  /// The library moved. Refresh even if the TTL had not expired.
  changed,

  /// A scan is running, so the server's own view is inconsistent. Wait.
  scanning,

  /// No usable beacon. Fall back to time-based staleness.
  unknown,
}

/// What the scan beacon said, and whether it moved.
class ScanBeacon {
  const ScanBeacon({this.lastScan, this.songCount, this.scanning = false});

  final String? lastScan;
  final int? songCount;

  /// A scan is in progress. Crawling now caches a half-indexed library, so the
  /// right response is to wait rather than to fetch.
  final bool scanning;

  /// Whether anything in the library could have changed since [previous].
  ///
  /// Unknown values mean "assume changed". A server that reports nothing useful
  /// must fall through to the TTL path, not be treated as permanently fresh —
  /// that would be a cache that never refreshes.
  bool changedSince(ScanBeacon? previous) {
    if (previous == null) return true;
    if (lastScan == null || previous.lastScan == null) return true;
    return lastScan != previous.lastScan || songCount != previous.songCount;
  }

  @override
  bool operator ==(Object other) =>
      other is ScanBeacon &&
      other.lastScan == lastScan &&
      other.songCount == songCount &&
      other.scanning == scanning;

  @override
  int get hashCode => Object.hash(lastScan, songCount, scanning);
}
