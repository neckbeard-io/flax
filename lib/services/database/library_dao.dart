import 'package:drift/drift.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/mappers.dart';

/// An annotation written locally that the server has not accepted yet.
class PendingWrite {
  const PendingWrite(this.ref, {required this.favorite, this.rating});

  final EntityRef ref;
  final bool favorite;
  final int? rating;
}

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

  Future<List<Artist>> getAllArtists(String serverId) async {
    final q = _db.select(_db.artists)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([
        (t) => OrderingTerm(expression: coalesce([t.sortName, t.name])),
      ]);
    final rows = await q.get();
    return rows.map(artistFromRow).toList();
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

  /// All cached albums for a server.
  Stream<List<Album>> watchAllAlbums(String serverId) {
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  Future<List<Album>> getAllAlbums(String serverId) async {
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    final rows = await q.get();
    return rows.map(albumFromRow).toList();
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

  Stream<Song?> watchSong(String serverId, String songId) {
    final q = _db.select(_db.songs)
      ..where((t) => t.serverId.equals(serverId) & t.id.equals(songId));
    return q.watchSingleOrNull().map((r) => r == null ? null : songFromRow(r));
  }

  /// Watch a specific set of songs, in the order given. The counterpart of
  /// [watchAlbumsByIds], for lists whose order must not be persisted.
  Stream<List<Song>> watchSongsByIds(String serverId, List<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    final q = _db.select(_db.songs)
      ..where((t) => t.serverId.equals(serverId) & t.id.isIn(ids));
    return q.watch().map((rows) {
      final byId = {for (final r in rows) r.id: songFromRow(r)};
      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    });
  }

  Stream<List<Song>> searchSongs(String serverId, String term, int limit) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final q = _db.select(_db.songs)
      ..where((t) => t.serverId.equals(serverId) & t.title.like('%$term%'))
      ..orderBy([(t) => OrderingTerm(expression: t.title)])
      ..limit(limit);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Future<DateTime?> artistAlbumsFetchedAt(
    String serverId,
    String artistId,
  ) async {
    final q = _db.select(_db.albums)
      ..where((t) => t.serverId.equals(serverId) & t.artistId.equals(artistId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.fetchedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.fetchedAt;
  }

  /// How many of an artist's albums are cached.
  ///
  /// Compared against the artist's own `albumCount` to tell a complete list from
  /// a partial one. Album *lists* populate rows for arbitrary artists, so the
  /// presence of some albums says nothing about whether the artist's own list was
  /// ever fetched — which is how an artist page showed two of five albums and
  /// never corrected itself.
  Future<int> cachedArtistAlbumCount(String serverId, String artistId) async {
    final count = _db.albums.id.count();
    final q = _db.selectOnly(_db.albums)
      ..addColumns([count])
      ..where(
        _db.albums.serverId.equals(serverId) &
            _db.albums.artistId.equals(artistId),
      );
    final row = await q.getSingle();
    return row.read(count) ?? 0;
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

  /// How many of an album's songs are cached.
  ///
  /// Compared against the album's own `songCount` to tell a complete track list
  /// from a partial one. Individual song plays, search results, or queues cache
  /// song rows with an `albumId`, so the presence of some songs does not mean the
  /// album's full track listing was ever fetched.
  Future<int> cachedAlbumSongCount(String serverId, String albumId) async {
    final count = _db.songs.id.count();
    final q = _db.selectOnly(_db.songs)
      ..addColumns([count])
      ..where(
        _db.songs.serverId.equals(serverId) & _db.songs.albumId.equals(albumId),
      );
    final row = await q.getSingle();
    return row.read(count) ?? 0;
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

  /// Bring the local favorite flags in line with the server's starred set.
  ///
  /// Two-way: ids present are starred, and anything locally starred that the
  /// server no longer lists is un-starred — that is how a heart removed in the
  /// web UI arrives.
  ///
  /// **Dirty rows are skipped in both directions.** A favorite written here and
  /// not yet accepted is the user's pending intent; letting the server's older
  /// answer overwrite it would silently discard the thing they just did.
  Future<void> reconcileFavorites(
    String serverId, {
    required Set<String> artistIds,
    required Set<String> albumIds,
    required Set<String> songIds,
    required DateTime now,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.artists)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.id.isIn(artistIds),
          ))
          .write(ArtistsCompanion(starred: const Value(true)));
      await (_db.update(_db.artists)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.starred.equals(true) &
                t.id.isNotIn(artistIds),
          ))
          .write(
            const ArtistsCompanion(
              starred: Value(false),
              starredAt: Value(null),
            ),
          );

      await (_db.update(_db.albums)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.id.isIn(albumIds),
          ))
          .write(AlbumsCompanion(starred: const Value(true)));
      await (_db.update(_db.albums)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.starred.equals(true) &
                t.id.isNotIn(albumIds),
          ))
          .write(
            const AlbumsCompanion(
              starred: Value(false),
              starredAt: Value(null),
            ),
          );

      await (_db.update(_db.songs)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.id.isIn(songIds),
          ))
          .write(SongsCompanion(starred: const Value(true)));
      await (_db.update(_db.songs)..where(
            (t) =>
                t.serverId.equals(serverId) &
                t.dirty.equals(false) &
                t.starred.equals(true) &
                t.id.isNotIn(songIds),
          ))
          .write(
            const SongsCompanion(starred: Value(false), starredAt: Value(null)),
          );
    });
  }

  /// Local annotation writes the server has not accepted yet.
  Future<List<PendingWrite>> pendingWrites(String serverId) async {
    final out = <PendingWrite>[];

    for (final r
        in await (_db.select(
              _db.artists,
            )..where((t) => t.serverId.equals(serverId) & t.dirty.equals(true)))
            .get()) {
      out.add(
        PendingWrite(
          EntityRef(EntityType.artist, r.id),
          favorite: r.starred,
          rating: r.userRating,
        ),
      );
    }
    for (final r
        in await (_db.select(
              _db.albums,
            )..where((t) => t.serverId.equals(serverId) & t.dirty.equals(true)))
            .get()) {
      out.add(
        PendingWrite(
          EntityRef(EntityType.album, r.id),
          favorite: r.starred,
          rating: r.userRating,
        ),
      );
    }
    for (final r
        in await (_db.select(
              _db.songs,
            )..where((t) => t.serverId.equals(serverId) & t.dirty.equals(true)))
            .get()) {
      out.add(
        PendingWrite(
          EntityRef(EntityType.song, r.id),
          favorite: r.starred,
          rating: r.userRating,
        ),
      );
    }
    return out;
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

  // ── Downloads & Offline Cache ───────────────────────────────────────────

  Future<void> updateSongDownload(
    String serverId,
    String songId, {
    required String? localPath,
    required DownloadState state,
  }) async {
    await (_db.update(
      _db.songs,
    )..where((t) => t.serverId.equals(serverId) & t.id.equals(songId))).write(
      SongsCompanion(
        localPath: Value(localPath),
        downloadState: Value(state.index),
      ),
    );
  }

  Future<void> updateSongsDownloadState(
    String serverId,
    List<String> songIds, {
    required DownloadState state,
  }) async {
    if (songIds.isEmpty) return;
    await (_db.update(_db.songs)
          ..where((t) => t.serverId.equals(serverId) & t.id.isIn(songIds)))
        .write(SongsCompanion(downloadState: Value(state.index)));
  }

  Future<void> clearAllSongDownloads(String serverId) async {
    await (_db.update(
      _db.songs,
    )..where((t) => t.serverId.equals(serverId))).write(
      const SongsCompanion(localPath: Value(null), downloadState: Value(0)),
    );
  }

  /// Migrates all recorded local song paths when the base cache directory changes.
  Future<void> migrateLocalPaths(String oldBasePath, String newBasePath) async {
    await _db.customStatement(
      'UPDATE songs SET local_path = REPLACE(local_path, ?, ?) WHERE local_path IS NOT NULL;',
      [oldBasePath, newBasePath],
    );
  }

  Stream<Set<String>> watchDownloadedSongIds(String serverId) {
    final q = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.id])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index),
      );
    return q.watch().map(
      (rows) => rows.map((r) => r.read(_db.songs.id)!).toSet(),
    );
  }

  Stream<List<Song>> watchActiveDownloadSongs(String serverId) {
    final q = _db.select(_db.songs)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            (t.downloadState.equals(DownloadState.downloading.index) |
                t.downloadState.equals(DownloadState.queued.index)),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.downloadState),
        (t) => OrderingTerm.asc(t.track),
      ]);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Stream<Set<String>> watchDownloadingSongIds(String serverId) {
    final q = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.id])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.downloadState.equals(DownloadState.downloading.index),
      );
    return q.watch().map(
      (rows) => rows.map((r) => r.read(_db.songs.id)!).toSet(),
    );
  }

  Stream<Set<String>> watchDownloadedAlbumIds(String serverId) {
    final query = _db.customSelect(
      'SELECT album_id FROM songs '
      'WHERE server_id = ? AND album_id IS NOT NULL '
      'GROUP BY album_id '
      'HAVING COUNT(*) > 0 AND COUNT(*) = SUM(CASE WHEN download_state = ? AND local_path IS NOT NULL THEN 1 ELSE 0 END)',
      variables: [
        Variable<String>(serverId),
        Variable<int>(DownloadState.complete.index),
      ],
      readsFrom: {_db.songs},
    );
    return query.watch().map(
      (rows) => rows.map((r) => r.read<String>('album_id')).toSet(),
    );
  }

  Stream<Set<String>> watchDownloadedArtistIds(String serverId) {
    final query = _db.customSelect(
      'SELECT artist_id FROM songs '
      'WHERE server_id = ? AND artist_id IS NOT NULL '
      'GROUP BY artist_id '
      'HAVING COUNT(*) > 0 AND COUNT(*) = SUM(CASE WHEN download_state = ? AND local_path IS NOT NULL THEN 1 ELSE 0 END)',
      variables: [
        Variable<String>(serverId),
        Variable<int>(DownloadState.complete.index),
      ],
      readsFrom: {_db.songs},
    );
    return query.watch().map(
      (rows) => rows.map((r) => r.read<String>('artist_id')).toSet(),
    );
  }

  Future<List<Song>> getDownloadedSongs(String serverId) async {
    final q = _db.select(_db.songs)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.localPath.isNotNull() &
            t.downloadState.equals(DownloadState.complete.index),
      );
    final rows = await q.get();
    return rows.map(songFromRow).toList();
  }

  Stream<List<Song>> watchDownloadedSongs(String serverId) {
    final q = _db.select(_db.songs)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.localPath.isNotNull() &
            t.downloadState.equals(DownloadState.complete.index),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.title)]);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Stream<List<Album>> watchDownloadedAlbums(
    String serverId, [
    AlbumListQuery? query,
  ]) {
    final downloadedAlbumSubquery = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.albumId])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index) &
            _db.songs.albumId.isNotNull(),
      );

    final q = _db.select(_db.albums)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.id.isInQuery(downloadedAlbumSubquery),
      );

    if (query != null) {
      switch (query.type) {
        case AlbumListType.alphabeticalByName:
          q.orderBy([(t) => OrderingTerm(expression: t.name)]);
        case AlbumListType.alphabeticalByArtist:
          q.orderBy([
            (t) => OrderingTerm(expression: t.artistName),
            (t) => OrderingTerm(expression: t.name),
          ]);
        case AlbumListType.newest:
        case AlbumListType.recent:
          q.orderBy([
            (t) =>
                OrderingTerm(expression: t.lastSeenAt, mode: OrderingMode.desc),
          ]);
        case AlbumListType.byYear:
          q.orderBy([
            (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
          ]);
        case AlbumListType.starred:
          q.where((t) => t.starred.equals(true));
        case AlbumListType.highest:
          q.orderBy([
            (t) =>
                OrderingTerm(expression: t.userRating, mode: OrderingMode.desc),
          ]);
        default:
          q.orderBy([(t) => OrderingTerm(expression: t.name)]);
      }
    } else {
      q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    }

    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  Stream<List<Artist>> watchDownloadedArtists(String serverId) {
    final downloadedArtistSubquery = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.artistId])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index) &
            _db.songs.artistId.isNotNull(),
      );

    final q = _db.select(_db.artists)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.id.isInQuery(downloadedArtistSubquery),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: coalesce([t.sortName, t.name])),
      ]);
    return q.watch().map((rows) => rows.map(artistFromRow).toList());
  }

  Stream<List<Album>> watchDownloadedArtistAlbums(
    String serverId,
    String artistId,
  ) {
    final downloadedAlbumSubquery = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.albumId])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index) &
            _db.songs.albumId.isNotNull(),
      );

    final q = _db.select(_db.albums)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.artistId.equals(artistId) &
            t.id.isInQuery(downloadedAlbumSubquery),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.year.isNull()),
        (t) => OrderingTerm(expression: t.year),
        (t) => OrderingTerm(expression: t.name),
      ]);
    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  Stream<List<Song>> watchDownloadedAlbumSongs(
    String serverId,
    String albumId,
  ) {
    final q = _db.select(_db.songs)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.albumId.equals(albumId) &
            t.localPath.isNotNull() &
            t.downloadState.equals(DownloadState.complete.index),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.discNumber),
        (t) => OrderingTerm(expression: t.track),
        (t) => OrderingTerm(expression: t.title),
      ]);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Stream<List<Song>> searchDownloadedSongs(
    String serverId,
    String term,
    int limit,
  ) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final q = _db.select(_db.songs)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.title.like('%$term%') &
            t.localPath.isNotNull() &
            t.downloadState.equals(DownloadState.complete.index),
      )
      ..limit(limit);
    return q.watch().map((rows) => rows.map(songFromRow).toList());
  }

  Stream<List<Album>> searchDownloadedAlbums(
    String serverId,
    String term,
    int limit,
  ) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final downloadedAlbumSubquery = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.albumId])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index) &
            _db.songs.albumId.isNotNull(),
      );

    final q = _db.select(_db.albums)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.name.like('%$term%') &
            t.id.isInQuery(downloadedAlbumSubquery),
      )
      ..limit(limit);
    return q.watch().map((rows) => rows.map(albumFromRow).toList());
  }

  Stream<List<Artist>> searchDownloadedArtists(
    String serverId,
    String term,
    int limit,
  ) {
    if (term.trim().isEmpty) return Stream.value(const []);
    final downloadedArtistSubquery = _db.selectOnly(_db.songs)
      ..addColumns([_db.songs.artistId])
      ..where(
        _db.songs.serverId.equals(serverId) &
            _db.songs.localPath.isNotNull() &
            _db.songs.downloadState.equals(DownloadState.complete.index) &
            _db.songs.artistId.isNotNull(),
      );

    final q = _db.select(_db.artists)
      ..where(
        (t) =>
            t.serverId.equals(serverId) &
            t.name.like('%$term%') &
            t.id.isInQuery(downloadedArtistSubquery),
      )
      ..limit(limit);
    return q.watch().map((rows) => rows.map(artistFromRow).toList());
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
