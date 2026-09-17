import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/album_filter.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/library/artists_screen.dart';

class _FakeHangLibraryRepository extends Fake implements LibraryRepository {
  final List<Album> cachedAlbums;
  final List<Artist> cachedArtists;
  final List<Album> downloadedAlbums;
  final List<Artist> downloadedArtists;

  _FakeHangLibraryRepository({
    this.cachedAlbums = const [],
    this.cachedArtists = const [],
    this.downloadedAlbums = const [],
    this.downloadedArtists = const [],
  });

  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery query) =>
      Stream.value(cachedAlbums);

  @override
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query}) =>
      Stream.value(downloadedAlbums);

  @override
  Stream<List<Artist>> watchArtists() => Stream.value(cachedArtists);

  @override
  Stream<List<Artist>> watchDownloadedArtists() =>
      Stream.value(downloadedArtists);

  @override
  Stream<Set<String>> watchDownloadedAlbumIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchAnyDownloadedAlbumIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchDownloadedArtistIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchAnyDownloadedArtistIds() => Stream.value(const {});

  @override
  Future<DateTime?> artistsFetchedAt() async => null;

  @override
  Future<void> refreshAlbumList(AlbumListQuery query, {bool force = false}) {
    // Intentionally uncompleted Completer to simulate an in-flight network call
    return Completer<void>().future;
  }

  @override
  Future<void> refreshArtists({bool force = false}) {
    // Intentionally uncompleted Completer to simulate an in-flight network call
    return Completer<void>().future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testAlbum = Album(
    id: 'alb-1',
    serverId: 'srv',
    artistId: 'art-1',
    name: 'Un-gated Album',
    artistName: 'Test Artist',
  );

  final testArtist = Artist(
    id: 'art-1',
    serverId: 'srv',
    name: 'Test Artist',
    albumCount: 1,
  );

  test('albumsProvider yields immediately even when refresh hangs', () async {
    final fakeRepo = _FakeHangLibraryRepository(cachedAlbums: [testAlbum]);

    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(fakeRepo),
        isOfflineModeProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    // Read provider stream - it should emit cached item on frame 1 without waiting for refreshAlbumList
    final list = await container.read(albumsProvider(AlbumFilter.all).future);
    expect(list, isNotEmpty);
    expect(list.first.name, 'Un-gated Album');
  });

  test(
    'albumsProvider falls back to downloaded albums immediately when cache is empty',
    () async {
      final fakeRepo = _FakeHangLibraryRepository(
        cachedAlbums: const [],
        downloadedAlbums: [testAlbum],
      );

      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
          isOfflineModeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final list = await container.read(albumsProvider(AlbumFilter.all).future);
      expect(list, isNotEmpty);
      expect(list.first.name, 'Un-gated Album');
    },
  );

  test('artistsProvider yields immediately even when refresh hangs', () async {
    final fakeRepo = _FakeHangLibraryRepository(cachedArtists: [testArtist]);

    final container = ProviderContainer(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(fakeRepo),
        isOfflineModeProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final list = await container.read(artistsProvider.future);
    expect(list, isNotEmpty);
    expect(list.first.name, 'Test Artist');
  });

  test(
    'artistsProvider falls back to downloaded artists immediately when cache is empty',
    () async {
      final fakeRepo = _FakeHangLibraryRepository(
        cachedArtists: const [],
        downloadedArtists: [testArtist],
      );

      final container = ProviderContainer(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
          isOfflineModeProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final list = await container.read(artistsProvider.future);
      expect(list, isNotEmpty);
      expect(list.first.name, 'Test Artist');
    },
  );

  testWidgets(
    'AlbumsScreen and ArtistsScreen render on mobile viewport without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeRepo = _FakeHangLibraryRepository(
        cachedAlbums: [testAlbum],
        cachedArtists: [testArtist],
      );

      // Verify AlbumsScreen renders on phone dimensions
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
            isOfflineModeProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: AlbumsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Albums'), findsOneWidget);

      // Verify ArtistsScreen renders on phone dimensions
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(fakeRepo),
            isOfflineModeProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: ArtistsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Artists'), findsOneWidget);
    },
  );
}
