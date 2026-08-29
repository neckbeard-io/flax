import 'dart:io';

import 'package:flax/services/cache/audio_cache_service.dart';
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
