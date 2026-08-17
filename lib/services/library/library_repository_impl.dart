import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/library/sync_policy.dart';

/// Reads locally, refreshes in the background. Issue #8.
///
/// Nothing here blocks a read on the network. Callers get a stream off the
/// database immediately; whether a refresh happens is decided separately, and
/// the stream emits again if one lands.
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl(
    this._dao,
    this._backend,
    this._serverId, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryDao _dao;
  final MusicBackend _backend;
  final String _serverId;
  final DateTime Function() _clock;

  /// Refreshes in flight, so N subscribers to one stream cause one fetch rather
  /// than N. Without this, opening a screen with several widgets watching the
  /// same provider hammers the server.
  final _inFlight = <String, Future<void>>{};

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Stream<List<Artist>> watchArtists() => _dao.watchArtists(_serverId);

  @override
  Stream<Artist?> watchArtist(String artistId) =>
      _dao.watchArtist(_serverId, artistId);

  @override
  Stream<List<Album>> watchArtistAlbums(String artistId) =>
      _dao.watchArtistAlbums(_serverId, artistId);

  @override
  Stream<Album?> watchAlbum(String albumId) =>
      _dao.watchAlbum(_serverId, albumId);

  @override
  Stream<List<Song>> watchAlbumSongs(String albumId) =>
      _dao.watchAlbumSongs(_serverId, albumId);

  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery query) =>
      _dao.watchAlbumList(_serverId, query);

  @override
  Stream<List<Album>> watchAlbumSearch(String query, {int limit = 20}) =>
      _dao.searchAlbums(_serverId, query, limit);

  @override
  Stream<List<Artist>> watchArtistSearch(String query, {int limit = 20}) =>
      _dao.searchArtists(_serverId, query, limit);

  // ── Refresh ──────────────────────────────────────────────────────────────

  @override
  Future<void> refreshArtists({bool force = false}) {
    return _once('artists', () async {
      if (!force) {
        final fetchedAt = await _dao.artistsFetchedAt(_serverId);
        if (!await _shouldFetch(SyncPolicy.stableList, fetchedAt)) return;
      }
      final artists = await _backend.getArtists();
      await _dao.upsertArtists(artists, _clock());
    });
  }

  @override
  Future<void> refreshAlbumList(AlbumListQuery query, {bool force = false}) {
    return _once('list:${query.type.name}:${query.filterKey}', () async {
      if (!force && query.isCacheable) {
        final fetchedAt = await _dao.albumListFetchedAt(_serverId, query);
        if (!await _shouldFetch(SyncPolicy.forList(query.type), fetchedAt)) {
          return;
        }
      }

      final albums = await _backend.getAlbumList(
        query.type,
        count: 500,
        genre: query.genre,
        fromYear: query.fromYear,
        toYear: query.toYear,
      );

      final now = _clock();
      await _dao.upsertAlbums(albums, now);
      // Random is never persisted as an ordering — a cached "random" shelf never
      // reshuffles. Its entities are still worth keeping.
      if (query.isCacheable) {
        await _dao.replaceAlbumList(
          _serverId,
          query,
          albums.map((a) => a.id).toList(),
          now,
        );
      }
    });
  }

  @override
  Future<void> refreshAlbum(String albumId, {bool force = false}) {
    return _once('album:$albumId', () async {
      if (!force) {
        final fetchedAt = await _dao.albumDetailFetchedAt(_serverId, albumId);
        if (!await _shouldFetch(SyncPolicy.albumDetail, fetchedAt)) return;
      }
      final album = await _backend.getAlbum(albumId);
      final songs = await _backend.getAlbumSongs(albumId);
      final now = _clock();
      await _dao.upsertAlbums([album], now);
      await _dao.upsertSongs(songs, now);
    });
  }

  @override
  Future<bool> syncIfChanged() async {
    final beacon = await _readBeacon();
    // Mid-scan the server's own view is inconsistent; caching it captures a
    // half-indexed library. Waiting is the correct move, not fetching.
    if (beacon == null || beacon.scanning) return false;

    final stored = await _storedBeacon();
    if (!beacon.changedSince(stored)) return false;

    await _writeBeacon(beacon);
    await refreshArtists(force: true);
    return true;
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> setFavorite(EntityRef ref, {required bool favorite}) async {
    // Local first, so the heart fills the moment it is clicked.
    await _dao.setFavorite(
      _serverId,
      ref,
      favorite: favorite,
      now: _clock(),
      dirty: true,
    );
    try {
      final id = ref.type == EntityType.song ? ref.id : null;
      final albumId = ref.type == EntityType.album ? ref.id : null;
      final artistId = ref.type == EntityType.artist ? ref.id : null;
      if (favorite) {
        await _backend.star(id: id, albumId: albumId, artistId: artistId);
      } else {
        await _backend.unstar(id: id, albumId: albumId, artistId: artistId);
      }
      await _dao.setFavorite(
        _serverId,
        ref,
        favorite: favorite,
        now: _clock(),
        dirty: false,
      );
    } catch (_) {
      // The row keeps the user's intent and stays dirty for retry. Reverting
      // under them would be worse than being briefly out of step.
    }
  }

  @override
  Future<void> setRating(EntityRef ref, {required int rating}) async {
    await _dao.setRating(_serverId, ref, rating: rating, dirty: true);
    try {
      await _backend.setRating(ref.id, rating);
      await _dao.setRating(_serverId, ref, rating: rating, dirty: false);
    } catch (_) {
      // As above.
    }
  }

  // ── Beacon plumbing ──────────────────────────────────────────────────────

  Future<ScanBeacon?> _readBeacon() async {
    try {
      final raw = await _backend.getScanStatus();
      if (raw == null) return null;
      return ScanBeacon(
        lastScan: raw['lastScan'] as String?,
        songCount: (raw['count'] as num?)?.toInt(),
        scanning: raw['scanning'] == true,
      );
    } catch (_) {
      // A server with no usable getScanStatus falls through to the TTL path
      // rather than being treated as permanently fresh.
      return null;
    }
  }

  Future<ScanBeacon?> _storedBeacon() async {
    final lastScan = await _dao.syncValue(_serverId, SyncKeys.lastScan);
    if (lastScan == null) return null;
    final count = await _dao.syncValue(_serverId, SyncKeys.songCount);
    return ScanBeacon(lastScan: lastScan, songCount: int.tryParse(count ?? ''));
  }

  Future<void> _writeBeacon(ScanBeacon beacon) async {
    final now = _clock();
    await _dao.putSyncValue(_serverId, SyncKeys.lastScan, beacon.lastScan, now);
    await _dao.putSyncValue(
      _serverId,
      SyncKeys.songCount,
      beacon.songCount?.toString(),
      now,
    );
  }

  /// Ask the beacon what it knows.
  Future<BeaconVerdict> _beaconVerdict() async {
    final beacon = await _readBeacon();
    if (beacon == null) return BeaconVerdict.unknown;
    if (beacon.scanning) return BeaconVerdict.scanning;
    final stored = await _storedBeacon();
    if (!beacon.changedSince(stored)) return BeaconVerdict.unchanged;
    // Record it here so a caller that refreshes on the strength of this does not
    // ask again and see the same move twice.
    await _writeBeacon(beacon);
    return BeaconVerdict.changed;
  }

  /// Whether to go to the network at all.
  ///
  /// The beacon decides when it can; the TTL only arbitrates when it cannot.
  /// With a stable library that means almost every check costs 285 bytes and
  /// does nothing, which is the entire point.
  Future<bool> _shouldFetch(Duration ttl, DateTime? fetchedAt) async {
    // Always ask, even on a cold cache, because asking is what records the
    // token. Returning early without it leaves nothing for the next check to
    // compare against, and every subsequent call then reads as "changed".
    final verdict = await _beaconVerdict();

    // Mid-scan, wait. A half-indexed library cached is worse than an empty
    // screen, and this gets retried.
    if (verdict == BeaconVerdict.scanning) return false;

    // Nothing cached: fetch whatever the beacon says. An unchanged token cannot
    // fill an empty cache, and the token outlives the rows recorded alongside
    // it — so a table emptied by garbage collection or a migration would
    // otherwise never refill, leaving the screen permanently blank.
    if (fetchedAt == null) return true;

    return switch (verdict) {
      BeaconVerdict.unchanged => false,
      BeaconVerdict.changed => true,
      BeaconVerdict.scanning => false,
      BeaconVerdict.unknown => SyncPolicy.isStale(fetchedAt, ttl, _clock()),
    };
  }

  Future<void> _once(String key, Future<void> Function() work) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = work().whenComplete(() {
      // Block body, not `=> _inFlight.remove(key)`. `Map.remove` returns the
      // value it removed — which here is this very future — and `whenComplete`
      // awaits whatever its callback returns. The arrow form makes the future
      // wait for itself and hangs forever.
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }
}
