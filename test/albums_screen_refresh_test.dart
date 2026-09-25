import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/library/albums_screen.dart';

class _TestLibraryRepository extends Fake implements LibraryRepository {
  final List<Album> albums;
  final List<AlbumListQuery> refreshCalls = [];
  final List<bool> forceValues = [];

  _TestLibraryRepository({this.albums = const []});

  @override
  Stream<List<Album>> watchAlbumList(AlbumListQuery query) =>
      Stream.value(albums);

  @override
  Stream<List<Album>> watchDownloadedAlbums({AlbumListQuery? query}) =>
      Stream.value(const []);

  @override
  Stream<Set<String>> watchDownloadedAlbumIds() => Stream.value(const {});

  @override
  Stream<Set<String>> watchAnyDownloadedAlbumIds() => Stream.value(const {});

  @override
  Future<void> refreshAlbumList(
    AlbumListQuery query, {
    bool force = false,
  }) async {
    refreshCalls.add(query);
    forceValues.add(force);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlbumsScreen refresh affordances', () {
    testWidgets('renders on phone dimensions (390x844) without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _TestLibraryRepository(
        albums: [
          const Album(
            id: 'alb-1',
            serverId: 'srv',
            name: 'Test Album',
            artistName: 'Test Artist',
            songCount: 10,
            duration: 1800,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            isOfflineModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: AlbumsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Albums'), findsOneWidget);
      expect(find.byTooltip('Refresh albums'), findsOneWidget);
      expect(find.text('Test Album'), findsOneWidget);

      final rect = tester.getRect(find.byTooltip('Refresh albums'));
      expect(rect.right, lessThanOrEqualTo(390));
    });

    testWidgets('tapping refresh icon in header triggers force refresh', (
      tester,
    ) async {
      final repo = _TestLibraryRepository(
        albums: [
          const Album(
            id: 'alb-1',
            serverId: 'srv',
            name: 'Test Album',
            artistName: 'Test Artist',
            songCount: 10,
            duration: 1800,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            isOfflineModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: AlbumsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final refreshButton = find.byTooltip('Refresh albums');
      expect(refreshButton, findsOneWidget);

      repo.refreshCalls.clear();
      repo.forceValues.clear();

      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      expect(repo.refreshCalls.length, 1);
      expect(repo.forceValues.first, isTrue);
    });

    testWidgets('re-tapping active filter tab triggers force refresh', (
      tester,
    ) async {
      final repo = _TestLibraryRepository(
        albums: [
          const Album(
            id: 'alb-1',
            serverId: 'srv',
            name: 'Test Album',
            artistName: 'Test Artist',
            songCount: 10,
            duration: 1800,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(repo),
            isOfflineModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: AlbumsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // By default, 'All' is the active filter tab
      repo.refreshCalls.clear();
      repo.forceValues.clear();

      // Tap 'All' again while already selected
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(repo.refreshCalls.length, 1);
      expect(repo.forceValues.first, isTrue);
    });
  });
}
