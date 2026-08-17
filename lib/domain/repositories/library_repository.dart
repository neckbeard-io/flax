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

  /// Local substring search over cached entities. Instant, and works offline.
  /// The server is still asked separately to widen the result set.
  Stream<List<Album>> watchAlbumSearch(String query, {int limit = 20});
  Stream<List<Artist>> watchArtistSearch(String query, {int limit = 20});

  /// Bring the artist list up to date if it is stale. Cheap when it is not —
  /// see [syncIfChanged].
  Future<void> refreshArtists({bool force = false});
  Future<void> refreshAlbumList(AlbumListQuery query, {bool force = false});
  Future<void> refreshAlbum(String albumId, {bool force = false});

  /// Ask the server whether anything changed, and refresh only if so.
  ///
  /// Returns true when the beacon moved. This is one 285-byte call against
  /// Navidrome, so it is cheap enough to run on app focus.
  Future<bool> syncIfChanged();

  /// Stars are ratings, hearts are favorites — two independent fields. These
  /// two methods must never write each other's column.
  Future<void> setFavorite(EntityRef ref, {required bool favorite});
  Future<void> setRating(EntityRef ref, {required int rating});
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
