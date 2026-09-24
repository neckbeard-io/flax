import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

const _kOfflineManualPrefKey = 'flax_offline_manual_override';
const _kOfflineOnCellularPrefKey = 'flax_offline_on_cellular';
const _kOfflineOnAndroidAutoPrefKey = 'flax_offline_on_android_auto';
const kLastServerReachablePrefKey = 'flax_last_server_reachable';
const kLastIsOfflinePrefKey = 'flax_last_is_offline';
const kLastIsCellularPrefKey = 'flax_last_is_cellular';

/// Persisted last known transport state for instant frame-1 mobile evaluation.
final lastKnownCellularProvider = StateProvider<bool>((ref) => false);
final lastKnownOfflineProvider = StateProvider<bool>((ref) => false);

/// Reason why the app is currently in offline mode.
enum OfflineReason {
  none,
  manual,
  cellular,
  androidAuto,
  serverUnreachable,
  noNetwork,
}

/// Manual offline mode toggle persisted across sessions.
final offlineManualOverrideProvider =
    StateNotifierProvider<OfflineManualNotifier, bool>((ref) {
      return OfflineManualNotifier();
    });

class OfflineManualNotifier extends StateNotifier<bool> {
  OfflineManualNotifier({bool? initialValue}) : super(initialValue ?? false) {
    if (initialValue == null) {
      _load();
    }
  }

  static bool loadFromPrefs(SharedPreferences prefs) {
    return prefs.getBool(_kOfflineManualPrefKey) ?? false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kOfflineManualPrefKey);
      if (saved != null && mounted) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    await set(!state);
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOfflineManualPrefKey, value);
    } catch (_) {}
  }
}

/// Setting: automatically switch to offline mode when not on Wi-Fi/Ethernet.
final offlineOnCellularSettingProvider =
    StateNotifierProvider<OfflineOnCellularNotifier, bool>((ref) {
      return OfflineOnCellularNotifier();
    });

class OfflineOnCellularNotifier extends StateNotifier<bool> {
  OfflineOnCellularNotifier({bool? initialValue})
    : super(initialValue ?? false) {
    if (initialValue == null) {
      _load();
    }
  }

  static bool loadFromPrefs(SharedPreferences prefs) {
    return prefs.getBool(_kOfflineOnCellularPrefKey) ?? false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kOfflineOnCellularPrefKey);
      if (saved != null && mounted) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    await set(!state);
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOfflineOnCellularPrefKey, value);
    } catch (_) {}
  }
}

/// Setting: automatically switch to offline mode when using Android Auto or automotive media browser.
final offlineOnAndroidAutoSettingProvider =
    StateNotifierProvider<OfflineOnAndroidAutoNotifier, bool>((ref) {
      return OfflineOnAndroidAutoNotifier();
    });

class OfflineOnAndroidAutoNotifier extends StateNotifier<bool> {
  OfflineOnAndroidAutoNotifier({bool? initialValue})
    : super(initialValue ?? false) {
    if (initialValue == null) {
      _load();
    }
  }

  static bool loadFromPrefs(SharedPreferences prefs) {
    return prefs.getBool(_kOfflineOnAndroidAutoPrefKey) ?? false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kOfflineOnAndroidAutoPrefKey);
      if (saved != null && mounted) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    await set(!state);
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOfflineOnAndroidAutoPrefKey, value);
    } catch (_) {}
  }
}

/// State of server reachability.
class ServerReachability {
  final bool isReachable;
  final bool isProbing;
  final String? lastError;
  final DateTime? lastChecked;
  final int consecutiveFailures;

  const ServerReachability({
    this.isReachable = true,
    this.isProbing = false,
    this.lastError,
    this.lastChecked,
    this.consecutiveFailures = 0,
  });

