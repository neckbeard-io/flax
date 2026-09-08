import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/downloads_screen.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/app_chrome.dart';
import 'package:flax/shared/widgets/artist_context_menu.dart';
import 'package:flax/shared/widgets/caching_snack_bar.dart';
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
        ratePerSecond: 2500000,
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

      expect(find.text('2/4 · 2.5 MB/s'), findsOneWidget);
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

    test(
      'watchActiveDownloadSongs returns queued and downloading songs ordered by status and track number',
      () async {
        const songA = Song(
          id: 's-a',
          serverId: serverId,
          title: 'Track A',
          duration: 180,
          track: 1,
        );
        const songB = Song(
          id: 's-b',
          serverId: serverId,
          title: 'Track B',
          duration: 200,
          track: 2,
        );

        await dao.upsertSongs([songA, songB], DateTime.now());

        // Bulk queue songs
        await dao.updateSongsDownloadState(serverId, [
          's-a',
          's-b',
        ], state: DownloadState.queued);

        var active = await dao.watchActiveDownloadSongs(serverId).first;
        expect(active.length, equals(2));
        expect(
          active.every((s) => s.downloadState == DownloadState.queued),
          isTrue,
        );

        // Transition songA to downloading
        await dao.updateSongDownload(
          serverId,
          's-a',
          state: DownloadState.downloading,
        );

        active = await dao.watchActiveDownloadSongs(serverId).first;
        expect(active.length, equals(2));
        expect(active.first.id, equals('s-a'));
        expect(active.first.downloadState, equals(DownloadState.downloading));
        expect(active.last.id, equals('s-b'));
        expect(active.last.downloadState, equals(DownloadState.queued));
      },
    );

    test(
      'updateSongDownload guards completed songs from regressing to downloading',
      () async {
        const song = Song(
          id: 's-preserve',
          serverId: serverId,
          title: 'Preserve Test',
          duration: 180,
        );
        await dao.upsertSongs([song], now);
        await dao.updateSongDownload(
          serverId,
          song.id,
          localPath: '/cache/srv-test-1/s-preserve.mp3',
          state: DownloadState.complete,
        );

        // Attempt to move a completed song back to downloading — the DAO
        // guards against this so the row should remain complete.
        await dao.updateSongDownload(
          serverId,
          song.id,
          state: DownloadState.downloading,
        );

        final updatedSong = await dao.watchSong(serverId, song.id).first;
        expect(updatedSong?.downloadState, equals(DownloadState.complete));
        expect(
          updatedSong?.localPath,
          equals('/cache/srv-test-1/s-preserve.mp3'),
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

    testWidgets(
      'showCachingSnackBar auto-dismisses after duration without user interaction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showCachingSnackBar(
                    context,
                    message: 'Caching test album...',
                    duration: const Duration(seconds: 1),
                  ),
                  child: const Text('Show SnackBar'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show SnackBar'));
        // Settle entrance animation so the timer is scheduled
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Caching test album...'), findsOneWidget);
        expect(find.text('View'), findsOneWidget);

        // Advance past duration and wait for exit animation to complete
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(find.text('Caching test album...'), findsNothing);
        expect(find.text('View'), findsNothing);
      },
    );

    testWidgets(
      'AppChrome dismisses active SnackBar when active background tasks empty',
      (tester) async {
        final task = Task(
          id: 'task-test-dl',
          label: 'Caching album',
          kind: TaskKind.audioDownload,
          state: TaskState.running,
        );

        final container = ProviderContainer(
          overrides: [
            activeTasksProvider.overrideWithValue([task]),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => AppChrome(child: child!),
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showCachingSnackBar(
                      context,
                      message: 'Caching album in progress...',
                    ),
                    child: const Text('Trigger Caching'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger Caching'));
        await tester.pump();
        expect(find.text('Caching album in progress...'), findsOneWidget);

        // Now queue finishes (transitions to empty)
        container.updateOverrides([activeTasksProvider.overrideWithValue([])]);
        await tester.pump();
        await tester.pumpAndSettle();

        // Should be immediately dismissed because there is no more queue to view
        expect(find.text('Caching album in progress...'), findsNothing);
      },
    );

    group('DownloadsScreen Active Queue & Speed Metrics', () {
      testWidgets(
        'renders active task speed badge and individual song progress list on mobile viewport',
        (tester) async {
          debugOverrideIsDesktopPlatform = false;
          addTearDown(() => debugOverrideIsDesktopPlatform = null);

          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final task = Task(
            id: 'task-dl-album',
            label: 'Caching "Piece of Mind"',
            kind: TaskKind.audioDownload,
            state: TaskState.running,
            itemsDone: 2,
            itemsTotal: 5,
            bytesDone: 15728640,
            bytesTotal: 41943040,
            ratePerSecond: 2800000,
            eta: const Duration(seconds: 10),
            cancelable: true,
          );

          const activeSong1 = Song(
            id: 'song-active-1',
            serverId: 'srv-1',
            title: 'Where Eagles Dare',
            artistName: 'Iron Maiden',
            albumName: 'Piece of Mind',
            duration: 370,
            downloadState: DownloadState.downloading,
          );

          const activeSong2 = Song(
            id: 'song-active-2',
            serverId: 'srv-1',
            title: 'Revelations',
            artistName: 'Iron Maiden',
            albumName: 'Piece of Mind',
            duration: 408,
            downloadState: DownloadState.queued,
          );

          final container = ProviderContainer(
            overrides: [
              activeTasksProvider.overrideWithValue([task]),
              activeDownloadSongsProvider.overrideWith(
                (ref) => Stream.value([activeSong1, activeSong2]),
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DownloadsScreen()),
            ),
          );
          await tester.pump();

          // Header summary & speeds
          expect(find.text('Caching "Piece of Mind"'), findsOneWidget);
          expect(find.text('2 of 5 tracks'), findsOneWidget);
          expect(find.text('2.8 MB/s'), findsOneWidget);
          expect(find.text('ETA: less than a minute'), findsOneWidget);

          // Individual tracks list
          expect(find.text('Where Eagles Dare'), findsOneWidget);
          expect(find.text('Revelations'), findsOneWidget);
          expect(find.text('Queued'), findsOneWidget);

          // Mobile viewport layout sanity
          final activeBox = tester.getRect(
            find.text('Caching "Piece of Mind"'),
          );
          expect(activeBox.right, lessThanOrEqualTo(390));
        },
      );

      testWidgets(
        'aggregates multiple queued download batches into unified progress header',
        (tester) async {
          debugOverrideIsDesktopPlatform = false;
          addTearDown(() => debugOverrideIsDesktopPlatform = null);

          final task1 = Task(
            id: 'task-dl-1',
            label: 'Caching "Album One"',
            kind: TaskKind.audioDownload,
            state: TaskState.running,
            itemsDone: 3,
            itemsTotal: 5,
            ratePerSecond: 2000000,
            cancelable: true,
          );

          final task2 = Task(
            id: 'task-dl-2',
            label: 'Caching "Album Two"',
            kind: TaskKind.audioDownload,
            state: TaskState.running,
            itemsDone: 2,
            itemsTotal: 7,
            ratePerSecond: 1500000,
            cancelable: true,
          );

          final container = ProviderContainer(
            overrides: [
              activeTasksProvider.overrideWithValue([task1, task2]),
              activeDownloadSongsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DownloadsScreen()),
            ),
          );
          await tester.pump();

          expect(find.text('Downloading 2 batches'), findsOneWidget);
          expect(find.text('5 of 12 tracks'), findsOneWidget);
          expect(find.text('3.5 MB/s'), findsOneWidget);
        },
      );

      testWidgets(
        'renders distinct individual track download speed separate from aggregate batch speed',
        (tester) async {
          debugOverrideIsDesktopPlatform = false;
          addTearDown(() => debugOverrideIsDesktopPlatform = null);

          final task = Task(
            id: 'task-dl-batch',
            label: 'Downloading 2 tracks',
            kind: TaskKind.audioDownload,
            state: TaskState.running,
            itemsDone: 0,
            itemsTotal: 2,
            ratePerSecond: 10000000, // 10.0 MB/s aggregate batch rate
          );

          const activeSong1 = Song(
            id: 's-1',
            serverId: 'srv-1',
            title: 'Song One',
            downloadState: DownloadState.downloading,
          );

          const activeSong2 = Song(
            id: 's-2',
            serverId: 'srv-1',
            title: 'Song Two',
            downloadState: DownloadState.queued,
          );

          final container = ProviderContainer(
            overrides: [
              activeTasksProvider.overrideWithValue([task]),
              activeDownloadSongsProvider.overrideWith(
                (ref) => Stream.value([activeSong1, activeSong2]),
              ),
              songDownloadProgressProvider.overrideWith(
                () => _MockSongDownloadProgressNotifier({
                  's-1': const SongDownloadProgress(
                    bytesDownloaded: 2097152,
                    totalBytes: 8388608,
                    speedBytesPerSec: 2500000, // 2.5 MB/s for Song One
                  ),
                }),
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DownloadsScreen()),
            ),
          );
          await tester.pump();

          // Header summary must display the aggregate rate (10 MB/s)
          expect(find.text('10 MB/s'), findsOneWidget);

          // Active track row must display its OWN distinct rate (2.5 MB/s), NOT 10 MB/s
          expect(find.text('2.5 MB/s'), findsOneWidget);

          // Queued track row must display 'Queued' and not show speed
          expect(find.text('Queued'), findsOneWidget);
        },
      );
    });
  });
}

class _MockSongDownloadProgressNotifier extends SongDownloadProgressNotifier {
  final Map<String, SongDownloadProgress> _initial;
  _MockSongDownloadProgressNotifier(this._initial);

  @override
  Map<String, SongDownloadProgress> build() => _initial;
}
