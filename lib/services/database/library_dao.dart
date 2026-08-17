import 'package:drift/drift.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/mappers.dart';

/// Every query and write against the local library. Issue #8.
///
/// Reads return streams so the UI updates on any write, from anywhere. Writes
/// are upserts that merge rather than replace — see `mappers.dart` for why.
class LibraryDao {
  LibraryDao(this._db);

  final FlaxDatabase _db;

  // ── Artists ──────────────────────────────────────────────────────────────

  Stream<List<Artist>> watchArtists(String serverId) {
    final q = _db.select(_db.artists)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([
        // Sort on sortName where the server gave one, name otherwise. Doing
        // this in SQL rather than in Dart keeps it inside the stream, so a
        // newly-inserted artist lands in the right place without a re-sort.
        (t) => OrderingTerm(expression: coalesce([t.sortName, t.name])),
      ]);
    return q.watch().map((rows) => rows.map(artistFromRow).toList());
  }

  Stream<Artist?> watchArtist(String serverId, String artistId) {
    final q = _db.select(_db.artists)
      ..where((t) => t.serverId.equals(serverId) & t.id.equals(artistId));
    return q.watchSingleOrNull().map(
      (r) => r == null ? null : artistFromRow(r),
    );
  }

  Stream<List<Artist>> searchArtists(String serverId, String term, int limit) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final q = _db.select(_db.artists)
      ..where((t) => t.serverId.equals(serverId) & t.name.like('%$term%'))
      ..orderBy([
        (t) => OrderingTerm(expression: coalesce([t.sortName, t.name])),
      ])
      ..limit(limit);
    return q.watch().map((rows) => rows.map(artistFromRow).toList());
  }

  Future<void> upsertArtists(List<Artist> artists, DateTime now) async {
    if (artists.isEmpty) return;
    await _db.batch((b) {
      for (final a in artists) {
        b.insert(
          _db.artists,
          artistToCompanion(a, now),
          onConflict: DoUpdate(
            (_) => artistToCompanion(a, now),
            target: [_db.artists.serverId, _db.artists.id],
          ),
        );
      }
    });
  }

  /// When the artist list was last written, or null if it never has been.
  Future<DateTime?> artistsFetchedAt(String serverId) async {
    final q = _db.select(_db.artists)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.fetchedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.fetchedAt;
  }

  // ── Albums ───────────────────────────────────────────────────────────────

  Stream<Album?> watchAlbum(String serverId, String albumId) {
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId) & t.id.equals(albumId));
    return q.watchSingleOrNull().map((r) => r == null ? null : albumFromRow(r));
  }

  Stream<List<Album>> watchArtistAlbums(String serverId, String artistId) {
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId) & t.artistId.equals(artistId))
      ..orderBy([
        // Chronological, with undated releases last rather than first — a null
        // year sorts before everything in SQL and would put unknowns on top.
        (t) => OrderingTerm(expression: t.year.isNull()),
        (t) => OrderingTerm(expression: t.year),
        (t) => OrderingTerm(expression: t.name),
      ]);
    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  Stream<List<Album>> searchAlbums(String serverId, String term, int limit) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId) & t.name.like('%$term%'))
      ..orderBy([(t) => OrderingTerm(expression: t.name)])
      ..limit(limit);
    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  /// The albums of a cached ordering, in the order the server gave them.
  ///
  /// Joins positions to entities, so an album appearing in five lists is stored
  /// once and a favorite written anywhere updates all five.
  Stream<List<Album>> watchAlbumList(String serverId, AlbumListQuery query) {
    final entries = _db.albumListEntries;
    final albums = _db.albums;

    final q = _db.select(entries).join([
      innerJoin(
        albums,
        albums.serverId.equalsExp(entries.serverId) &
            albums.id.equalsExp(entries.albumId),
      ),
    ]);
    q.where(
      entries.serverId.equals(serverId) &
          entries.listType.equals(query.type.name) &
          entries.filterKey.equals(query.filterKey),
    );
    q.orderBy([OrderingTerm(expression: entries.position)]);

    return q.watch().map(
      (rows) => rows.map((r) => albumFromRow(r.readTable(albums))).toList(),
    );
  }

  /// Watch a specific set of albums, in the order given.
  ///
  /// For lists that must not be persisted as an ordering — Random — but whose
  /// rows should still update live when a favorite is written. SQL `IN` does not
  /// preserve argument order, so the ordering is reapplied in Dart.
  Stream<List<Album>> watchAlbumsByIds(String serverId, List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId) & t.id.isIn(ids));
    return q.watch().map((rows) {
      final byId = {for (final r in rows) r.id: albumFromRow(r)};
      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    });
  }

  Future<void> upsertAlbums(List<Album> albums, DateTime now) async {
    if (albums.isEmpty) return;
    await _db.batch((b) {
      for (final a in albums) {
        b.insert(
          _db.albums,
          albumToCompanion(a, now),
          onConflict: DoUpdate(
            (_) => albumToCompanion(a, now),
            target: [_db.albums.serverId, _db.albums.id],
          ),
        );
      }
    });
  }

  /// Replace a cached ordering wholesale.
  ///
  /// Positions are rewritten, entity rows are untouched. Deleting first rather
  /// than upserting matters: a list that got shorter would otherwise keep the
  /// tail of its previous contents forever.
  Future<void> replaceAlbumList(
    String serverId,
    AlbumListQuery query,
    List<String> albumIds,
    DateTime now,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.albumListEntries)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.listType.equals(query.type.name) &
                t.filterKey.equals(query.filterKey),
          ))
          .go();
      if (albumIds.isEmpty) return;
      await _db.batch((b) {
        for (var i = 0; i < albumIds.length; i++) {
          b.insert(
            _db.albumListEntries,
            AlbumListEntriesCompanion.insert(
              serverId: serverId,
              listType: query.type.name,
              filterKey: Value(query.filterKey),
              position: i,
              albumId: albumIds[i],
              fetchedAt: now,
            ),
          );
        }
      });
    });
  }

  /// When a cached ordering was last written, or null if it has never been.
  Future<DateTime?> albumListFetchedAt(
    String serverId,
    AlbumListQuery query,
  ) async {
    final q = _db.select(_db.albumListEntries)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.listType.equals(query.type.name) &
            t.filterKey.equals(query.filterKey),
      )
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.fetchedAt;
  }

  /// The orderings currently held for a server, as (listType, filterKey) pairs.
  ///
  /// Used to re-crawl what is actually cached when the beacon moves, rather than
  /// guessing at every list type the UI might one day ask for.
  Future<List<(String, String)>> cachedAlbumLists(String serverId) async {
    final entries = _db.albumListEntries;
    final q = _db.selectOnly(entries, distinct: true)
      ..addColumns([entries.listType, entries.filterKey])
      ..where(entries.serverId.equals(serverId));
    final rows = await q.get();
    return [
      for (final r in rows)
        (r.read(entries.listType)!, r.read(entries.filterKey)!),
    ];
  }

  // ── Songs ────────────────────────────────────────────────────────────────

  Stream<List<Song>> watchAlbumSongs(String serverId, String albumId) {
    final q = _db.select(_db.songs)
      ..where((t) => t.serverId.equals(serverId) & t.albumId.equals(albumId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.discNumber),
        (t) => OrderingTerm(expression: t.track),
        (t) => OrderingTerm(expression: t.title),
      ]);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Future<void> upsertSongs(List<Song> songs, DateTime now) async {
    if (songs.isEmpty) return;
    await _db.batch((b) {
      for (final s in songs) {
        b.insert(
          _db.songs,
          songToCompanion(s, now),
          onConflict: DoUpdate(
            (_) => songToCompanion(s, now),
            target: [_db.songs.serverId, _db.songs.id],
          ),
        );
      }
    });
  }

  Future<DateTime?> albumDetailFetchedAt(
    String serverId,
    String albumId,
  ) async {
    final q = _db.select(_db.songs)
      ..where((t) => t.serverId.equals(serverId) & t.albumId.equals(albumId))
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.fetchedAt;
  }

  // ── Playlists ────────────────────────────────────────────────────────────

  Stream<List<Playlist>> watchPlaylists(String serverId) {
    final q = _db.select(_db.playlists)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch().map((rows) => rows.map(playlistFromRow).toList());
  }

  Future<void> upsertPlaylists(List<Playlist> playlists, DateTime now) async {
    if (playlists.isEmpty) return;
    await _db.batch((b) {
      for (final p in playlists) {
        b.insert(
          _db.playlists,
          playlistToCompanion(p, now),
          onConflict: DoUpdate(
            (_) => playlistToCompanion(p, now),
            target: [_db.playlists.serverId, _db.playlists.id],
          ),
        );
      }
    });
  }

  // ── Annotations ──────────────────────────────────────────────────────────
  //
  // Stars are ratings, hearts are favorites: two independent fields on the same
  // row. Each of these writes exactly one of them and never the other.

  Future<void> setFavorite(
    String serverId,
    EntityRef ref, {
    required bool favorite,
    required DateTime now,
    bool dirty = false,
  }) async {
    switch (ref.type) {
      case EntityType.artist:
        await (_db.update(_db.artists)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(
              ArtistsCompanion(
                starred: Value(favorite),
                starredAt: Value(favorite ? now : null),
                dirty: Value(dirty),
              ),
            );
      case EntityType.album:
        await (_db.update(_db.albums)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(
              AlbumsCompanion(
                starred: Value(favorite),
                starredAt: Value(favorite ? now : null),
                dirty: Value(dirty),
              ),
            );
      case EntityType.song:
        await (_db.update(_db.songs)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(
              SongsCompanion(
                starred: Value(favorite),
                starredAt: Value(favorite ? now : null),
                dirty: Value(dirty),
              ),
            );
    }
  }

  Future<void> setRating(
    String serverId,
    EntityRef ref, {
    required int rating,
    bool dirty = false,
  }) async {
    // 0 means "no rating" in Subsonic, which is a null column here rather than
    // a stored zero — otherwise a cleared rating renders as zero stars filled.
    final value = Value<int?>(rating <= 0 ? null : rating);
    switch (ref.type) {
      case EntityType.artist:
        await (_db.update(_db.artists)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(ArtistsCompanion(userRating: value, dirty: Value(dirty)));
      case EntityType.album:
        await (_db.update(_db.albums)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(AlbumsCompanion(userRating: value, dirty: Value(dirty)));
      case EntityType.song:
        await (_db.update(_db.songs)
              ..where((t) => t.serverId.equals(serverId) & t.id.equals(ref.id)))
            .write(SongsCompanion(userRating: value, dirty: Value(dirty)));
    }
  }

  // ── Sync state ───────────────────────────────────────────────────────────

  Future<String?> syncValue(String serverId, String key) async {
    final q = _db.select(_db.syncStates)
      ..where((t) => t.serverId.equals(serverId) & t.key.equals(key));
    final row = await q.getSingleOrNull();
    return row?.value;
  }

  Future<void> putSyncValue(
    String serverId,
    String key,
    String? value,
    DateTime now,
  ) async {
    await _db
        .into(_db.syncStates)
        .insertOnConflictUpdate(
          SyncStatesCompanion.insert(
            serverId: serverId,
            key: key,
            value: Value(value),
            updatedAt: now,
          ),
        );
  }

  // ── Housekeeping ─────────────────────────────────────────────────────────

  /// Everything belonging to a server. Called when a server is removed.
  Future<void> deleteServer(String serverId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.albumListEntries,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.playlistEntries,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.songs,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.albums,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.artists,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.playlists,
      )..where((t) => t.serverId.equals(serverId))).go();
      await (_db.delete(
        _db.syncStates,
      )..where((t) => t.serverId.equals(serverId))).go();
    });
  }

  /// Drop albums the server has stopped mentioning.
  ///
  /// An album deleted upstream vanishes from refreshed orderings but its entity
  /// row lingers. Anything still referenced by an ordering, favorited, or rated
  /// is kept — a favorite is the user's data, not the server's, and dropping it
  /// because a scan missed one pass would be unforgivable.
  Future<int> collectGarbage(String serverId, DateTime before) async {
    final referenced = _db.selectOnly(_db.albumListEntries)
      ..addColumns([_db.albumListEntries.albumId])
      ..where(_db.albumListEntries.serverId.equals(serverId));

    return (_db.delete(_db.albums)..where(
          (t) =>
              t.serverId.equals(serverId) &
              t.lastSeenAt.isSmallerThanValue(before) &
              t.starred.equals(false) &
              t.userRating.isNull() &
              t.id.isNotInQuery(referenced),
        ))
        .go();
  }
}
