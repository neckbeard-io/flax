import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
import 'package:flax/services/transcoding/transcoding_service.dart';

void main() {
  group('TranscodeParameters', () {
    test('original parameters are not marked as transcoded', () {
      const params = TranscodeParameters.original();
      expect(params.isTranscoded, isFalse);
      expect(params.format, isNull);
      expect(params.maxBitRate, isNull);
      expect(params.quality, StreamQuality.original);
      expect(params.displayLabel, 'Original');
      expect(params.shortLabel, 'Original');
    });

    test('transcoded parameters format labels correctly', () {
      const params = TranscodeParameters(
        format: 'opus',
        maxBitRate: 256,
        quality: StreamQuality.kbps256,
        isTranscoded: true,
      );
      expect(params.isTranscoded, isTrue);
      expect(params.displayLabel, 'OPUS 256kbps');
      expect(params.shortLabel, 'OPUS 256k');
    });

    test('FLAC transcode format labels correctly', () {
      const params = TranscodeParameters(
        format: 'flac',
        maxBitRate: null,
        quality: StreamQuality.flac,
        isTranscoded: true,
      );
      expect(params.displayLabel, 'FLAC');
      expect(params.shortLabel, 'FLAC');
    });

    test('equality and hashCode', () {
      const a = TranscodeParameters(
        format: 'opus',
        maxBitRate: 256,
        quality: StreamQuality.kbps256,
        isTranscoded: true,
      );
      const b = TranscodeParameters(
        format: 'opus',
        maxBitRate: 256,
        quality: StreamQuality.kbps256,
        isTranscoded: true,
      );
      const c = TranscodeParameters(
        format: 'aac',
        maxBitRate: 256,
        quality: StreamQuality.kbps256,
        isTranscoded: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('TranscodingConfig Serialization', () {
    test('defaults are populated properly', () {
      const config = TranscodingConfig();
      expect(config.wifiQuality, StreamQuality.original);
      expect(config.cellularQuality, StreamQuality.kbps256);
      expect(config.transcodeFormat, TranscodeFormat.opus);
      expect(config.offlineQuality, StreamQuality.original);
      expect(config.offlineConcurrency, 2);
    });

    test('round trip to JSON and back', () {
      const config = TranscodingConfig(
        wifiQuality: StreamQuality.kbps320,
        cellularQuality: StreamQuality.kbps128,
        transcodeFormat: TranscodeFormat.aac,
        offlineQuality: StreamQuality.flac,
        offlineConcurrency: 4,
      );
      final json = config.toJson();
      final restored = TranscodingConfig.fromJson(json);

      expect(restored.wifiQuality, StreamQuality.kbps320);
      expect(restored.cellularQuality, StreamQuality.kbps128);
      expect(restored.transcodeFormat, TranscodeFormat.aac);
      expect(restored.offlineQuality, StreamQuality.flac);
      expect(restored.offlineConcurrency, 4);
    });

    test('fromJson handles missing fields with defaults', () {
      final restored = TranscodingConfig.fromJson(const {});
      expect(restored.wifiQuality, StreamQuality.original);
      expect(restored.cellularQuality, StreamQuality.kbps256);
      expect(restored.transcodeFormat, TranscodeFormat.opus);
      expect(restored.offlineQuality, StreamQuality.original);
      expect(restored.offlineConcurrency, 2);
    });
  });

  group('TranscodingService resolution', () {
    const server = Server(
      id: 'srv-1',
      name: 'Home Navidrome',
      url: 'https://music.example.com',
      username: 'tester',
      tokenHash: 'secret',
      salt: 'salt123',
      transcodingConfig: TranscodingConfig(
        wifiQuality: StreamQuality.original,
        cellularQuality: StreamQuality.kbps192,
        transcodeFormat: TranscodeFormat.opus,
        offlineQuality: StreamQuality.kbps320,
        offlineConcurrency: 3,
      ),
    );

    test('resolves Wi-Fi streaming to original quality', () {
      final params = TranscodingService.resolveStreamParameters(
        server: server,
        connectivity: [ConnectivityResult.wifi],
      );
      expect(params.isTranscoded, isFalse);
      expect(params.quality, StreamQuality.original);
      expect(params.format, isNull);
      expect(params.maxBitRate, isNull);
    });

    test('resolves Cellular streaming to configured cellular quality', () {
      final params = TranscodingService.resolveStreamParameters(
        server: server,
        connectivity: [ConnectivityResult.mobile],
      );
      expect(params.isTranscoded, isTrue);
      expect(params.quality, StreamQuality.kbps192);
      expect(params.format, 'opus');
      expect(params.maxBitRate, 192);
    });

    test('throws StreamingDisabledException when quality is disabled', () {
      final disabledServer = server.copyWith(
        transcodingConfig: server.transcodingConfig.copyWith(
          cellularQuality: StreamQuality.disabled,
        ),
      );

      expect(
        () => TranscodingService.resolveStreamParameters(
          server: disabledServer,
          connectivity: [ConnectivityResult.mobile],
        ),
        throwsA(isA<StreamingDisabledException>()),
      );
    });

    test('resolves offline download parameters', () {
      final params = TranscodingService.resolveDownloadParameters(
        server: server,
      );
      expect(params.isTranscoded, isTrue);
      expect(params.quality, StreamQuality.kbps320);
      expect(params.format, 'opus');
      expect(params.maxBitRate, 320);
    });

    test('resolves offline concurrency and clamps properly', () {
      expect(
        TranscodingService.getOfflineConcurrency(server: server),
        equals(3),
      );

      final clamped = server.copyWith(
        transcodingConfig: server.transcodingConfig.copyWith(
          offlineConcurrency: 10,
        ),
      );
      expect(
        TranscodingService.getOfflineConcurrency(server: clamped),
        equals(6),
      );
    });
  });

  group('SubsonicClient stream URL generation', () {
    const server = Server(
      id: 'srv-1',
      name: 'Home',
      url: 'https://music.example.com',
      username: 'tester',
      tokenHash: 'secret',
      salt: 'salt123',
    );
    final client = SubsonicClient(server: server);

    test('original stream URL omits maxBitRate and format', () {
      final uri = client.getStreamUri('song-100');
      expect(uri.path, '/rest/stream');
      expect(uri.queryParameters['id'], 'song-100');
      expect(uri.queryParameters['maxBitRate'], isNull);
      expect(uri.queryParameters['format'], isNull);
    });

    test('download URL uses rest/download endpoint without transcoding', () {
      final uri = client.getDownloadUri('song-100');
      expect(uri.path, '/rest/download');
      expect(uri.queryParameters['id'], 'song-100');
      expect(uri.queryParameters['maxBitRate'], isNull);
      expect(uri.queryParameters['format'], isNull);
    });

    test('transcoded stream URL appends maxBitRate and format', () {
      final uri = client.getStreamUri(
        'song-100',
        maxBitRate: 256,
        format: 'opus',
      );
      expect(uri.path, '/rest/stream');
      expect(uri.queryParameters['id'], 'song-100');
      expect(uri.queryParameters['maxBitRate'], '256');
      expect(uri.queryParameters['format'], 'opus');
    });
  });
}
