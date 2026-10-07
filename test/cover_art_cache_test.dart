import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/widgets/cover_art_cache.dart';

import 'helpers/fake_cover_store.dart';

class FakeRepo extends Fake implements CacheInfoRepository {
  FakeRepo(this.objects);

  final List<CacheObject> objects;

  @override
  Future<bool> open() async => true;

  @override
  Future<List<CacheObject>> getAllObjects() async => objects;
}

void main() {
  late Directory dir;
  late FakeCoverStore store;

  setUp(() {
    dir = const LocalFileSystem().systemTempDirectory.createTempSync(
      'flax_covers_',
    );
    store = FakeCoverStore(dir);
    CoverArtCache.resetForTest();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('candidates: requested size, larger, original, then smaller', () {
    expect(CoverArtCache.candidateKeys('c', 512), [
      'cover-c-512',
      'cover-c-768',
      'cover-c-1024',
      'cover-c-1536',
      'cover-c-2048',
      'cover-c-orig',
      'cover-c-384',
      'cover-c-256',
      'cover-c-128',
      'cover-c-64',
    ]);
    expect(CoverArtCache.candidateKeys('c', null).first, 'cover-c-orig');
  });

  test(
    'a cover stored at one size is found by screens asking for others',
    () async {
      // What a download stores (the configured quality) versus what the mini
      // player, a grid tile and an album header actually ask for. Offline, only
      // the exact size used to be looked up, so art came and went per screen.
      final stored = store.add(coverCacheKey('alb1', 512));
      for (final asked in [256, 768, 1024, null]) {
        final found = await CoverArtCache.findCached(
          store,
          'alb1',
          preferredSize: asked,
        );
        expect(found?.path, stored.path, reason: 'asked for $asked');
      }
    },
  );

  test('nothing stored means null, and nothing is fetched', () async {
    expect(await CoverArtCache.findCached(store, 'none'), isNull);
    expect(store.downloaded, isEmpty);
  });

  test('a found cover is remembered for synchronous readers', () async {
    final stored = store.add(coverCacheKey('np', 768));
    await CoverArtCache.findCached(store, 'np', preferredSize: 768);
    expect(CoverArtCache.knownPath('np', size: 768), stored.path);
    expect(CoverArtCache.knownPath('np'), stored.path);
  });

  test('storing for offline files the cover under its stable name', () async {
    await CoverArtCache.storeForOffline(
      store,
      coverArtId: 'dl1',
      size: 512,
      url: Uri.parse('https://music.example.com/rest/getCoverArt?id=dl1&s=x'),
    );
    expect(store.downloaded, ['cover-dl1-512']);
    expect(store.files.keys, contains('cover-dl1-512'));
  });

  test('storing is skipped when a copy at least that size is there', () async {
    store.add(coverCacheKey('dl2', 1024));
    store.add(coverCacheKey('dl3', null));
    for (final id in ['dl2', 'dl3']) {
      await CoverArtCache.storeForOffline(
        store,
        coverArtId: id,
        size: 512,
        url: Uri.parse('https://music.example.com/rest/getCoverArt?id=$id'),
      );
    }
    expect(store.downloaded, isEmpty);
  });

  test('a thumbnail does not stop the cover being stored at size', () async {
    // The mini player stores a thumbnail the moment a track plays. Counting it
    // left cached tracks with nothing bigger, drawn full-screen in the car.
    store.add(coverCacheKey('thumb', 128));
    await CoverArtCache.storeForOffline(
      store,
      coverArtId: 'thumb',
      size: 512,
      url: Uri.parse('https://music.example.com/rest/getCoverArt?id=thumb'),
    );
    expect(store.downloaded, ['cover-thumb-512']);
    expect(CoverArtCache.knownPath('thumb', size: 512), isNotNull);
  });

  test('the best copy found is remembered, not the last', () async {
    final big = store.add(coverCacheKey('np2', 768));
    final thumb = store.add(coverCacheKey('np2', 128));
    await CoverArtCache.findCached(store, 'np2', preferredSize: 768);
    await CoverArtCache.findCached(store, 'np2', preferredSize: 128);
    expect(CoverArtCache.knownPath('np2', size: 768), big.path);
    expect(CoverArtCache.knownPath('np2', size: 1536), big.path);
    expect(CoverArtCache.knownPath('np2', size: 128), thumb.path);
  });

  test('covers filed under their request URL are re-filed by name', () async {
    const sized =
        'https://music.example.com/rest/getCoverArt?u=me&t=a&s=b&id=al-1&size=512';
    const original =
        'https://music.example.com/rest/getCoverArt?u=me&t=c&s=d&id=ar-2';
    store.add(sized);
    store.add(original);
    store.add('https://images.example.com/artist.jpg');
    final repo = FakeRepo([
      for (final key in [
        sized,
        original,
        'https://images.example.com/artist.jpg',
      ])
        CacheObject(
          key,
          key: key,
          relativePath: 'x.jpg',
          validTill: DateTime(2100),
        ),
    ]);

    final moved = await CoverArtCache.rekeyLegacyEntries(
      repo: repo,
      cache: store,
    );

    expect(moved, 2);
    expect(
      store.files.keys,
      containsAll(['cover-al-1-512', 'cover-ar-2-orig']),
    );
    expect(store.files.keys, isNot(contains(sized)));
    // Not a cover request; left exactly as it was.
    expect(store.files.keys, contains('https://images.example.com/artist.jpg'));
  });

  test(
    'covers the nightly sync downloaded are filed under their key',
    () async {
      final inbox = dir.childDirectory('inbox')..createSync();
      inbox.childFile('cover-al-1-512').writeAsBytesSync([1, 2]);
      inbox.childFile('cover-ar-2-orig').writeAsBytesSync([3]);
      // Still being written by the worker.
      inbox.childFile('cover-al-3-512.tmp').writeAsBytesSync([4]);

      final filed = await CoverArtCache.importNightlyCovers(
        store,
        inbox: inbox,
      );

      expect(filed, 2);
      expect(
        store.files.keys,
        unorderedEquals(['cover-al-1-512', 'cover-ar-2-orig']),
      );
      expect(inbox.childFile('cover-al-1-512').existsSync(), isFalse);
      expect(inbox.childFile('cover-al-3-512.tmp').existsSync(), isTrue);
    },
  );

  test('no nightly folder files nothing', () async {
    final filed = await CoverArtCache.importNightlyCovers(
      store,
      inbox: dir.childDirectory('missing'),
    );
    expect(filed, 0);
  });
}
