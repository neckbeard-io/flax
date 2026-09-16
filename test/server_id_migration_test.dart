import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/settings/metadata_caching_screen.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/cache/storage_manager.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/services/scrobble/scrobble_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/shared/widgets/server_migration_banner.dart';

class _FakeSubsonicClient extends Fake implements SubsonicClient {
  @override
  final Server server;
  final Future<void> Function(String songId)? onScrobble;

  _FakeSubsonicClient({required this.server, this.onScrobble});

  @override
  Future<void> scrobble(
    String songId, {
    bool submission = true,
    DateTime? time,
  }) async {
    if (onScrobble != null) {
      await onScrobble!(songId);
    }
  }
}

class _FakeReachabilityNotifier extends ServerReachabilityNotifier {
  _FakeReachabilityNotifier(super.ref) {
    state = const ServerReachability(isReachable: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return Directory.systemTemp.path;
          },
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Navidrome 0.64.0 Version Helpers', () {
    test('isNavidrome064OrNewer identifies versions correctly', () {
      expect(isNavidrome064OrNewer('0.63.2'), isFalse);
      expect(isNavidrome064OrNewer('0.63.0-alpha'), isFalse);
      expect(isNavidrome064OrNewer('0.64.0'), isTrue);
      expect(isNavidrome064OrNewer('v0.64.0'), isTrue);
      expect(isNavidrome064OrNewer('0.64.1'), isTrue);
      expect(isNavidrome064OrNewer('0.65.0'), isTrue);
      expect(isNavidrome064OrNewer('1.0.0'), isTrue);
      expect(isNavidrome064OrNewer(''), isFalse);
    });

    test('isNavidrome064Migration detects upgrade crossing 0.64.0', () {
      expect(isNavidrome064Migration('0.63.2', '0.64.0'), isTrue);
      expect(isNavidrome064Migration('0.60.0', '0.64.1'), isTrue);
      expect(isNavidrome064Migration('0.64.0', '0.64.1'), isFalse);
      expect(isNavidrome064Migration('0.63.0', '0.63.2'), isFalse);
      expect(isNavidrome064Migration('0.65.0', '0.65.1'), isFalse);
    });
  });

  group('LibraryDao Server Resync & ID Queries', () {
    late FlaxDatabase db;
    late LibraryDao dao;
    const serverId = 'srv-test';
    final now = DateTime.utc(2026, 9, 15);

    setUp(() {
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getAllSongIds and getAllAlbumIds return exact id sets', () async {
      const album1 = Album(id: 'alb-1', serverId: serverId, name: 'Album 1');
      const album2 = Album(id: 'alb-2', serverId: serverId, name: 'Album 2');
      const song1 = Song(
        id: 'song-1',
        serverId: serverId,
        albumId: 'alb-1',
        title: 'Song 1',
      );
      const song2 = Song(
        id: 'song-2',
        serverId: serverId,
        albumId: 'alb-2',
        title: 'Song 2',
      );

      await dao.upsertAlbums([album1, album2], now);
      await dao.upsertSongs([song1, song2], now);

      final albumIds = await dao.getAllAlbumIds(serverId);
      expect(albumIds, equals({'alb-1', 'alb-2'}));

      final songIds = await dao.getAllSongIds(serverId);
      expect(songIds, equals({'song-1', 'song-2'}));

      final sampleSongIds = await dao.getSampleSongIds(serverId, limit: 1);
      expect(sampleSongIds.length, equals(1));
      expect(sampleSongIds.first, anyOf('song-1', 'song-2'));
    });

    test('clearServerLibrary and deleteSyncValue wipe server state', () async {
      const album = Album(id: 'alb-1', serverId: serverId, name: 'Album');
      const song = Song(id: 'song-1', serverId: serverId, title: 'Song');

      await dao.upsertAlbums([album], now);
      await dao.upsertSongs([song], now);
      await dao.putSyncValue(serverId, SyncKeys.migrationDetected, 'true', now);

      expect(await dao.syncValue(serverId, SyncKeys.migrationDetected), 'true');
      expect((await dao.getAllSongIds(serverId)).isNotEmpty, isTrue);

      await dao.deleteSyncValue(serverId, SyncKeys.migrationDetected);
      expect(await dao.syncValue(serverId, SyncKeys.migrationDetected), isNull);

      await dao.clearServerLibrary(serverId);
      expect(await dao.getAllSongIds(serverId), isEmpty);
      expect(await dao.getAllAlbumIds(serverId), isEmpty);
    });
  });

  group('AudioCacheService Orphaned File Cleanup & Reset', () {
    late Directory tempDir;
    late FlaxDatabase db;
    late LibraryDao dao;
    const serverId = 'srv-orphan';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flax_orphan_test_');
      AudioCacheService.cachedBasePath = tempDir.path;
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
    });

    tearDown(() async {
      AudioCacheService.cachedBasePath = null;
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('cleanupOrphanedFiles removes unindexed audio and lyrics', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageManager.prefStoragePathKey, tempDir.path);
      await prefs.setString(StorageManager.prefStorageVolumeIdKey, 'custom');

      // Create files in offline, rolling, and lyrics
      final offlineActive = File(
        p.join(tempDir.path, 'music', 'offline', serverId, 'song-active.mp3'),
      );
      final offlineOrphan = File(
        p.join(tempDir.path, 'music', 'offline', serverId, 'song-orphan.flac'),
      );
      final rollingOrphan = File(
        p.join(
          tempDir.path,
          'music',
          'rolling',
          serverId,
          'song-rolling-orphan.opus',
        ),
      );
      final lyricsActive = File(
        p.join(tempDir.path, 'lyrics', serverId, 'song-active.lrc'),
      );
      final lyricsOrphan = File(
        p.join(tempDir.path, 'lyrics', serverId, 'song-orphan.lrc'),
      );

      await offlineActive.parent.create(recursive: true);
      await rollingOrphan.parent.create(recursive: true);
      await lyricsActive.parent.create(recursive: true);

      await offlineActive.writeAsString('audio-active-data');
      await offlineOrphan.writeAsString('audio-orphan-data');
      await rollingOrphan.writeAsString('rolling-orphan-data');
      await lyricsActive.writeAsString('[00:01.00]active lyrics');
      await lyricsOrphan.writeAsString('[00:01.00]orphan lyrics');

      // Only song-active is present in the database
      const activeSong = Song(
        id: 'song-active',
        serverId: serverId,
        title: 'Active Track',
      );
      await dao.upsertSongs([activeSong], DateTime.now());

      final container = ProviderContainer(
        overrides: [libraryDaoProvider.overrideWithValue(dao)],
      );
      addTearDown(container.dispose);

      final service = container.read(audioCacheServiceProvider);
      final result = await service.cleanupOrphanedFiles(serverId);

      expect(result.filesDeleted, equals(3));
      expect(result.bytesFreed, greaterThan(0));

      // Active files survive
      expect(offlineActive.existsSync(), isTrue);
      expect(lyricsActive.existsSync(), isTrue);

      // Orphaned files were deleted
      expect(offlineOrphan.existsSync(), isFalse);
      expect(rollingOrphan.existsSync(), isFalse);
      expect(lyricsOrphan.existsSync(), isFalse);
    });

    test(
      'resetServerData removes all audio and lyrics dirs and clears db',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(StorageManager.prefStoragePathKey, tempDir.path);
        await prefs.setString(StorageManager.prefStorageVolumeIdKey, 'custom');

        final offlineFile = File(
          p.join(tempDir.path, 'music', 'offline', serverId, 'song.mp3'),
        );
        final lyricsFile = File(
          p.join(tempDir.path, 'lyrics', serverId, 'song.lrc'),
        );
        await offlineFile.parent.create(recursive: true);
        await lyricsFile.parent.create(recursive: true);
        await offlineFile.writeAsString('audio');
        await lyricsFile.writeAsString('lyrics');

        const song = Song(id: 'song', serverId: serverId, title: 'Title');
        await dao.upsertSongs([song], DateTime.now());

        final container = ProviderContainer(
          overrides: [libraryDaoProvider.overrideWithValue(dao)],
        );
        addTearDown(container.dispose);

        final service = container.read(audioCacheServiceProvider);
        await service.resetServerData(serverId);

        expect(offlineFile.existsSync(), isFalse);
        expect(lyricsFile.existsSync(), isFalse);
        expect(await dao.getAllSongIds(serverId), isEmpty);
      },
    );
  });

  group('ScrobbleSyncService Resilient Drain', () {
    late FlaxDatabase db;
    late LibraryDao dao;
    const server = Server(
      id: 'srv-scrobble',
      name: 'Test Server',
      url: 'https://music.example.com',
      username: 'user',
      tokenHash: 'hash',
      salt: 'salt',
      isActive: true,
    );

    setUp(() {
      db = FlaxDatabase.memory();
      dao = LibraryDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'prunes Subsonic error 70 missing songs immediately and continues draining',
      () async {
        final now = DateTime.now();
        await dao.insertPendingScrobble(server.id, 'song-missing', now);
        await dao.insertPendingScrobble(server.id, 'song-valid', now);

        final client = _FakeSubsonicClient(
          server: server,
          onScrobble: (songId) async {
            if (songId == 'song-missing') {
              throw const SubsonicException(
                code: 70,
                message: 'The requested data was not found',
              );
            }
          },
        );

        final container = ProviderContainer(
          overrides: [
            activeServerProvider.overrideWithValue(server),
            subsonicClientProvider.overrideWithValue(client),
            libraryDaoProvider.overrideWithValue(dao),
            isOfflineModeProvider.overrideWith((ref) => false),
            serverReachabilityProvider.overrideWith(
              (ref) => _FakeReachabilityNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(scrobbleSyncServiceProvider);
        final drained = await service.drainPendingScrobbles(
          timeout: const Duration(seconds: 2),
        );

        // song-missing was pruned (not counted as drained success), song-valid was successfully drained
        expect(drained, equals(1));
        final remaining = await dao.getPendingScrobbles(server.id);
        expect(remaining, isEmpty);
      },
    );
  });

  group('MetadataCachingScreen Migration UI', () {
    const testServer = Server(
      id: 'srv-mig-ui',
      name: 'Navidrome Server',
      url: 'https://music.example.com',
      username: 'user',
      tokenHash: 'hash',
      salt: 'salt',
    );

    testWidgets(
      'displays migration banner and maintenance buttons without overflow on mobile',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            activeServerProvider.overrideWith((ref) => testServer),
            serverMigrationAlertProvider.overrideWith(
              (ref) =>
                  ServerMigrationAlertNotifier()..setAlert('srv-mig-ui', true),
            ),
            metadataCacheSummaryProvider('srv-mig-ui').overrideWith(
              (ref) async => const MetadataCacheSummary(
                albumArtBytes: 1048576,
                albumArtCached: 5,
                albumArtTotal: 5,
              ),
            ),
            audioCacheSummaryProvider('srv-mig-ui').overrideWith(
              (ref) async => const AudioCacheSummary(
                cachedSongCount: 10,
                audioBytes: 52428800,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MetadataCachingScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Migration card is visible
        expect(
          find.text('Navidrome 0.64.0 Migration Detected'),
          findsOneWidget,
        );
        expect(find.text('Reset & Re-sync Now'), findsOneWidget);
        expect(find.text('Dismiss'), findsOneWidget);

        // Scroll to maintenance section
        await tester.scrollUntilVisible(
          find.text('Reset & Re-sync Server Library'),
          500,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clean Orphaned Files'), findsOneWidget);
        expect(find.text('Reset & Re-sync Server Library'), findsOneWidget);

        // Verify button bounds within mobile viewport width
        final resetBtnRect = tester.getRect(
          find.text('Reset & Re-sync Server Library'),
        );
        expect(resetBtnRect.right, lessThanOrEqualTo(390));
      },
    );

    testWidgets(
      'ServerMigrationBanner renders on mobile viewport without overflow and responds to dismiss',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final alertNotifier = ServerMigrationAlertNotifier()
          ..setAlert('srv-mig-ui', true);

        final container = ProviderContainer(
          overrides: [
            activeServerProvider.overrideWith((ref) => testServer),
            serverMigrationAlertProvider.overrideWith((ref) => alertNotifier),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ServerMigrationBanner(),
                    Expanded(child: Text('Main Content')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Navidrome 0.64+ ID Migration Detected'),
          findsOneWidget,
        );
        expect(find.text('Reset & Re-sync Library'), findsOneWidget);
        expect(find.text('Clean Orphaned Files'), findsOneWidget);
        expect(find.text('Storage Settings'), findsOneWidget);

        // Action buttons fit within mobile width
        final resetRect = tester.getRect(find.text('Reset & Re-sync Library'));
        expect(resetRect.right, lessThanOrEqualTo(390));

        // Dismiss the banner
        await tester.tap(find.byTooltip('Dismiss alert'));
        await tester.pumpAndSettle();

        expect(alertNotifier.state['srv-mig-ui'], isNull);
        expect(
          find.text('Navidrome 0.64+ ID Migration Detected'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ServerMigrationBanner reserves top margin on desktop to clear window controls',
      (tester) async {
        final alertNotifier = ServerMigrationAlertNotifier()
          ..setAlert('srv-mig-ui', true);

        final container = ProviderContainer(
          overrides: [
            activeServerProvider.overrideWith((ref) => testServer),
            serverMigrationAlertProvider.overrideWith((ref) => alertNotifier),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    ServerMigrationBanner(),
                    Expanded(child: Text('Main Content')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bannerFinder = find.byType(ServerMigrationBanner);
        expect(bannerFinder, findsOneWidget);
        final containerFinder = find.descendant(
          of: bannerFinder,
          matching: find.byType(Container),
        );
        final containerWidget = tester.widget<Container>(containerFinder.first);
        final margin = containerWidget.margin as EdgeInsets;
        expect(margin.top, greaterThanOrEqualTo(44.0));
      },
    );
  });
}
