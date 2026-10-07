import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

final scrobbleSyncServiceProvider = Provider<ScrobbleSyncService>((ref) {
  final service = ScrobbleSyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class ScrobbleSyncService {
  final Ref _ref;
  bool _isDraining = false;
  bool _drainScheduled = false;
  bool _disposed = false;
  AppLifecycleListener? _lifecycleListener;

  ScrobbleSyncService(this._ref) {
    _initListeners();
  }

  void _initListeners() {
    // 1. Connectivity Recovery (transitions from none/bluetooth to active network)
    _ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityStreamProvider,
      (prev, next) {
        final current = next.valueOrNull;
        if (current != null) {
          final hasNetwork = current.any(
            (c) =>
                c != ConnectivityResult.none &&
                c != ConnectivityResult.bluetooth,
          );
          if (hasNetwork) {
            _scheduleDrain();
          }
        }
      },
    );

    // 2. Server Reachability Transitions (isReachable flips false -> true)
    _ref.listen<ServerReachability>(serverReachabilityProvider, (prev, next) {
      if (next.isReachable && prev?.isReachable != true) {
        _scheduleDrain();
      }
    });

    // 3. Offline Mode Deactivation (offline -> online)
    _ref.listen<bool>(isOfflineModeProvider, (prev, next) {
      if (!next && prev == true) {
        _scheduleDrain();
      }
    });

    // 4. Client Startup & Authentication
    _ref.listen<SubsonicClient?>(subsonicClientProvider, (prev, next) {
      if (next != null) {
        _scheduleDrain();
      }
    });

    // 5. App Lifecycle Resume (foregrounding from background / lockscreen)
    try {
      _lifecycleListener = AppLifecycleListener(onResume: _scheduleDrain);
    } catch (_) {
      // AppLifecycleListener may not be available in headless test bindings
    }
  }

  Future<void> enqueuePendingScrobble(
    String songId,
    DateTime listenedAt,
  ) async {
    final server = _ref.read(activeServerProvider);
    if (server == null) return;
    final dao = _ref.read(libraryDaoProvider);
    await dao.insertPendingScrobble(server.id, songId, listenedAt);
    AppLogger.i(
      'ScrobbleSync',
      'Enqueued offline scrobble for song $songId (listenedAt: $listenedAt)',
    );
  }

  Future<int> drainPendingScrobbles({
    Duration rateLimit = const Duration(milliseconds: 120),
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isDraining) return 0;
    _isDraining = true;

    try {
      final server = _ref.read(activeServerProvider);
      final client = _ref.read(subsonicClientProvider);
      if (server == null || client == null) return 0;

      final isOffline = _ref.read(isOfflineModeProvider);
      final isReachable = _ref.read(serverReachabilityProvider).isReachable;
      // In offline mode or when unreachable, defer drain until reconnected
      if (isOffline || !isReachable) return 0;

      final dao = _ref.read(libraryDaoProvider);
      final pending = await dao.getPendingScrobbles(server.id, limit: 50);
      if (pending.isEmpty) return 0;

      AppLogger.i(
        'ScrobbleSync',
        'Starting scrobble drain for ${pending.length} items',
      );
      int drained = 0;

      for (final item in pending) {
        try {
          await client
              .scrobble(item.songId, submission: true, time: item.listenedAt)
              .timeout(timeout);

          await dao.deletePendingScrobble(item.id);
          drained++;

          if (rateLimit > Duration.zero) {
            await Future<void>.delayed(rateLimit);
          }
        } catch (e) {
          AppLogger.w(
            'ScrobbleSync',
            'Failed scrobble drain for item ${item.id} (song ${item.songId}): $e',
          );

          final isNotFound =
              (e is SubsonicException && e.code == 70) ||
              (e is DioException && e.response?.statusCode == 404);

          if (isNotFound) {
            // Song ID no longer exists upstream (e.g. Navidrome 0.64.0 ID migration).
            // Prune immediately and continue draining the rest of the queue.
            await dao.deletePendingScrobble(item.id);
            AppLogger.w(
              'ScrobbleSync',
              'Pruned scrobble ${item.id} for missing song ${item.songId} (not found on server)',
            );
            continue;
          }

          if (item.attempts >= 4) {
            // Poison pill protection: drop after 5 failed attempts
            await dao.deletePendingScrobble(item.id);
            AppLogger.w(
              'ScrobbleSync',
              'Pruned permanently failing scrobble ${item.id}',
            );
          } else {
            await dao.incrementPendingScrobbleAttempts(item.id);
          }
          // Break early on network/timeout error so we do not spam a struggling server
          break;
        }
      }

      if (drained > 0) {
        AppLogger.i(
          'ScrobbleSync',
          'Successfully drained $drained pending scrobbles',
        );
      }
      return drained;
    } finally {
      _isDraining = false;
    }
  }

  /// Starts a drain once the change that asked for it has settled.
  ///
  /// The listeners above run while Riverpod is still refreshing the providers
  /// they listen to, and a drain reads isOfflineModeProvider before its first
  /// await. Read there, it rebuilt that provider in the middle of the walk
  /// over its own dependencies, which threw "Concurrent modification during
  /// iteration" from whatever read offline mode next: AppChrome's library
  /// sync timer, on a phone in the background. A microtask runs after that
  /// walk, and triggers that land together start one drain.
  void _scheduleDrain() {
    if (_drainScheduled || _disposed) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      if (!_disposed) drainPendingScrobbles();
    });
  }

  void dispose() {
    _disposed = true;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}
