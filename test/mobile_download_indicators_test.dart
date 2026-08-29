import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/artist_context_menu.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/mobile_downloads_pill.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileActiveDownloadsPill Widget', () {
    testWidgets('renders active download progress and navigates on tap', (
      tester,
    ) async {
      debugOverrideIsDesktopPlatform = false;
      addTearDown(() => debugOverrideIsDesktopPlatform = null);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final task = Task(
        id: 'task-dl-1',
        label: 'Downloading 4 songs',
        kind: TaskKind.audioDownload,
        state: TaskState.running,
        itemsDone: 2,
        itemsTotal: 4,
        bytesDone: 10485760,
        bytesTotal: 20971520,
        ratePerSecond: 2.5,
      );

      final container = ProviderContainer(
        overrides: [
          activeTasksProvider.overrideWithValue([task]),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: MobileActiveDownloadsPill())),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2/4'), findsOneWidget);
      expect(find.byIcon(Icons.downloading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final rect = tester.getRect(find.byType(MobileActiveDownloadsPill));
      expect(rect.right, lessThanOrEqualTo(390));
    });

    testWidgets('renders nothing when no tasks are active', (tester) async {
      debugOverrideIsDesktopPlatform = false;
      addTearDown(() => debugOverrideIsDesktopPlatform = null);

      final container = ProviderContainer(
        overrides: [activeTasksProvider.overrideWithValue([])],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: MobileActiveDownloadsPill())),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.downloading), findsNothing);
    });
  });

  group('LibraryDao & downloadingSongIdsProvider', () {
    late FlaxDatabase db;
    late LibraryDao dao;
    const serverId = 'srv-test-1';
    final now = DateTime.utc(2026, 8, 28, 12);

    setUp(() {
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'watchDownloadingSongIds returns songs in downloading state',
      () async {
        const song1 = Song(
          id: 's-1',
          serverId: serverId,
          title: 'Running Free',
          duration: 200,
        );
        const song2 = Song(
          id: 's-2',
          serverId: serverId,
          title: 'Sanctuary',
          duration: 195,
        );

        await dao.upsertSongs([song1, song2], now);

        expect(await dao.watchDownloadingSongIds(serverId).first, isEmpty);

        // Transition song1 to downloading
        await dao.updateSongDownload(
          serverId,
          song1.id,
          localPath: null,
          state: DownloadState.downloading,
        );

        final downloadingIds = await dao
            .watchDownloadingSongIds(serverId)
            .first;
        expect(downloadingIds, contains('s-1'));
        expect(downloadingIds, isNot(contains('s-2')));

        // Transition song1 to complete
        await dao.updateSongDownload(
          serverId,
          song1.id,
          localPath: '/tmp/s-1.mp3',
          state: DownloadState.complete,
        );

        expect(await dao.watchDownloadingSongIds(serverId).first, isEmpty);
        expect(
          await dao.watchDownloadedSongIds(serverId).first,
          contains('s-1'),
        );
      },
    );
  });

  group('Context Menu Download Feedback Snackbars', () {
    testWidgets('AlbumContextMenu shows feedback SnackBar on cache offline', (
      tester,
    ) async {
      const album = Album(
        id: 'alb-1',
        serverId: 'srv-1',
        name: 'Killers',
        songCount: 10,
        duration: 2400,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AlbumContextMenu(
                album: album,
                child: const Text('Killers Target'),
              ),
            ),
          ),
        ),
      );

      // Long press to open context menu
      await tester.longPress(find.text('Killers Target'));
      await tester.pumpAndSettle();

      expect(find.text('Cache Offline'), findsOneWidget);
      await tester.tap(find.text('Cache Offline'));
      await tester.pump();

      expect(find.text('Caching "Killers"...'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('SongContextMenu shows feedback SnackBar on cache offline', (
      tester,
    ) async {
      const song = Song(
        id: 's-1',
        serverId: 'srv-1',
        title: 'Wrathchild',
        duration: 180,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SongContextMenu(
                song: song,
                child: const Text('Wrathchild Target'),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Wrathchild Target'));
      await tester.pumpAndSettle();

      expect(find.text('Cache Offline'), findsOneWidget);
      await tester.tap(find.text('Cache Offline'));
      await tester.pump();

      expect(find.text('Downloading "Wrathchild"...'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });

    testWidgets('ArtistContextMenu shows feedback SnackBar on cache offline', (
      tester,
    ) async {
      const artist = Artist(
        id: 'art-1',
        serverId: 'srv-1',
        name: 'Iron Maiden',
        albumCount: 15,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ArtistContextMenu(
                artist: artist,
                child: const Text('Iron Maiden Target'),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Iron Maiden Target'));
      await tester.pumpAndSettle();

      expect(find.text('Cache Offline'), findsOneWidget);
      await tester.tap(find.text('Cache Offline'));
      await tester.pump();

      expect(
        find.text('Caching all albums for "Iron Maiden"...'),
        findsOneWidget,
      );
      expect(find.text('View'), findsOneWidget);
    });
  });
}
