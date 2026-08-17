import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/domain/repositories/music_backend.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/library/library_repository_impl.dart';
import 'package:flax/services/library/sync_policy.dart';

/// The local metadata database and the repository over it. Issue #8.
///
/// Everything here runs against `NativeDatabase.memory()` — no server, no mpv,
/// no router.
class _FakeBackend implements MusicBackend {
  _FakeBackend();

  List<Artist> artists = const [];
  List<Album> albums = const [];
  List<Song> songs = const [];
  Album? album;

  Map<String, dynamic>? scanStatus;
  bool scanStatusThrows = false;

  int getArtistsCalls = 0;
  int getAlbumListCalls = 0;
  int getAlbumCalls = 0;
  final starCalls = <String>[];
  final ratingCalls = <String>[];
  bool starThrows = false;
  bool ratingThrows = false;

  @override
  Future<List<Artist>> getArtists() async {
    getArtistsCalls++;
    return artists;
  }

  @override
  Future<List<Album>> getAlbumList(
    AlbumListType type, {
    int offset = 0,
    int count = 20,
    int? fromYear,
    int? toYear,
    String? genre,
  }) async {
    getAlbumListCalls++;
    return albums;
  }

  @override
  Future<Album> getAlbum(String id) async {
    getAlbumCalls++;
    return album!;
  }

  @override
  Future<List<Song>> getAlbumSongs(String albumId) async => songs;

  SearchResult starred = const SearchResult();
  int getStarredCalls = 0;
  Artist? artist;
  List<Album> artistAlbums = const [];
  int getArtistCalls = 0;

