import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/settings/metadata_caching_screen.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MetadataQuality', () {
    test('quality values provide proper labels and request sizes', () {
      expect(MetadataQuality.low.label, 'Low (256px)');
      expect(MetadataQuality.low.requestSize, 256);

      expect(MetadataQuality.medium.label, 'Medium (512px)');
      expect(MetadataQuality.medium.requestSize, 512);

      expect(MetadataQuality.original.label, 'Original (Full)');
      expect(MetadataQuality.original.requestSize, isNull);

      expect(MetadataQuality.disabled.label, 'Disabled');
      expect(MetadataQuality.disabled.requestSize, 0);
    });
  });

  group('MetadataCacheConfig', () {
    test('default configuration values', () {
      const config = MetadataCacheConfig();
      expect(config.albumArtQuality, MetadataQuality.medium);
      expect(config.artistArtQuality, MetadataQuality.medium);
      expect(config.cacheArtistInfo, isTrue);
      expect(config.concurrency, 4);
    });

    test('round trip JSON serialization', () {
      const config = MetadataCacheConfig(
        albumArtQuality: MetadataQuality.original,
        artistArtQuality: MetadataQuality.low,
        cacheArtistInfo: false,
        concurrency: 6,
      );

      final json = config.toJson();
      final restored = MetadataCacheConfig.fromJson(json);

      expect(restored.albumArtQuality, MetadataQuality.original);
      expect(restored.artistArtQuality, MetadataQuality.low);
      expect(restored.cacheArtistInfo, isFalse);
      expect(restored.concurrency, 6);
    });

    test('concurrency is clamped between 1 and 8', () {
      final low = MetadataCacheConfig.fromJson(const {'concurrency': 0});
      expect(low.concurrency, 1);

      final high = MetadataCacheConfig.fromJson(const {'concurrency': 20});
      expect(high.concurrency, 8);
    });

    test('copyWith updates properties', () {
      const config = MetadataCacheConfig();
      final updated = config.copyWith(
        albumArtQuality: MetadataQuality.low,
        cacheArtistInfo: false,
      );

      expect(updated.albumArtQuality, MetadataQuality.low);
      expect(updated.artistArtQuality, MetadataQuality.medium);
      expect(updated.cacheArtistInfo, isFalse);
      expect(updated.concurrency, 4);
    });
  });

  group('MetadataCachingScreen Widget Tests', () {
    const testServer = Server(
      id: 'srv-1',
      name: 'Test Server',
      url: 'https://music.example.com',
      username: 'user',
      tokenHash: 'hash',
      salt: 'salt',
    );

    testWidgets('Screen renders on phone dimensions without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          activeServerProvider.overrideWith((ref) => testServer),
          metadataCacheSummaryProvider('srv-1').overrideWith(
            (ref) async => const MetadataCacheSummary(
              albumArtBytes: 52428800,
              albumArtCached: 10,
              albumArtTotal: 10,
            ),
          ),
          audioCacheSummaryProvider('srv-1').overrideWith(
            (ref) async => const AudioCacheSummary(
              cachedSongCount: 25,
              audioBytes: 262144000,
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

      expect(find.text('Caching'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Audio Cache Size Limit'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audio Cache Size Limit'), findsOneWidget);
      expect(find.text('5 GB'), findsOneWidget);

      // Open cache limit dialog
      await tester.tap(find.text('Audio Cache Size Limit'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Presets:'), findsOneWidget);
      expect(find.text('10 GB'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);
      expect(find.text('Custom Limit (in GB)'), findsOneWidget);

      // Tap 10 GB preset
      await tester.tap(find.text('10 GB'));
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('10 GB'), findsOneWidget);
    });
  });
}
