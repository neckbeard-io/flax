import 'dart:async';
import 'dart:io';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/database/database.dart';
import 'package:flax/services/database/library_dao.dart';
import 'package:flax/services/cache/storage_manager.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';

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

  group('StorageVolume & Safety Headroom', () {
    test('StorageVolume properties and copyWith', () {
      const vol = StorageVolume(
        id: 'external_0',
        label: 'SanDisk 512GB MicroSD',
        path: '/storage/1234-5678/Android/data/io.neckbeard.flax/files/music',
        isRemovable: true,
        totalBytes: 512000000000,
        availableBytes: 256000000000,
      );

      expect(vol.id, equals('external_0'));
      expect(vol.label, equals('SanDisk 512GB MicroSD'));
      expect(vol.isRemovable, isTrue);
      expect(vol.totalBytes, equals(512000000000));
      expect(vol.availableBytes, equals(256000000000));

      final updated = vol.copyWith(label: 'Adopted Storage');
      expect(updated.label, equals('Adopted Storage'));
      expect(updated.id, equals('external_0'));
    });

    test('StorageManager safety buffer constants', () {
      expect(StorageManager.minSafetyBufferBytes, equals(1536 * 1024 * 1024));
      expect(StorageManager.minSafetyBufferRatio, equals(0.10));
    });
  });

  group('Missing Storage Fallback Handling', () {
    test(
      'calls onMissingVolume when saved custom path does not exist',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageManager.prefStoragePathKey:
              '/storage/nonexistent-sdcard/flax_cache',
        });

        String? reportedMissing;
        final resolved = await StorageManager.resolveActiveCacheBasePath(
          onMissingVolume: (path) {
            reportedMissing = path;
          },
        );

        expect(
          reportedMissing,
          equals('/storage/nonexistent-sdcard/flax_cache'),
        );
        expect(
          resolved,
          isNot(equals('/storage/nonexistent-sdcard/flax_cache')),
        );
        expect(resolved, contains('audio_cache'));
      },
    );

    test('resolves custom path when valid and writable', () async {
      final tempDir = await Directory.systemTemp.createTemp('flax_valid_vol_');
      try {
        SharedPreferences.setMockInitialValues({
          StorageManager.prefStoragePathKey: tempDir.path,
        });

        var wasMissing = false;
        final resolved = await StorageManager.resolveActiveCacheBasePath(
          onMissingVolume: (_) {
            wasMissing = true;
          },
        );

        expect(wasMissing, isFalse);
        expect(resolved, equals(tempDir.path));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('Storage location that is slow or missing', () {
    test(
      'one that never answers is treated as missing, not waited on',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageManager.prefStoragePathKey: '/Volumes/nas/flax_cache',
        });

        String? reportedMissing;
        final resolved = await StorageManager.resolveActiveCacheBasePath(
          onMissingVolume: (path) => reportedMissing = path,
          // A dropped network share: the filesystem call never returns.
          isUsable: (_) => Completer<bool>().future,
          timeout: const Duration(milliseconds: 50),
        ).timeout(const Duration(seconds: 2));

        expect(reportedMissing, '/Volumes/nas/flax_cache');
        expect(resolved, contains('audio_cache'));
      },
    );

    group('download reconciliation', () {
      const serverId = 'srv-vol';
      const song = Song(
        id: 's-1',
        serverId: serverId,
        albumId: 'alb-1',
        artistId: 'art-1',
        title: 'Aces High',
        duration: 271,
      );
      late FlaxDatabase db;
      late LibraryDao dao;
      late ProviderContainer container;

      setUp(() async {
        db = FlaxDatabase.memory();
        dao = LibraryDao(db);
        final now = DateTime.utc(2026, 9, 30);
        await dao.upsertArtists([
          const Artist(id: 'art-1', serverId: serverId, name: 'Iron Maiden'),
        ], now);
        await dao.upsertAlbums([
          const Album(
            id: 'alb-1',
            serverId: serverId,
            name: 'Powerslave',
            artistId: 'art-1',
            artistName: 'Iron Maiden',
          ),
        ], now);
        await dao.upsertSongs([song], now);
        // Downloaded to a card that is not mounted right now.
        await dao.updateSongDownload(
          serverId,
          song.id,
          localPath: '/storage/1234-5678/flax/music/offline/srv-vol/s-1.flac',
          state: DownloadState.complete,
        );
        container = ProviderContainer(
          overrides: [
            libraryDaoProvider.overrideWithValue(dao),
            serverListProvider.overrideWith(
              (ref) => ServerListNotifier(
                initialServers: const [
                  Server(
                    id: serverId,
                    name: 'Home',
                    url: 'https://music.example.com',
                    username: 'me',
                    tokenHash: 'secret',
                    salt: '',
                    isActive: true,
                  ),
                ],
              ),
            ),
          ],
        );
      });

      tearDown(() async {
        container.dispose();
        AudioCacheService.cachedBasePath = null;
        await db.close();
      });

      Future<DownloadState?> stateAfterReconcile() async {
        await container
            .read(audioCacheServiceProvider)
            .reconcileLocalDownloads();
        return (await dao.watchSong(serverId, song.id).first)?.downloadState;
      }

      test('keeps downloads while the configured storage is missing', () async {
        SharedPreferences.setMockInitialValues({
          StorageManager.prefStoragePathKey: '/storage/1234-5678/flax',
        });
        await AudioCacheService.initialize();

        expect(AudioCacheService.canTrustMissingFiles, isFalse);
        // Resetting here emptied the offline library every time a card was
        // briefly unmounted.
        expect(await stateAfterReconcile(), DownloadState.complete);
        expect(
          container.read(missingStorageWarningProvider),
          '/storage/1234-5678/flax',
        );
      });

      test('still clears downloads that are really gone', () async {
        final tempDir = await Directory.systemTemp.createTemp('flax_vol_ok_');
        addTearDown(() => tempDir.delete(recursive: true));
        SharedPreferences.setMockInitialValues({
          StorageManager.prefStoragePathKey: tempDir.path,
        });
        await AudioCacheService.initialize();

        expect(AudioCacheService.canTrustMissingFiles, isTrue);
        expect(await stateAfterReconcile(), DownloadState.none);
      });
    });
  });

  group('AudioCacheService Multi-Directory Resolution', () {
    test(
      'finds cached tracks across offline, rolling, and cache directories',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'flax_cache_search_',
        );
        try {
          SharedPreferences.setMockInitialValues({
            StorageManager.prefStoragePathKey: tempDir.path,
          });

          await AudioCacheService.initialize();

          const serverId = 'srv-1';
          final offlineDir = Directory(
            p.join(tempDir.path, 'music', 'offline', serverId),
          );
          final rollingDir = Directory(
            p.join(tempDir.path, 'music', 'rolling', serverId),
          );
          final legacyCacheDir = Directory(
            p.join(tempDir.path, 'music', 'cache', serverId),
          );

          await offlineDir.create(recursive: true);
          await rollingDir.create(recursive: true);
          await legacyCacheDir.create(recursive: true);

          final offlineTrack = File(p.join(offlineDir.path, 'song_pinned.mp3'));
          await offlineTrack.writeAsString('audio-pinned');

          final rollingTrack = File(
            p.join(rollingDir.path, 'song_streamed.mp3'),
          );
          await rollingTrack.writeAsString('audio-streamed');

          final legacyTrack = File(
            p.join(legacyCacheDir.path, 'song_legacy.flac'),
          );
          await legacyTrack.writeAsString('audio-legacy');

          expect(
            AudioCacheService.findCachedSongPathSync(serverId, 'song_pinned'),
            equals(offlineTrack.path),
          );
          expect(
            AudioCacheService.findCachedSongPathSync(serverId, 'song_streamed'),
            equals(rollingTrack.path),
          );
          expect(
            AudioCacheService.findCachedSongPathSync(serverId, 'song_legacy'),
            equals(legacyTrack.path),
          );
          expect(
            AudioCacheService.findCachedSongPathSync(serverId, 'non_existent'),
            isNull,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );
  });

  group('MissingStorageBanner Widget', () {
    testWidgets('renders when missing storage is set and dismisses on tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          missingStorageWarningProvider.overrideWith(
            (ref) => '/storage/ejected-sd/music',
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: OfflineStatusBanner())),
        ),
      );
      await tester.pump();

      expect(find.text('Storage location unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.sd_card_alert_outlined), findsOneWidget);

      // Tap dismiss close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Storage location unavailable'), findsNothing);
      expect(container.read(missingStorageWarningProvider), isNull);
    });

    testWidgets(
      'OfflineStatusBanner renders on mobile dimensions without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            missingStorageWarningProvider.overrideWith(
              (ref) =>
                  '/storage/1234-5678/Android/data/io.neckbeard.flax/files/music',
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: OfflineStatusBanner()),
            ),
          ),
        );
        await tester.pump();

        final bannerFinder = find.byType(MissingStorageBanner);
        expect(bannerFinder, findsOneWidget);
        final rect = tester.getRect(bannerFinder);
        expect(rect.right, lessThanOrEqualTo(390));
      },
    );
  });
}
