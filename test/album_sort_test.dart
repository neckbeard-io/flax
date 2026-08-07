import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_sort.dart';

Album _album(String name, {int? year, int? rating}) => Album(
      id: 'al-$name',
      serverId: 'srv',
      name: name,
      songCount: 1,
      duration: 100,
      year: year,
      userRating: rating,
    );

/// Waits for the notifier's async load to land.
Future<AlbumSortMode> _restored() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(albumSortProvider);
  await Future<void>.delayed(Duration.zero);
  return container.read(albumSortProvider);
}

void main() {
  group('persistence', () {
    test('defaults to year ascending when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await _restored(), AlbumSortMode.yearAsc);
      expect(AlbumSortMode.defaultMode, AlbumSortMode.yearAsc);
    });

    test('a chosen order survives a restart', () async {
      // The whole bug: the choice only lasted for one run of the app.
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(albumSortProvider.notifier).setMode(AlbumSortMode.title);
      expect(first.read(albumSortProvider), AlbumSortMode.title);

      // A fresh container is a fresh launch: nothing carries over in memory.
      expect(await _restored(), AlbumSortMode.title);
    });

    test('every mode round-trips', () async {
      for (final mode in AlbumSortMode.values) {
        SharedPreferences.setMockInitialValues({});
        final c = ProviderContainer();
        await c.read(albumSortProvider.notifier).setMode(mode);
        c.dispose();
        expect(await _restored(), mode, reason: '${mode.name} did not persist');
      }
    });

    test('is stored by name, not by ordinal', () async {
      // Persisting the index would silently remap every saved preference the
      // moment a value is added to the enum or the list is reordered.
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(albumSortProvider.notifier).setMode(AlbumSortMode.rating);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AlbumSortNotifier.storageKey), 'rating');
    });

    test('an unrecognized stored value falls back to the default', () async {
      // An older build's spelling, or a corrupt string, must not stop the
      // screen from opening.
      SharedPreferences.setMockInitialValues({
        'flutter.${AlbumSortNotifier.storageKey}': 'yearDescending',
      });
      // Prove the bad value is actually readable first — otherwise this test
      // would pass simply because the key was never found, and the fallback
      // path it is meant to cover would never run.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AlbumSortNotifier.storageKey), 'yearDescending');

      expect(await _restored(), AlbumSortMode.defaultMode);
      expect(decodeSortMode('nonsense'), AlbumSortMode.defaultMode);
    });
  });

  group('ordering', () {
    final albums = [
      _album('Ritual', year: 1991, rating: 3),
      _album('Aurora', year: 2004, rating: 5),
      _album('Beacon', rating: 1),
      _album('Cinder', year: 1998),
    ];

    test('leaves the caller\'s list untouched', () {
      final input = List<Album>.from(albums);
      sortAlbums(input, AlbumSortMode.title);
      expect(input.map((a) => a.name), albums.map((a) => a.name));
    });

    test('year ascending puts an unknown year last', () {
      // An album with no year must not displace one that has a real year.
      final sorted = sortAlbums(albums, AlbumSortMode.yearAsc);
      expect(sorted.map((a) => a.name),
          ['Ritual', 'Cinder', 'Aurora', 'Beacon']);
    });

    test('year descending puts an unknown year first', () {
      final sorted = sortAlbums(albums, AlbumSortMode.yearDesc);
      expect(sorted.first.name, 'Aurora');
      expect(sorted.last.name, 'Beacon');
    });

    test('title sorts alphabetically', () {
      expect(
        sortAlbums(albums, AlbumSortMode.title).map((a) => a.name),
        ['Aurora', 'Beacon', 'Cinder', 'Ritual'],
      );
    });

    test('rating sorts highest first, unrated last', () {
      final sorted = sortAlbums(albums, AlbumSortMode.rating);
      expect(sorted.first.name, 'Aurora');
      expect(sorted.last.name, 'Cinder');
    });

    test('every mode has a menu label', () {
      for (final mode in AlbumSortMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });
  });
}
