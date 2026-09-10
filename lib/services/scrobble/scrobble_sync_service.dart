import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
            drainPendingScrobbles();
          }
        }
      },
    );

    // 2. Server Reachability Transitions (isReachable flips false -> true)
    _ref.listen<ServerReachability>(serverReachabilityProvider, (prev, next) {
      if (next.isReachable && prev?.isReachable != true) {
        drainPendingScrobbles();
      }
    });

    // 3. Offline Mode Deactivation (offline -> online)
    _ref.listen<bool>(isOfflineModeProvider, (prev, next) {
      if (!next && prev == true) {
        drainPendingScrobbles();
      }
    });

    // 4. Client Startup & Authentication
    _ref.listen<SubsonicClient?>(subsonicClientProvider, (prev, next) {
      if (next != null) {
        drainPendingScrobbles();
      }
    });

    // 5. App Lifecycle Resume (foregrounding from background / lockscreen)
    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: () {
          drainPendingScrobbles();
        },
      );
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

  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }
}
