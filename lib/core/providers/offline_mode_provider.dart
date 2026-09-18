import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/services/database/tables/orderings.dart';
import 'package:flax/services/platform/car_connection_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

const _kOfflineManualPrefKey = 'flax_offline_manual_override';
const _kOfflineOnCellularPrefKey = 'flax_offline_on_cellular';
const _kOfflineOnAndroidAutoPrefKey = 'flax_offline_on_android_auto';

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

  const ServerReachability({
    this.isReachable = true,
    this.isProbing = false,
    this.lastError,
    this.lastChecked,
  });

  ServerReachability copyWith({
    bool? isReachable,
    bool? isProbing,
    String? lastError,
    DateTime? lastChecked,
  }) {
    return ServerReachability(
      isReachable: isReachable ?? this.isReachable,
      isProbing: isProbing ?? this.isProbing,
      lastError: lastError ?? this.lastError,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

/// Probes the server with a 3-second hard timeout and falls back to offline mode.
final serverReachabilityProvider =
    StateNotifierProvider<ServerReachabilityNotifier, ServerReachability>((
      ref,
    ) {
      return ServerReachabilityNotifier(ref);
    });

class ServerReachabilityNotifier extends StateNotifier<ServerReachability> {
  final Ref _ref;
  Timer? _retryTimer;

  ServerReachabilityNotifier(this._ref) : super(const ServerReachability()) {
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

  /// Probes the server with a configurable timeout (default 10s).
  Future<bool> probeServer({
    Duration timeout = const Duration(seconds: 10),
    bool silent = false,
  }) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      state = const ServerReachability();
      _retryTimer?.cancel();
      _retryTimer = null;
      return true;
    }

    state = state.copyWith(isProbing: true);
    String? error;
    try {
      error = await client
          .tryPing(timeout: timeout)
          .timeout(
            timeout,
            onTimeout: () => 'Connection timed out (${timeout.inSeconds}s)',
          );
    } catch (e) {
      error = e.toString();
    }
    final isReachable = error == null;

    final wasReachable = state.isReachable;
    state = ServerReachability(
      isReachable: isReachable,
      isProbing: false,
      lastError: error,
      lastChecked: DateTime.now(),
    );

    if (isReachable) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _checkServerMigration(client);
    } else {
      _startRetryTimer();
    }

    if (!isReachable && wasReachable && !silent) {
      // Trigger toaster notification
      final errDisplay = error;
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable ($errDisplay). Switched to Offline mode.');
    }

    return isReachable;
  }

  void markReachable() {
    _retryTimer?.cancel();
    _retryTimer = null;
    state = state.copyWith(isReachable: true, lastError: null);
  }

  void markUnreachable(String reason) {
    final wasReachable = state.isReachable;
    state = state.copyWith(isReachable: false, lastError: reason);
    _startRetryTimer();
    if (wasReachable) {
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable ($reason). Switched to Offline mode.');
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.isReachable && !state.isProbing) {
        probeServer(silent: true);
      } else if (state.isReachable) {
        _retryTimer?.cancel();
        _retryTimer = null;
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

/// Whether the app is currently operating in offline mode.
final isOfflineModeProvider = Provider<bool>((ref) {
  final manual = ref.watch(offlineManualOverrideProvider);
  if (manual) return true;

  // Auto-offline when using Android Auto or connected to vehicle
  final autoOfflineOnCar = ref.watch(offlineOnAndroidAutoSettingProvider);
  final isCarConnected = ref.watch(isCarConnectedProvider);
  if (autoOfflineOnCar && isCarConnected) {
    return true;
  }

  final connectivity =
      ref.watch(connectivityStreamProvider).valueOrNull ??
      ref.watch(connectivityProvider).valueOrNull;
  if (connectivity != null) {
    final hasConnection = connectivity.any(
      (c) => c != ConnectivityResult.none && c != ConnectivityResult.bluetooth,
    );
    if (!hasConnection) {
      return true;
    }
  }

  final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
  if (onCellularSetting && connectivity != null) {
    final isMobile = connectivity.contains(ConnectivityResult.mobile);
    final hasWifiOrEthernet =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet) ||
        connectivity.contains(ConnectivityResult.vpn) ||
        connectivity.contains(ConnectivityResult.other);
    if (isMobile && !hasWifiOrEthernet) {
      return true;
    }
  }

  final server = ref.watch(activeServerProvider);
  if (server == null) {
    return false;
  }

  final reachability = ref.watch(serverReachabilityProvider);
  if (!reachability.isReachable) {
    return true;
  }

  return false;
});

/// Specific reason why offline mode is active.
final offlineReasonProvider = Provider<OfflineReason>((ref) {
  final manual = ref.watch(offlineManualOverrideProvider);
  if (manual) return OfflineReason.manual;

  // Auto-offline when using Android Auto or connected to vehicle
  final autoOfflineOnCar = ref.watch(offlineOnAndroidAutoSettingProvider);
  final isCarConnected = ref.watch(isCarConnectedProvider);
  if (autoOfflineOnCar && isCarConnected) {
    return OfflineReason.androidAuto;
  }

  final connectivity =
      ref.watch(connectivityStreamProvider).valueOrNull ??
      ref.watch(connectivityProvider).valueOrNull;
  if (connectivity != null) {
    final hasConnection = connectivity.any(
      (c) => c != ConnectivityResult.none && c != ConnectivityResult.bluetooth,
    );
    if (!hasConnection) {
      return OfflineReason.noNetwork;
    }
  }

  final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
  if (onCellularSetting && connectivity != null) {
    final isMobile = connectivity.contains(ConnectivityResult.mobile);
    final hasWifiOrEthernet =
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet) ||
        connectivity.contains(ConnectivityResult.vpn) ||
        connectivity.contains(ConnectivityResult.other);
    if (isMobile && !hasWifiOrEthernet) {
      return OfflineReason.cellular;
    }
  }

  final server = ref.watch(activeServerProvider);
  if (server == null) {
    return OfflineReason.none;
  }

  final reachability = ref.watch(serverReachabilityProvider);
  if (!reachability.isReachable) {
    return OfflineReason.serverUnreachable;
  }

  return OfflineReason.none;
});
