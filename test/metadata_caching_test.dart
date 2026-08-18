import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';

void main() {
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

  group('Server model includes metadataCacheConfig', () {
    test('server serialization preserves metadataCacheConfig', () {
      const server = Server(
        id: 'srv-1',
        name: 'Home',
        url: 'https://music.example.com',
        username: 'user',
        tokenHash: 'hash',
        salt: 'salt',
        metadataCacheConfig: MetadataCacheConfig(
          albumArtQuality: MetadataQuality.low,
          artistArtQuality: MetadataQuality.original,
          cacheArtistInfo: false,
          concurrency: 2,
        ),
      );

      final json = server.toJson();
      final restored = Server.fromJson(json);

      expect(restored.metadataCacheConfig.albumArtQuality, MetadataQuality.low);
      expect(
        restored.metadataCacheConfig.artistArtQuality,
        MetadataQuality.original,
      );
      expect(restored.metadataCacheConfig.cacheArtistInfo, isFalse);
      expect(restored.metadataCacheConfig.concurrency, 2);
    });
  });
}