  @override
  Future<Artist> getArtist(String id) async {
    getArtistCalls++;
    return artist!;
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async => artistAlbums;

  @override
  Future<SearchResult> getStarred() async {
    getStarredCalls++;
    return starred;
  }

  @override
  Future<Map<String, dynamic>?> getScanStatus() async {
    if (scanStatusThrows) throw Exception('no such endpoint');
    return scanStatus;
  }

  @override
  Future<void> star({String? id, String? albumId, String? artistId}) async {
    if (starThrows) throw Exception('offline');
    starCalls.add('star:${id ?? albumId ?? artistId}');
  }

  @override
  Future<void> unstar({String? id, String? albumId, String? artistId}) async {
    if (starThrows) throw Exception('offline');
    starCalls.add('unstar:${id ?? albumId ?? artistId}');
  }

  @override
  Future<void> setRating(String id, int rating) async {
    if (ratingThrows) throw Exception('offline');
    ratingCalls.add('$id=$rating');
  }

  /// Everything else in `MusicBackend` is not reached by these tests. Declaring
  /// `noSuchMethod` lets the analyzer synthesise the rest rather than needing
  /// thirty stubs, and any accidental use fails loudly.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  const sid = 'server-1';
  late FlaxDatabase db;
  late LibraryDao dao;
  late _FakeBackend backend;
  late DateTime now;

  LibraryRepositoryImpl repo() =>
      LibraryRepositoryImpl(dao, backend, sid, clock: () => now);

  Artist artist(
    String id, {
    String? name,
    int albumCount = 0,
    bool starred = false,
  }) => Artist(
    id: id,
    serverId: sid,
    name: name ?? 'Artist $id',
    albumCount: albumCount,
    starred: starred,
  );

  Album album(String id, {String? name, String? artistId, int? year}) => Album(
    id: id,
    serverId: sid,
    name: name ?? 'Album $id',
    artistId: artistId,
    year: year,
  );

  Song song(
    String id, {
    String albumId = 'al1',
    int? track,
    int? disc,
    int? bitDepth,
    String? title,
  }) => Song(
    id: id,
    serverId: sid,
    albumId: albumId,
    title: title ?? 'Song $id',
    track: track,
    discNumber: disc,
    bitDepth: bitDepth,
  );

  setUp(() {
    now = DateTime.utc(2026, 8, 16, 12);
    db = FlaxDatabase.memory();
    dao = LibraryDao(db);
    backend = _FakeBackend();
  });

  tearDown(() => db.close());

  group('upsert merges rather than replaces', () {
    test('is idempotent', () async {
      await dao.upsertArtists([artist('a1')], now);
      await dao.upsertArtists([artist('a1')], now);
      expect(await dao.watchArtists(sid).first, hasLength(1));
    });

    test('a thin record does not erase fields a fuller one populated', () async {
      // getAlbum gives full detail...
      await dao.upsertSongs([song('s1', track: 4, bitDepth: 24)], now);
      // ...then the same song turns up in a search result, which carries no
      // track number and no bit depth. Writing nulls here is the bug this
      // guards: which version you saw would depend on whether you had searched.
      await dao.upsertSongs([song('s1')], now);

      final stored = (await dao.watchAlbumSongs(sid, 'al1').first).single;
      expect(stored.track, 4);
      expect(stored.bitDepth, 24);
    });

    test('a zero count does not wipe a known one', () async {
      await dao.upsertArtists([artist('a1', albumCount: 12)], now);
      await dao.upsertArtists([artist('a1', albumCount: 0)], now);
      expect((await dao.watchArtists(sid).first).single.albumCount, 12);
    });

    test('a real change does land', () async {
      await dao.upsertArtists([artist('a1', name: 'Old')], now);
      await dao.upsertArtists([artist('a1', name: 'New')], now);
      expect((await dao.watchArtists(sid).first).single.name, 'New');
    });
  });

  group('stars and hearts stay independent', () {
    for (final entity in [
      (EntityType.artist, 'artist'),
      (EntityType.album, 'album'),
      (EntityType.song, 'song'),
    ]) {
      test('a rating write never touches ${entity.$2} favorite', () async {
        await dao.upsertArtists([artist('x')], now);
        await dao.upsertAlbums([album('x')], now);
        await dao.upsertSongs([song('x')], now);
        final ref = EntityRef(entity.$1, 'x');

        await dao.setFavorite(sid, ref, favorite: true, now: now);
        await dao.setRating(sid, ref, rating: 4);

        final (favorite, rating) = await _read(dao, sid, ref);
        expect(favorite, isTrue, reason: 'rating write cleared the favorite');
        expect(rating, 4);
      });

      test('a favorite write never touches ${entity.$2} rating', () async {
        await dao.upsertArtists([artist('x')], now);
        await dao.upsertAlbums([album('x')], now);
        await dao.upsertSongs([song('x')], now);
        final ref = EntityRef(entity.$1, 'x');

        await dao.setRating(sid, ref, rating: 5);
        await dao.setFavorite(sid, ref, favorite: false, now: now);

        final (favorite, rating) = await _read(dao, sid, ref);
        expect(rating, 5, reason: 'favorite write cleared the rating');
        expect(favorite, isFalse);
      });
    }

    test('a zero rating clears rather than storing zero', () async {
      await dao.upsertAlbums([album('x')], now);
      final ref = const EntityRef(EntityType.album, 'x');
      await dao.setRating(sid, ref, rating: 3);
      await dao.setRating(sid, ref, rating: 0);
      final (_, rating) = await _read(dao, sid, ref);
      // Stored zero would render as zero stars *filled* rather than unrated.
      expect(rating, isNull);
    });
  });

  group('multi-server isolation', () {
    test('colliding ids do not bleed between servers', () async {
      await dao.upsertArtists([artist('same')], now);
      await dao.upsertArtists([
        const Artist(id: 'same', serverId: 'server-2', name: 'Other server'),
      ], now);

      expect((await dao.watchArtists(sid).first).single.name, 'Artist same');
      expect(
        (await dao.watchArtists('server-2').first).single.name,
        'Other server',
      );
    });

    test('deleting a server takes only its rows', () async {
      await dao.upsertArtists([artist('a1')], now);
      await dao.upsertArtists([
        const Artist(id: 'a1', serverId: 'server-2', name: 'Keep me'),
      ], now);

      await dao.deleteServer(sid);

      expect(await dao.watchArtists(sid).first, isEmpty);
      expect(await dao.watchArtists('server-2').first, hasLength(1));
    });
  });

  group('orderings', () {
    test(
      'are stored separately from entities and joined back in order',
      () async {
        await dao.upsertAlbums([album('a'), album('b'), album('c')], now);
        const query = AlbumListQuery(AlbumListType.newest);
        await dao.replaceAlbumList(sid, query, ['c', 'a', 'b'], now);

        final list = await dao.watchAlbumList(sid, query).first;
        expect(list.map((a) => a.id), ['c', 'a', 'b']);
      },
    );

    test('replacing a shorter list drops the old tail', () async {
      await dao.upsertAlbums([album('a'), album('b'), album('c')], now);
      const query = AlbumListQuery(AlbumListType.newest);
      await dao.replaceAlbumList(sid, query, ['a', 'b', 'c'], now);
      await dao.replaceAlbumList(sid, query, ['a'], now);

      expect((await dao.watchAlbumList(sid, query).first).map((a) => a.id), [
        'a',
      ]);
    });

    test('two filters of the same type do not share positions', () async {
      await dao.upsertAlbums([album('a'), album('b')], now);
      const rock = AlbumListQuery(AlbumListType.byGenre, genre: 'rock');
      const jazz = AlbumListQuery(AlbumListType.byGenre, genre: 'jazz');
      await dao.replaceAlbumList(sid, rock, ['a'], now);
      await dao.replaceAlbumList(sid, jazz, ['b'], now);

      expect((await dao.watchAlbumList(sid, rock).first).single.id, 'a');
      expect((await dao.watchAlbumList(sid, jazz).first).single.id, 'b');
    });

    test('a filter key round-trips', () {
      // The key is a genre|fromYear|toYear triple. Reading it back as a bare
      // genre would silently mis-scope every year-filtered list.
      const q = AlbumListQuery(
        AlbumListType.byYear,
        genre: 'doom',
        fromYear: 1985,
        toYear: 1994,
      );
      expect(
        AlbumListQuery.fromFilterKey(AlbumListType.byYear, q.filterKey),
        q,
      );
      expect(
        AlbumListQuery.fromFilterKey(AlbumListType.newest, ''),
        const AlbumListQuery(AlbumListType.newest),
      );
    });

    test('random is never cacheable', () {
      expect(const AlbumListQuery(AlbumListType.random).isCacheable, isFalse);
      expect(const AlbumListQuery(AlbumListType.newest).isCacheable, isTrue);
    });
  });

  group('the scan beacon', () {
    Map<String, dynamic> status({
      String lastScan = '2026-08-07T23:55:56Z',
      int count = 48605,
      bool scanning = false,
    }) => {'lastScan': lastScan, 'count': count, 'scanning': scanning};

    test('an unchanged beacon suppresses the refresh entirely', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      final r = repo();

      await r.refreshArtists();
      expect(backend.getArtistsCalls, 1);

      // However old fetchedAt gets, nothing changed upstream, so nothing is
      // fetched. This is the whole point of the beacon.
      now = now.add(const Duration(days: 30));
      await r.refreshArtists();
      expect(backend.getArtistsCalls, 1);
    });

    test('a moved lastScan does trigger a refresh', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      final r = repo();
      await r.refreshArtists();

      backend.scanStatus = status(lastScan: '2026-08-16T09:00:00Z');
      await r.refreshArtists();
      expect(backend.getArtistsCalls, 2);
    });

    test('a moved song count alone is enough', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      final r = repo();
      await r.refreshArtists();

      backend.scanStatus = status(count: 48606);
      await r.refreshArtists();
      expect(backend.getArtistsCalls, 2);
    });