  ServerReachability copyWith({
    bool? isReachable,
    bool? isProbing,
    String? lastError,
    DateTime? lastChecked,
    int? consecutiveFailures,
  }) {
    return ServerReachability(
      isReachable: isReachable ?? this.isReachable,
      isProbing: isProbing ?? this.isProbing,
      lastError: lastError ?? this.lastError,
      lastChecked: lastChecked ?? this.lastChecked,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}

/// Probes the server and updates reachability state based on platform-specific policies.
final serverReachabilityProvider =
    StateNotifierProvider<ServerReachabilityNotifier, ServerReachability>((
      ref,
    ) {
      return ServerReachabilityNotifier(ref);
    });

class ServerReachabilityNotifier extends StateNotifier<ServerReachability> {
  final Ref _ref;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  ServerReachabilityNotifier(
    this._ref, {
    ServerReachability? initialReachability,
  }) : super(initialReachability ?? const ServerReachability()) {
    _ref.listen<SubsonicClient?>(subsonicClientProvider, (prev, next) {
      if (next != null) {
        try {
          _checkStoredMigrationAlert(next.server.id);
        } catch (_) {}
        if (prev != null && prev != next) {
          probeServer(silent: true);
        }
      } else {
        state = const ServerReachability();
      }
    });

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
          if (hasNetwork && !state.isReachable && !state.isProbing) {
            probeServer(silent: true);
          }
        }
      },
    );
  }

  Future<void> _checkStoredMigrationAlert(String serverId) async {
    try {
      final dao = _ref.read(libraryDaoProvider);
      final stored = await dao.syncValue(serverId, SyncKeys.migrationDetected);
      if (stored == 'true') {
        _ref
            .read(serverMigrationAlertProvider.notifier)
            .setAlert(serverId, true);
      }
    } catch (_) {}
  }

  Future<void> _checkServerMigration(SubsonicClient client) async {
    String serverId;
    try {
      serverId = client.server.id;
    } catch (_) {
      return;
    }
    final dao = _ref.read(libraryDaoProvider);

    try {
      AppLogger.d(
        'Reachability',
        () => 'Checking server migration for $serverId',
      );
      final stored = await dao.syncValue(serverId, SyncKeys.migrationDetected);
      if (stored == 'true') {
        AppLogger.d(
          'Reachability',
          () => 'Stored migration alert already active for $serverId',
        );
        _ref
            .read(serverMigrationAlertProvider.notifier)
            .setAlert(serverId, true);
        return;
      }

      final info = await client.getServerInfo(
        timeout: const Duration(seconds: 4),
      );
      final ver = info.serverVersion;
      if (ver == null) return;

      final prevVer = await dao.syncValue(serverId, SyncKeys.serverVersion);
      bool migrationDetected = false;
      if (prevVer != null && isNavidrome064Migration(prevVer, ver)) {
        migrationDetected = true;
      } else if (isNavidrome064OrNewer(ver)) {
        // Navidrome 0.64.0+ re-encoded all track/song IDs into canonical 128-bit Base62 format.
        // Check if locally indexed songs still exist upstream.
        final sample = await dao.getSampleSongIds(serverId, limit: 5);
        if (sample.isNotEmpty) {
          int missingCount = 0;
          for (final songId in sample) {
            try {
              await client.getSong(songId);
            } on SubsonicException catch (se) {
              if (se.code == 70) {
                missingCount++;
              }
            } catch (_) {}
          }
          if (missingCount >= 2 || (sample.length == 1 && missingCount == 1)) {
            migrationDetected = true;
          }
        }
      }

      await dao.putSyncValue(
        serverId,
        SyncKeys.serverVersion,
        ver,
        DateTime.now(),
      );

      if (migrationDetected) {
        AppLogger.w(
          'Reachability',
          'Navidrome 0.64+ ID migration detected on server probe for $serverId',
        );
        await dao.putSyncValue(
          serverId,
          SyncKeys.migrationDetected,
          'true',
          DateTime.now(),
        );
        _ref
            .read(serverMigrationAlertProvider.notifier)
            .setAlert(serverId, true);
      }
    } catch (e, st) {
      AppLogger.w('Reachability', 'Error checking server migration: $e\n$st');
    }
  }

  void _persistReachability(bool isReachable) {
    final policy = _ref.read(platformOfflinePolicyProvider);
    if (!policy.persistReachabilityState) return;
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setBool(kLastServerReachablePrefKey, isReachable);
        })
        .catchError((_) {});
  }

  /// Probes the server with a platform-appropriate timeout.
  Future<bool> probeServer({Duration? timeout, bool silent = false}) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      state = const ServerReachability();
      _retryTimer?.cancel();
      _retryTimer = null;
      return true;
    }

    final policy = _ref.read(platformOfflinePolicyProvider);
    final effectiveTimeout =
        timeout ??
        (policy.supportsCellular
            ? const Duration(milliseconds: 3500)
            : const Duration(seconds: 8));

    state = state.copyWith(isProbing: true);
    String? error;
    try {
      error = await client
          .tryPing(timeout: effectiveTimeout)
          .timeout(
            effectiveTimeout,
            onTimeout: () =>
                'Connection timed out (${effectiveTimeout.inSeconds}s)',
          );
    } catch (e) {
      error = e.toString();
    }
    final isPingSuccess = error == null;
    final wasReachable = state.isReachable;
    final failures = isPingSuccess ? 0 : state.consecutiveFailures + 1;

    // Platform-specific reachability determination:
    // On desktop (macOS/Windows), a single failed probe (e.g. waking from sleep)
    // must not eagerly flip reachability if it hasn't met the failure threshold.
    final bool newReachable;
    if (isPingSuccess) {
      newReachable = true;
    } else if (failures >= policy.reachabilityFailureThreshold) {
      newReachable = false;
    } else {
      newReachable = wasReachable;
    }

    state = ServerReachability(
      isReachable: newReachable,
      isProbing: false,
      lastError: error,
      lastChecked: DateTime.now(),
      consecutiveFailures: failures,
    );

    _persistReachability(newReachable);

    if (newReachable) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
      _checkServerMigration(client);
    } else {
      _startRetryTimer();
    }

    if (!newReachable &&
        wasReachable &&
        !silent &&
        policy.autoOfflineOnReachabilityFailure) {
      final errDisplay = error;
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable ($errDisplay). Switched to Offline mode.');
    }

    return newReachable;
  }

  void markReachable() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    state = state.copyWith(
      isReachable: true,
      lastError: null,
      consecutiveFailures: 0,
    );
    _persistReachability(true);
  }

  void markUnreachable(String reason) {
    final wasReachable = state.isReachable;
    state = state.copyWith(
      isReachable: false,
      lastError: reason,
      consecutiveFailures: state.consecutiveFailures + 1,
    );
    _persistReachability(false);
    _startRetryTimer();
    final policy = _ref.read(platformOfflinePolicyProvider);
    if (wasReachable && policy.autoOfflineOnReachabilityFailure) {
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable ($reason). Switched to Offline mode.');
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _scheduleNextRetry();
  }

  void _scheduleNextRetry() {
    _retryTimer?.cancel();
    if (state.isReachable) return;

    // Fast backoff for quick recovery: 4s -> 8s -> 15s -> 30s
    const delays = [4, 8, 15, 30];
    final delaySec = _retryAttempt < delays.length ? delays[_retryAttempt] : 30;
    _retryAttempt++;

    _retryTimer = Timer(Duration(seconds: delaySec), () async {
      if (!state.isReachable && !state.isProbing) {
        final reachable = await probeServer(silent: true);
        if (!reachable) {
          _scheduleNextRetry();
        }
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

/// Transient in-window toaster message.
final offlineToastMessageProvider =
    StateNotifierProvider<OfflineToastNotifier, String?>((ref) {
      return OfflineToastNotifier();
    });

class OfflineToastNotifier extends StateNotifier<String?> {
  OfflineToastNotifier() : super(null);
  Timer? _timer;

  void show(String message, {Duration duration = const Duration(seconds: 4)}) {
    _timer?.cancel();
    state = message;
    _timer = Timer(duration, () {
      if (mounted && state == message) {
        state = null;
      }
    });
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

void _persistOfflineState(bool isOffline, PlatformOfflinePolicy policy) {
  if (!policy.persistReachabilityState) return;
  SharedPreferences.getInstance()
      .then((prefs) {
        prefs.setBool(kLastIsOfflinePrefKey, isOffline);
      })
      .catchError((_) {});
}

void _persistCellularState(bool isCellular, PlatformOfflinePolicy policy) {
  if (!policy.persistReachabilityState) return;
  SharedPreferences.getInstance()
      .then((prefs) {
        prefs.setBool(kLastIsCellularPrefKey, isCellular);
      })
      .catchError((_) {});
}

/// Whether the app is currently operating in offline mode.
final isOfflineModeProvider = Provider<bool>((ref) {
  final policy = ref.watch(platformOfflinePolicyProvider);
  final manual = ref.watch(offlineManualOverrideProvider);
  if (manual) {
    _persistOfflineState(true, policy);
    return true;
  }

  // 1. Auto-offline when using Android Auto or connected to vehicle (supported platforms)
  if (policy.supportsCarConnection) {
    final autoOfflineOnCar = ref.watch(offlineOnAndroidAutoSettingProvider);
    final isCarConnected = ref.watch(isCarConnectedProvider);
    if (autoOfflineOnCar && isCarConnected) {
      _persistOfflineState(true, policy);
      return true;
    }
  }

  // 2. Physical network connectivity
  if (policy.autoOfflineOnNoNetwork) {
    final connectivity =
        ref.watch(connectivityStreamProvider).valueOrNull ??
        ref.watch(connectivityProvider).valueOrNull;
    if (connectivity != null) {
      final hasConnection = connectivity.any(
        (c) =>
            c != ConnectivityResult.none && c != ConnectivityResult.bluetooth,
      );
      if (!hasConnection) {
        _persistOfflineState(true, policy);
        return true;
      }
    }
  }

  // 3. Cellular auto-offline setting (supported platforms)
  if (policy.supportsCellular) {
    final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
    if (onCellularSetting) {
      final connectivity =
          ref.watch(connectivityStreamProvider).valueOrNull ??
          ref.watch(connectivityProvider).valueOrNull;
      if (connectivity != null) {
        final isMobile = connectivity.contains(ConnectivityResult.mobile);
        final hasWifiOrEthernet =
            connectivity.contains(ConnectivityResult.wifi) ||
            connectivity.contains(ConnectivityResult.ethernet) ||
            connectivity.contains(ConnectivityResult.vpn) ||
            connectivity.contains(ConnectivityResult.other);
        final isCellularOnly = isMobile && !hasWifiOrEthernet;
        _persistCellularState(isCellularOnly, policy);
        if (isCellularOnly) {
          _persistOfflineState(true, policy);
          return true;
        }
      } else {
        // Startup frame 1 fallback: check persisted last-known cellular state
        final lastWasCellular = ref.watch(lastKnownCellularProvider);
        if (lastWasCellular) {
          _persistOfflineState(true, policy);
          return true;
        }
      }
    }
  }

  final server = ref.watch(activeServerProvider);
  if (server == null) {
    _persistOfflineState(false, policy);
    return false;
  }

  final reachability = ref.watch(serverReachabilityProvider);
  if (!reachability.isReachable) {
    if (policy.autoOfflineOnReachabilityFailure) {
      _persistOfflineState(true, policy);
      return true;
    }
  }

  _persistOfflineState(false, policy);
  return false;
});

/// Specific reason why offline mode is active.
final offlineReasonProvider = Provider<OfflineReason>((ref) {
  final manual = ref.watch(offlineManualOverrideProvider);
  if (manual) return OfflineReason.manual;

  final policy = ref.watch(platformOfflinePolicyProvider);

  // 1. Auto-offline on car connection
  if (policy.supportsCarConnection) {
    final autoOfflineOnCar = ref.watch(offlineOnAndroidAutoSettingProvider);
    final isCarConnected = ref.watch(isCarConnectedProvider);
    if (autoOfflineOnCar && isCarConnected) {
      return OfflineReason.androidAuto;
    }
  }

  // 2. Physical network connectivity
  if (policy.autoOfflineOnNoNetwork) {
    final connectivity =
        ref.watch(connectivityStreamProvider).valueOrNull ??
        ref.watch(connectivityProvider).valueOrNull;
    if (connectivity != null) {
      final hasConnection = connectivity.any(
        (c) =>
            c != ConnectivityResult.none && c != ConnectivityResult.bluetooth,
      );
      if (!hasConnection) {
        return OfflineReason.noNetwork;
      }
    }
  }

  // 3. Cellular auto-offline setting
  if (policy.supportsCellular) {
    final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
    if (onCellularSetting) {
      final connectivity =
          ref.watch(connectivityStreamProvider).valueOrNull ??
          ref.watch(connectivityProvider).valueOrNull;
      if (connectivity != null) {
        final isMobile = connectivity.contains(ConnectivityResult.mobile);
        final hasWifiOrEthernet =
            connectivity.contains(ConnectivityResult.wifi) ||
            connectivity.contains(ConnectivityResult.ethernet) ||
            connectivity.contains(ConnectivityResult.vpn) ||
            connectivity.contains(ConnectivityResult.other);
        if (isMobile && !hasWifiOrEthernet) {
          return OfflineReason.cellular;
        }
      } else {
        final lastWasCellular = ref.watch(lastKnownCellularProvider);
        if (lastWasCellular) {
          return OfflineReason.cellular;
        }
      }
    }
  }

  final server = ref.watch(activeServerProvider);
  if (server == null) {
    return OfflineReason.none;
  }

  final reachability = ref.watch(serverReachabilityProvider);
  if (!reachability.isReachable) {
    if (policy.autoOfflineOnReachabilityFailure) {
      return OfflineReason.serverUnreachable;
    }
  }

  return OfflineReason.none;
});
