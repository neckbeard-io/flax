/// Cached orderings and sync bookkeeping. Issue #8.
///
/// The distinction from the entity tables is the one thing in this design that
/// is easy to get wrong: **a cached list is an ordered set of ids, not a set of
/// rows.** "Recently Added, page 1" is an ordering; the albums in it are
/// entities shared with every other view.
///
/// Keeping them apart means refreshing a list replaces its positions without
/// touching entity data, and an album that appears in five lists is stored once.
/// Conflating them gives five copies of every album and five places for a
/// favorite to go stale.
library;

import 'package:drift/drift.dart';

@DataClassName('AlbumListEntryRow')
class AlbumListEntries extends Table {
  TextColumn get serverId => text()();

  /// The `AlbumListType` name — `newest`, `recent`, `alphabetical`, and so on.
  ///
  /// `random` never appears here. Caching an ordering called "random" produces
  /// a shelf that never reshuffles, so that type bypasses this table entirely.
  TextColumn get listType => text()();

  /// Distinguishes otherwise identical lists that differ by filter — genre,
  /// year range. Empty string when the list takes no filter.
  TextColumn get filterKey => text().withDefault(const Constant(''))();

  IntColumn get position => integer()();
  TextColumn get albumId => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {serverId, listType, filterKey, position};
}

@DataClassName('PlaylistEntryRow')
class PlaylistEntries extends Table {
  TextColumn get serverId => text()();
  TextColumn get playlistId => text()();
  IntColumn get position => integer()();
  TextColumn get songId => text()();

  @override
  Set<Column> get primaryKey => {serverId, playlistId, position};
}

/// Per-server sync tokens. Without these the scan beacon has nothing to compare
/// against and every check degrades to a TTL guess.
///
/// Keys are the constants on `SyncKeys`.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  TextColumn get serverId => text()();
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {serverId, key};
}

/// The keys stored in [SyncStates].
abstract final class SyncKeys {
  /// `getScanStatus.lastScan` as of the last successful sync. Unchanged means
  /// no library content changed — provably, not probabilistically.
  static const lastScan = 'lastScan';

  /// `getScanStatus.count`. Checked alongside [lastScan] because a server that
  /// reports a stale timestamp can still report a moved song count.
  static const songCount = 'songCount';

  /// `getIndexes.lastModified`, fed back as `ifModifiedSince`. A matching value
  /// turns a 384 KiB response into 227 bytes.
  static const indexesLastModified = 'indexesLastModified';

  /// When the album/song crawl last completed.
  static const lastFullCrawlAt = 'lastFullCrawlAt';

  /// When the starred set was last reconciled. Separate because annotations
  /// change without a scan and the beacon is blind to them.
  static const lastStarredSyncAt = 'lastStarredSyncAt';
}
