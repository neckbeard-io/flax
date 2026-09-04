import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/logging/app_logger.dart';

class BackgroundSyncStatus {
  final bool isScheduled;
  final DateTime? lastSyncTimestamp;

  const BackgroundSyncStatus({
    this.isScheduled = false,
    this.lastSyncTimestamp,
  });
}

class BackgroundSyncService {
  static const _channel = MethodChannel('com.flax/background_sync');

  static bool get isSupported => Platform.isAndroid;

  Future<bool> schedulePeriodicSync({
    int intervalHours = 24,
    bool requiresCharging = true,
    bool wifiOnly = true,
  }) async {
    if (!isSupported) return false;
    try {
      final success = await _channel
          .invokeMethod<bool>('schedulePeriodicSync', {
            'intervalHours': intervalHours,
            'requiresCharging': requiresCharging,
            'wifiOnly': wifiOnly,
          });
      return success ?? false;
    } catch (e) {
      AppLogger.w('BackgroundSync', 'Failed to schedule periodic sync: $e');
      return false;
    }
  }

  Future<bool> cancelPeriodicSync() async {
    if (!isSupported) return false;
    try {
      final success = await _channel.invokeMethod<bool>('cancelPeriodicSync');
      return success ?? false;
    } catch (e) {
      AppLogger.w('BackgroundSync', 'Failed to cancel periodic sync: $e');
      return false;
    }
  }

  Future<bool> triggerImmediateSync() async {
    if (!isSupported) return false;
    try {
      final success = await _channel.invokeMethod<bool>('triggerImmediateSync');
      return success ?? false;
    } catch (e) {
      AppLogger.w('BackgroundSync', 'Failed to trigger immediate sync: $e');
      return false;
    }
  }

  Future<BackgroundSyncStatus> getSyncStatus() async {
    if (!isSupported) return const BackgroundSyncStatus();
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getSyncStatus',
      );
      if (res == null) return const BackgroundSyncStatus();
      final isScheduled = res['isScheduled'] as bool? ?? false;
      final rawTimestamp = res['lastSyncTimestamp'] as num?;
      final lastSync = rawTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
          : null;
      return BackgroundSyncStatus(
        isScheduled: isScheduled,
        lastSyncTimestamp: lastSync,
      );
    } catch (e) {
      AppLogger.w('BackgroundSync', 'Failed to get sync status: $e');
      return const BackgroundSyncStatus();
    }
  }
}

final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService();
});

final backgroundSyncStatusProvider = FutureProvider<BackgroundSyncStatus>((
  ref,
) async {
  final service = ref.watch(backgroundSyncServiceProvider);
  return service.getSyncStatus();
});
