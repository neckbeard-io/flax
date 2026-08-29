import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';

/// The library, read locally and refreshed in the background. Issue #8.
///
/// Reads are **streams**, not futures. That is the whole point: they are backed
/// by the local database, so they emit immediately (offline included) and emit
/// again when a refresh lands or a favorite changes — no manual invalidation,
/// and no screen holding its own stale copy.
///
/// Writes are optimistic. A favorite or a rating is written locally first, then
/// pushed; a failed push leaves the row `dirty` for retry rather than reverting
/// under the user.
abstract class LibraryRepository {
  Stream<List<Artist>> watchArtists();
  Stream<Artist?> watchArtist(String artistId);
  Stream<List<Album>> watchArtistAlbums(String artistId);
  Stream<List<Album>> watchAlbumList(AlbumListQuery query);
  Stream<Album?> watchAlbum(String albumId);
  Stream<List<Song>> watchAlbumSongs(String albumId);
  Stream<Song?> watchSong(String songId);

  /// A shuffle of the library. Like the Random album tab, this is never cached
  /// as an ordering — the rows are watched so annotations stay live, but the
  /// order belongs to the subscription.
  Stream<List<Song>> watchRandomSongs({int count = 100});

  /// Local substring search over cached entities. Instant, and works offline.
  /// The server is still asked separately to widen the result set.
  Stream<List<Album>> watchAlbumSearch(String query, {int limit = 20});
  Stream<List<Artist>> watchArtistSearch(String query, {int limit = 20});
  Stream<List<Song>> watchSongSearch(String query, {int limit = 20});

  /// Bring the artist list up to date if it is stale. Cheap when it is not —
  /// see [syncIfChanged].
  Future<void> refreshArtists({bool force = false});

  /// One artist and the albums `getArtist` returns alongside it.
  Future<void> refreshArtist(String artistId, {bool force = false});
  Future<void> refreshAlbumList(AlbumListQuery query, {bool force = false});
  Future<void> refreshAlbum(String albumId, {bool force = false});

  /// Ask the server whether anything changed, and refresh only if so.
  ///
  /// Returns true when the beacon moved. This is one 285-byte call against
  /// Navidrome, so it is cheap enough to run on app focus.
  /// Run the server's search and cache whatever entities it returns.
  ///
  /// The *results* are deliberately not cached — queries are unbounded, and a
  /// results table would grow without limit. Caching the entities is what makes
  /// the local search widen as the library gets browsed, and what lets search
  /// work at all with no network.
  Future<void> cacheSearch(
    String query, {
    int artistCount = 20,
    int albumCount = 20,
    int songCount = 20,
  });

  Future<bool> syncIfChanged();

  /// Reconcile favorites with the server, and retry anything still pending.
  ///
  /// Separate from [syncIfChanged] because annotations are the change domain the
  /// scan beacon cannot see. Rate-limited internally, because `getStarred2` is
  /// the one expensive call here.
  Future<void> syncAnnotations({bool force = false});

  /// Sweep entities the server has stopped mentioning. Cheap, and safe to call
  /// on a schedule — favorites, ratings and anything still in a cached list are
  /// kept regardless of age.
  Future<int> collectGarbage();

  /// Stars are ratings, hearts are favorites — two independent fields. These
  /// two methods must never write each other's column.
  Future<void> setFavorite(EntityRef ref, {required bool favorite});
  Future<void> setRating(EntityRef ref, {required int rating});

  // ── Downloads & Offline Cache ───────────────────────────────────────────

  Stream<Set<String>> watchDownloadedSongIds();
  Stream<Set<String>> watchDownloadingSongIds();
  Stream<Set<String>> watchDownloadedAlbumIds();
  Stream<Set<String>> watchDownloadedArtistIds();
  Stream<List<Song>> watchDownloadedSongs();
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query});
  Stream<List<Artist>> watchDownloadedArtists();
  Stream<List<Album>> watchDownloadedArtistAlbums(String artistId);
  Stream<List<Song>> watchDownloadedAlbumSongs(String albumId);
  Stream<List<Album>> watchDownloadedAlbumSearch(
    String query, {
    int limit = 20,
  });
  Stream<List<Artist>> watchDownloadedArtistSearch(
    String query, {
    int limit = 20,
  });
  Stream<List<Song>> watchDownloadedSongSearch(String query, {int limit = 20});
  Future<void> updateSongDownload(
    String songId, {
    required String? localPath,
    required DownloadState state,
  });
  Future<void> clearAllSongDownloads();
  Future<List<Song>> getDownloadedSongs();
}

/// Identifies the thing an annotation applies to. Subsonic's star/unstar takes
/// a different parameter name per entity type, and getting it wrong silently
/// stars nothing.
enum EntityType { artist, album, song }

class EntityRef {
  const EntityRef(this.type, this.id);

  final EntityType type;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// A cached ordering's identity: the list type plus whatever filters
/// distinguish it from another list of the same type.
class AlbumListQuery {
  const AlbumListQuery(this.type, {this.genre, this.fromYear, this.toYear});

  final AlbumListType type;
  final String? genre;
  final int? fromYear;
  final int? toYear;

  /// `random` is generated fresh by the server every call. Persisting an
  /// ordering for it would produce a shelf that never reshuffles, so it is
  /// never cached and always goes to the network.
  bool get isCacheable => type != AlbumListType.random;

  /// Rebuild a query from a [filterKey] read back out of the ordering table.
  ///
  /// The inverse of [filterKey]. Keeping the two together is the point: the key
  /// is a `genre|fromYear|toYear` triple, and reading it back as a bare genre
  /// silently mis-scopes every year-filtered list.
  factory AlbumListQuery.fromFilterKey(AlbumListType type, String filterKey) {
    if (filterKey.isEmpty) return AlbumListQuery(type);
    final parts = filterKey.split('|');
    String? at(int i) =>
        i < parts.length && parts[i].isNotEmpty ? parts[i] : null;
    return AlbumListQuery(
      type,
      genre: at(0),
      fromYear: int.tryParse(at(1) ?? ''),
      toYear: int.tryParse(at(2) ?? ''),
    );
  }

  /// Stable key for the ordering table. Two queries that differ only by filter
  /// must not share cached positions.
  String get filterKey {
    if (genre == null && fromYear == null && toYear == null) return '';
    return [
      genre ?? '',
      fromYear?.toString() ?? '',
      toYear?.toString() ?? '',
    ].join('|');
  }

  @override
  bool operator ==(Object other) =>
      other is AlbumListQuery &&
      other.type == type &&
      other.genre == genre &&
      other.fromYear == fromYear &&
      other.toYear == toYear;

  @override
  int get hashCode => Object.hash(type, genre, fromYear, toYear);
}
