import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flax/core/logging/app_logger.dart';

class NativeDownloadTask {
  final String songId;
  final String serverId;
  final String title;
  final String? artist;
  final String downloadUrl;
  final String destinationPath;
  final int? expectedSizeBytes;

  const NativeDownloadTask({
    required this.songId,
    required this.serverId,
    required this.title,
    this.artist,
    required this.downloadUrl,
    required this.destinationPath,
    this.expectedSizeBytes,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'serverId': serverId,
    'title': title,
    'artist': artist,
    'downloadUrl': downloadUrl,
    'destinationPath': destinationPath,
    'expectedSizeBytes': expectedSizeBytes,
  };
}

sealed class NativeDownloadEvent {
  const NativeDownloadEvent();
}

class NativeTaskStartedEvent extends NativeDownloadEvent {
  final String songId;
  final String serverId;
  final String title;

  const NativeTaskStartedEvent({
    required this.songId,
    required this.serverId,
    required this.title,
  });
}

class NativeProgressEvent extends NativeDownloadEvent {
  final String songId;
  final int bytesDownloaded;
  final int totalBytes;
  final int speedBytesPerSec;
  final int completedCount;
  final int totalCount;

  const NativeProgressEvent({
    required this.songId,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.completedCount,
    required this.totalCount,
  });
}

class NativeTaskCompletedEvent extends NativeDownloadEvent {
  final String songId;
  final String serverId;
  final String localPath;
  final int completedCount;
  final int totalCount;

  const NativeTaskCompletedEvent({
    required this.songId,
    required this.serverId,
    required this.localPath,
    required this.completedCount,
    required this.totalCount,
  });
}

class NativeTaskFailedEvent extends NativeDownloadEvent {
  final String songId;
  final String serverId;
  final String error;
  final int completedCount;
  final int totalCount;

  const NativeTaskFailedEvent({
    required this.songId,
    required this.serverId,
    required this.error,
    required this.completedCount,
    required this.totalCount,
  });
}

class NativeTaskCanceledEvent extends NativeDownloadEvent {
  final String songId;

  const NativeTaskCanceledEvent({required this.songId});
}

class NativeQueueCompletedEvent extends NativeDownloadEvent {
  final int totalCompleted;
  final int totalBytes;

  const NativeQueueCompletedEvent({
    required this.totalCompleted,
    required this.totalBytes,
  });
}

class NativeCanceledEvent extends NativeDownloadEvent {
  const NativeCanceledEvent();
}

/// Platform bridge to Android's native OkHttp + Foreground Service download engine.
class NativeDownloader {
  static const _methodChannel = MethodChannel('com.flax/native_downloader');
  static const _eventChannel = EventChannel(
    'com.flax/native_downloader_events',
  );

  static bool get isSupported => Platform.isAndroid;

  static Stream<NativeDownloadEvent>? _eventStream;

  static Stream<NativeDownloadEvent> get eventStream {
    if (!isSupported) {
      return const Stream.empty();
    }
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<NativeDownloadEvent>((dynamic raw) {
          if (raw is! Map) return const NativeCanceledEvent();
          final map = raw.cast<String, dynamic>();
          final type = map['type'] as String?;

          return switch (type) {
            'task_started' => NativeTaskStartedEvent(
              songId: map['songId'] as String,
              serverId: map['serverId'] as String,
              title: map['title'] as String? ?? '',
            ),
            'progress' => NativeProgressEvent(
              songId: map['songId'] as String? ?? '',
              bytesDownloaded: (map['bytesDownloaded'] as num?)?.toInt() ?? 0,
              totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
              speedBytesPerSec: (map['speedBytesPerSec'] as num?)?.toInt() ?? 0,
              completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
              totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
            ),
            'task_completed' => NativeTaskCompletedEvent(
              songId: map['songId'] as String,
              serverId: map['serverId'] as String,
              localPath: map['localPath'] as String,
              completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
              totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
            ),
            'task_failed' => NativeTaskFailedEvent(
              songId: map['songId'] as String,
              serverId: map['serverId'] as String,
              error: map['error'] as String? ?? 'Download failed',
              completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
              totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
            ),
            'task_canceled' => NativeTaskCanceledEvent(
              songId: map['songId'] as String? ?? '',
            ),
            'queue_completed' => NativeQueueCompletedEvent(
              totalCompleted: (map['totalCompleted'] as num?)?.toInt() ?? 0,
              totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
            ),
            _ => const NativeCanceledEvent(),
          };
        });
    return _eventStream!;
  }

  /// Starts downloading a batch of tasks via the native Android foreground service.
  static Future<bool> startDownload({
    required List<NativeDownloadTask> tasks,
    int concurrency = 4,
  }) async {
    if (!isSupported || tasks.isEmpty) return false;
    try {
      final success = await _methodChannel.invokeMethod<bool>('startDownload', {
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'concurrency': concurrency,
      });
      return success ?? false;
    } catch (e) {
      AppLogger.w('NativeDownloader', 'Failed to start native download: $e');
      return false;
    }
  }

  /// Cancels specific songs from the native download queue.
  static Future<void> cancelSongs(List<String> songIds) async {
    if (!isSupported || songIds.isEmpty) return;
    try {
      await _methodChannel.invokeMethod('cancelSongs', {'songIds': songIds});
    } catch (_) {}
  }

  /// Cancels all active downloads and stops the foreground service.
  static Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _methodChannel.invokeMethod('cancelAll');
    } catch (_) {}
  }
}
