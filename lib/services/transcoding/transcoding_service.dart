import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/server.dart';

/// Exception thrown when streaming is disabled on the current network type
/// (e.g., [StreamQuality.disabled] on cellular).
class StreamingDisabledException implements Exception {
  final String message;
  const StreamingDisabledException([
    this.message = 'Streaming is disabled on cellular connections.',
  ]);

  @override
  String toString() => message;
}

/// Resolved parameters for transcoding a stream or offline download.
@immutable
class TranscodeParameters {
  final int? maxBitRate;
  final String? format;
  final StreamQuality quality;
  final bool isTranscoded;

  const TranscodeParameters({
    this.maxBitRate,
    this.format,
    required this.quality,
    required this.isTranscoded,
  });

  const TranscodeParameters.original()
    : maxBitRate = null,
      format = null,
      quality = StreamQuality.original,
      isTranscoded = false;

  /// Formatted display label, e.g. "OPUS 256kbps", "FLAC", or "Original".
  String get displayLabel {
    if (!isTranscoded) return 'Original';
    final fmt = format?.toUpperCase() ?? 'TRANSCODE';
    if (maxBitRate != null) {
      return '$fmt ${maxBitRate}kbps';
    }
    return fmt;
  }

  /// Compact label for tight areas, e.g. "OPUS 256k".
  String get shortLabel {
    if (!isTranscoded) return 'Original';
    final fmt = format?.toUpperCase() ?? '';
    if (maxBitRate != null) {
      return '$fmt ${maxBitRate}k';
    }
    return fmt;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscodeParameters &&
          runtimeType == other.runtimeType &&
          maxBitRate == other.maxBitRate &&
          format == other.format &&
          quality == other.quality &&
          isTranscoded == other.isTranscoded;

  @override
  int get hashCode => Object.hash(maxBitRate, format, quality, isTranscoded);

  @override
  String toString() =>
      'TranscodeParameters(format: $format, maxBitRate: $maxBitRate, quality: ${quality.name}, isTranscoded: $isTranscoded)';
}

/// Resolves audio transcoding parameters according to the server's
/// [TranscodingConfig] and the current network environment.
class TranscodingService {
  const TranscodingService._();

  /// Resolves the streaming quality to use based on the network connection.
  static StreamQuality resolveStreamQuality({
    required TranscodingConfig config,
    List<ConnectivityResult>? connectivity,
  }) {
    final isCellular =
        connectivity != null &&
        connectivity.contains(ConnectivityResult.mobile);
    if (isCellular) {
      return config.cellularQuality;
    }
    return config.wifiQuality;
  }

  /// Resolves transcoding parameters for live streaming.
  ///
  /// Throws [StreamingDisabledException] if streaming is disabled on the current
  /// network type.
  static TranscodeParameters resolveStreamParameters({
    required Server server,
    List<ConnectivityResult>? connectivity,
  }) {
    final quality = resolveStreamQuality(
      config: server.transcodingConfig,
      connectivity: connectivity,
    );

    if (quality == StreamQuality.disabled) {
      throw const StreamingDisabledException();
    }

    if (quality == StreamQuality.original) {
      return const TranscodeParameters.original();
    }

    if (quality == StreamQuality.flac) {
      return const TranscodeParameters(
        maxBitRate: null,
        format: 'flac',
        quality: StreamQuality.flac,
        isTranscoded: true,
      );
    }

    return TranscodeParameters(
      maxBitRate: quality.maxBitRate,
      format: server.transcodingConfig.transcodeFormat.value,
      quality: quality,
      isTranscoded: true,
    );
  }

  /// Resolves transcoding parameters for offline downloads.
  static TranscodeParameters resolveDownloadParameters({
    required Server server,
  }) {
    final quality = server.transcodingConfig.offlineQuality;

    if (quality == StreamQuality.original) {
      return const TranscodeParameters.original();
    }

    if (quality == StreamQuality.flac) {
      return const TranscodeParameters(
        maxBitRate: null,
        format: 'flac',
        quality: StreamQuality.flac,
        isTranscoded: true,
      );
    }

    return TranscodeParameters(
      maxBitRate: quality.maxBitRate,
      format: server.transcodingConfig.transcodeFormat.value,
      quality: quality,
      isTranscoded: true,
    );
  }

  /// Returns the number of concurrent tracks to transcode while caching offline.
  static int getOfflineConcurrency({required Server server}) {
    return server.transcodingConfig.offlineConcurrency.clamp(1, 6);
  }
}