    test(
      'a scan in progress defers rather than caching half a library',
      () async {
        backend.scanStatus = status(scanning: true);
        backend.artists = [artist('a1')];
        final r = repo();

        await r.refreshArtists();
        expect(backend.getArtistsCalls, 0);
        expect(await r.syncIfChanged(), isFalse);
      },
    );

    test('a server with no usable beacon still refreshes', () async {
      // Falling through to the TTL path. Treating a missing beacon as "nothing
      // changed" would be a cache that never updates again.
      backend.scanStatusThrows = true;
      backend.artists = [artist('a1')];
      final r = repo();

      await r.refreshArtists();
      expect(backend.getArtistsCalls, 1);

      // No beacon means the TTL arbitrates, so an immediate second call is
      // still skipped. Time has to move for the fallback to fire.
      await r.refreshArtists();
      expect(backend.getArtistsCalls, 1);

      now = now.add(SyncPolicy.stableList + const Duration(minutes: 1));
      await r.refreshArtists();
      expect(backend.getArtistsCalls, 2);
    });

    test(
      'an empty cache is filled even when the beacon has not moved',
      () async {
        backend.scanStatus = status();
        backend.artists = [artist('a1')];
        final r = repo();
        await r.refreshArtists();
        expect(backend.getArtistsCalls, 1);

        // The beacon token outlives the rows recorded alongside it. Garbage
        // collection or a migration can empty a table while the token still says
        // "unchanged"; suppressing the fetch here would leave the screen blank
        // forever.
        await dao.deleteServer(sid);
        await dao.putSyncValue(
          sid,
          SyncKeys.lastScan,
          status()['lastScan'] as String,
          now,
        );
        await dao.putSyncValue(sid, SyncKeys.songCount, '48605', now);

        await repo().refreshArtists();
        expect(backend.getArtistsCalls, 2);
        expect(await dao.watchArtists(sid).first, hasLength(1));
      },
    );

    test('syncIfChanged re-crawls the orderings that exist', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      backend.albums = [album('al1')];
      final r = repo();

      // Two tabs get browsed, so two orderings are cached.
      await r.refreshAlbumList(const AlbumListQuery(AlbumListType.newest));
      await r.refreshAlbumList(const AlbumListQuery(AlbumListType.starred));
      final before = backend.getAlbumListCalls;

      backend.scanStatus = status(lastScan: '2026-08-17T09:00:00Z');
      expect(await r.syncIfChanged(), isTrue);

      // Both are re-fetched. Without forcing, recording the new beacon inside
      // syncIfChanged would convince every tab it had nothing to do.
      expect(backend.getAlbumListCalls, before + 2);
    });

    test('syncIfChanged does not re-crawl orderings nobody cached', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      final r = repo();
      await r.refreshArtists();

      backend.scanStatus = status(lastScan: '2026-08-17T09:00:00Z');
      await r.syncIfChanged();

      expect(backend.getAlbumListCalls, 0);
    });

    test('syncIfChanged reports whether anything moved', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      final r = repo();

      expect(await r.syncIfChanged(), isTrue);
      expect(await r.syncIfChanged(), isFalse);
    });

    test('the beacon is remembered across repository instances', () async {
      backend.scanStatus = status();
      backend.artists = [artist('a1')];
      await repo().refreshArtists();

      // A new instance reads the stored token from sync_state, so switching
      // screens does not re-crawl.
      await repo().refreshArtists();
      expect(backend.getArtistsCalls, 1);
      expect(await dao.syncValue(sid, SyncKeys.lastScan), isNotNull);
    });
  });

  group('refresh coalescing and TTLs', () {
    test('concurrent refreshes cause one fetch', () async {
      backend.scanStatusThrows = true;
      backend.artists = [artist('a1')];
      final r = repo();

      await Future.wait([
        r.refreshArtists(),
        r.refreshArtists(),
        r.refreshArtists(),
      ]);
      expect(backend.getArtistsCalls, 1);
    });

    test('a fresh album list is not refetched', () async {
      backend.scanStatusThrows = true;
      backend.albums = [album('al1')];
      final r = repo();
      const query = AlbumListQuery(AlbumListType.newest);

      await r.refreshAlbumList(query);
      expect(backend.getAlbumListCalls, 1);
      await r.refreshAlbumList(query);
      expect(backend.getAlbumListCalls, 1);

      now = now.add(SyncPolicy.volatileList + const Duration(minutes: 1));
      await r.refreshAlbumList(query);
      expect(backend.getAlbumListCalls, 2);
    });

    test('random always goes to the network and stores no ordering', () async {
      backend.albums = [album('al1')];
      final r = repo();
      const query = AlbumListQuery(AlbumListType.random);

      await r.refreshAlbumList(query);
      await r.refreshAlbumList(query);
      expect(backend.getAlbumListCalls, 2);
      // Entities kept, ordering not.
      expect(await dao.watchAlbumList(sid, query).first, isEmpty);
      expect(await dao.watchAlbum(sid, 'al1').first, isNotNull);
    });

    test('album detail respects its own TTL', () async {
      backend.scanStatusThrows = true;
      backend.album = album('al1');
      backend.songs = [song('s1')];
      final r = repo();

      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1);
      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 1);

      now = now.add(SyncPolicy.albumDetail + const Duration(days: 1));
      await r.refreshAlbum('al1');
      expect(backend.getAlbumCalls, 2);
    });
  });

  group('optimistic writes', () {
    test('a favorite is visible before the server confirms', () async {
      await dao.upsertAlbums([album('al1')], now);
      final r = repo();
      const ref = EntityRef(EntityType.album, 'al1');

      await r.setFavorite(ref, favorite: true);

      expect((await dao.watchAlbum(sid, 'al1').first)!.starred, isTrue);
      expect(backend.starCalls, ['star:al1']);
    });

    test('a failed push keeps the intent and stays dirty', () async {
      await dao.upsertAlbums([album('al1')], now);
      backend.starThrows = true;
      final r = repo();

      await r.setFavorite(
        const EntityRef(EntityType.album, 'al1'),
        favorite: true,
      );

      // Reverting under the user would be worse than being briefly out of step.
      expect((await dao.watchAlbum(sid, 'al1').first)!.starred, isTrue);
      expect(await _dirty(db, sid, 'al1'), isTrue);
    });

    test('a successful push clears dirty', () async {
      await dao.upsertAlbums([album('al1')], now);
      final r = repo();
      await r.setFavorite(
        const EntityRef(EntityType.album, 'al1'),
        favorite: true,
      );
      expect(await _dirty(db, sid, 'al1'), isFalse);
    });

    test('a rating survives a failed push too', () async {
      await dao.upsertAlbums([album('al1')], now);
      backend.ratingThrows = true;
      final r = repo();

      await r.setRating(const EntityRef(EntityType.album, 'al1'), rating: 5);

      final (_, rating) = await _read(
        dao,
        sid,
        const EntityRef(EntityType.album, 'al1'),
      );
      expect(rating, 5);
      expect(await _dirty(db, sid, 'al1'), isTrue);
    });
  });

  group('artist albums', () {
    test(
      'an incomplete list is refetched even when the beacon is unchanged',
      () async {
        backend.scanStatus = {
          'lastScan': '2026-08-07T23:55:56Z',
          'count': 48605,
          'scanning': false,
        };
        // The artist says five albums; an album list has cached two of them, with
        // a fresh timestamp. A timestamp check would call that done forever.
        await dao.upsertArtists([artist('ar1', albumCount: 5)], now);
        await dao.upsertAlbums([
          album('a', artistId: 'ar1'),
          album('b', artistId: 'ar1'),
        ], now);

        backend.artistAlbums = [
          album('a', artistId: 'ar1'),
          album('b', artistId: 'ar1'),
          album('c', artistId: 'ar1'),
          album('d', artistId: 'ar1'),
          album('e', artistId: 'ar1'),
        ];
        backend.artist = artist('ar1', albumCount: 5);

        await repo().refreshArtist('ar1');

        expect(await dao.watchArtistAlbums(sid, 'ar1').first, hasLength(5));
      },
    );

    test('a complete list is left alone', () async {
      backend.scanStatus = {
        'lastScan': '2026-08-07T23:55:56Z',
        'count': 48605,
        'scanning': false,
      };
      await dao.upsertArtists([artist('ar1', albumCount: 2)], now);
      await dao.upsertAlbums([
        album('a', artistId: 'ar1'),
        album('b', artistId: 'ar1'),
      ], now);
      backend.artist = artist('ar1', albumCount: 2);
      backend.artistAlbums = const [];

      final r = repo();
      await r.refreshArtist('ar1');
      final first = backend.getArtistCalls;
      await r.refreshArtist('ar1');
      expect(backend.getArtistCalls, first);
    });
  });

  group('annotation reconciliation', () {
    test('a favorite added elsewhere arrives', () async {
      await dao.upsertAlbums([album('al1')], now);
      backend.starred = SearchResult(albums: [album('al1')]);

      await repo().syncAnnotations();

      expect((await dao.watchAlbum(sid, 'al1').first)!.starred, isTrue);
    });

    test('a favorite removed elsewhere is cleared', () async {
      await dao.upsertAlbums([album('al1')], now);
      await dao.setFavorite(
        sid,
        const EntityRef(EntityType.album, 'al1'),
        favorite: true,
        now: now,
      );
      // Server no longer lists it.
      backend.starred = const SearchResult();

      await repo().syncAnnotations();

      expect((await dao.watchAlbum(sid, 'al1').first)!.starred, isFalse);
    });

    test(
      'a pending local favorite is not clobbered by an older server answer',
      () async {
        await dao.upsertAlbums([album('al1')], now);
        // The user hearts it while offline, so the push fails and it stays dirty.
        backend.starThrows = true;
        await repo().setFavorite(
          const EntityRef(EntityType.album, 'al1'),
          favorite: true,
        );
        expect(await _dirty(db, sid, 'al1'), isTrue);

        // The server has not heard about it yet and does not list it.
        backend.starred = const SearchResult();
        await repo().syncAnnotations();

        // Reconciling must skip dirty rows in both directions, or it silently
        // discards the thing the user just did.
        expect((await dao.watchAlbum(sid, 'al1').first)!.starred, isTrue);
      },
    );

    test('a pending write is retried and clears once accepted', () async {
      await dao.upsertAlbums([album('al1')], now);
      backend.starThrows = true;
      await repo().setFavorite(
        const EntityRef(EntityType.album, 'al1'),
        favorite: true,
      );
      expect(await _dirty(db, sid, 'al1'), isTrue);

      backend.starThrows = false;
      backend.starred = SearchResult(albums: [album('al1')]);
      await repo().syncAnnotations();

      expect(await _dirty(db, sid, 'al1'), isFalse);
      expect(backend.starCalls, contains('star:al1'));
    });

    test('getStarred is rate limited', () async {
      final r = repo();
      await r.syncAnnotations();
      expect(backend.getStarredCalls, 1);

      await r.syncAnnotations();
      expect(backend.getStarredCalls, 1);

      now = now.add(SyncPolicy.starred + const Duration(minutes: 1));
      await r.syncAnnotations();
      expect(backend.getStarredCalls, 2);
    });

    test('a favorite on an entity never seen before still lands', () async {
      // Nothing cached at all; the upsert has to happen before the reconcile or
      // there is no row for the flag to sit on.
      backend.starred = SearchResult(albums: [album('brand-new')]);
      await repo().syncAnnotations();
      expect((await dao.watchAlbum(sid, 'brand-new').first)?.starred, isTrue);
    });
  });

  group('garbage collection', () {
    test('drops an unreferenced stale album', () async {
      await dao.upsertAlbums([album('gone')], now);
      final removed = await dao.collectGarbage(
        sid,
        now.add(const Duration(days: 1)),
      );
      expect(removed, 1);
      expect(await dao.watchAlbum(sid, 'gone').first, isNull);
    });

    test('keeps a favorited album however stale', () async {
      await dao.upsertAlbums([album('loved')], now);
      await dao.setFavorite(
        sid,
        const EntityRef(EntityType.album, 'loved'),
        favorite: true,
        now: now,
      );

      await dao.collectGarbage(sid, now.add(const Duration(days: 365)));

      // A favorite is the user's data, not the server's. Dropping it because a
      // scan missed one pass would be unforgivable.
      expect(await dao.watchAlbum(sid, 'loved').first, isNotNull);
    });

    test('keeps a rated album', () async {
      await dao.upsertAlbums([album('rated')], now);
      await dao.setRating(
        sid,
        const EntityRef(EntityType.album, 'rated'),
        rating: 4,
      );
      await dao.collectGarbage(sid, now.add(const Duration(days: 365)));
      expect(await dao.watchAlbum(sid, 'rated').first, isNotNull);
    });

    test('keeps an album still referenced by a cached ordering', () async {
      await dao.upsertAlbums([album('listed')], now);
      await dao.replaceAlbumList(
        sid,
        const AlbumListQuery(AlbumListType.newest),
        ['listed'],
        now,
      );
      await dao.collectGarbage(sid, now.add(const Duration(days: 365)));
      expect(await dao.watchAlbum(sid, 'listed').first, isNotNull);
    });
  });

  group('local search', () {
    test('matches on substring and is scoped to the server', () async {
      await dao.upsertAlbums([
        album('a', name: 'Kind of Blue'),
        album('b', name: 'Blue Train'),
        album('c', name: 'Giant Steps'),
      ], now);

      final hits = await dao.searchAlbums(sid, 'Blue', 20).first;
      expect(hits.map((a) => a.name), ['Blue Train', 'Kind of Blue']);
      expect(await dao.searchAlbums('other', 'Blue', 20).first, isEmpty);
    });

    test('an empty query matches nothing rather than everything', () async {
      await dao.upsertAlbums([album('a')], now);
      expect(await dao.searchAlbums(sid, '', 20).first, isEmpty);
    });
  });

  group('ordering of results', () {
    test('artists sort on sortName where present', () async {
      await dao.upsertArtists([
        const Artist(
          id: '1',
          serverId: sid,
          name: 'The Beatles',
          sortName: 'Beatles, The',
        ),
        const Artist(id: '2', serverId: sid, name: 'Aphex Twin'),
      ], now);
      expect((await dao.watchArtists(sid).first).map((a) => a.id), ['2', '1']);
    });

    test('album songs sort by disc then track', () async {
      await dao.upsertSongs([
        song('c', disc: 2, track: 1),
        song('a', disc: 1, track: 2),
        song('b', disc: 1, track: 1),
      ], now);
      final ordered = await dao.watchAlbumSongs(sid, 'al1').first;
      expect(ordered.map((s) => s.id), ['b', 'a', 'c']);
    });

    test('artist albums put undated releases last, not first', () async {
      await dao.upsertAlbums([
        album('undated', artistId: 'ar1'),
        album('early', artistId: 'ar1', year: 1971),
        album('late', artistId: 'ar1', year: 1994),
      ], now);

      // A null year sorts before everything in SQL; unknowns on top would be
      // wrong.
      expect((await dao.watchArtistAlbums(sid, 'ar1').first).map((a) => a.id), [
        'early',
        'late',
        'undated',
      ]);
    });
  });

  group('streams update on write', () {
    test('a favorite written anywhere reaches an existing subscriber', () async {
      await dao.upsertAlbums([album('al1')], now);
      final seen = <bool>[];
      final sub = dao.watchAlbum(sid, 'al1').listen((a) {
        if (a != null) seen.add(a.starred);
      });
      await Future<void>.delayed(Duration.zero);

      await dao.setFavorite(
        sid,
        const EntityRef(EntityType.album, 'al1'),
        favorite: true,
        now: now,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      // This is what removes the need for manual invalidation: one write, every
      // watcher updates.
      expect(seen, containsAllInOrder([false, true]));
    });
  });
}

/// Reads back the favorite flag and the rating for whichever entity [ref] names.
Future<(bool, int?)> _read(LibraryDao dao, String sid, EntityRef ref) async {
  switch (ref.type) {
    case EntityType.artist:
      final a = await dao.watchArtist(sid, ref.id).first;
      return (a!.starred, a.userRating);
    case EntityType.album:
      final a = await dao.watchAlbum(sid, ref.id).first;
      return (a!.starred, a.userRating);
    case EntityType.song:
      final s = (await dao.watchAlbumSongs(sid, 'al1').first).firstWhere(
        (s) => s.id == ref.id,
      );
      return (s.starred, s.userRating);
  }
}

/// Reads the `dirty` flag without drift's expression builders. Importing
/// `drift.dart` here to get the `&` operator would also pull in its `isNull` and
/// `isNotNull`, which collide with matcher's.
Future<bool> _dirty(FlaxDatabase db, String sid, String albumId) async {
  final rows = await db.select(db.albums).get();
  return rows.firstWhere((r) => r.serverId == sid && r.id == albumId).dirty;
}
