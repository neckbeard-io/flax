import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/connectivity_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

const _kOfflineManualPrefKey = 'flax_offline_manual_override';
const _kOfflineOnCellularPrefKey = 'flax_offline_on_cellular';
const _kOfflineOnAndroidAutoPrefKey = 'flax_offline_on_android_auto';

/// Reason why the app is currently in offline mode.
enum OfflineReason { none, manual, cellular, androidAuto, serverUnreachable }

/// Manual offline mode toggle persisted across sessions.
final offlineManualOverrideProvider =
    StateNotifierProvider<OfflineManualNotifier, bool>((ref) {
      return OfflineManualNotifier();
    });

class OfflineManualNotifier extends StateNotifier<bool> {
  OfflineManualNotifier() : super(false) {
    _load();
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
  OfflineOnCellularNotifier() : super(false) {
    _load();
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
  OfflineOnAndroidAutoNotifier() : super(false) {
    _load();
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

  ServerReachabilityNotifier(this._ref) : super(const ServerReachability()) {
    _ref.listen<SubsonicClient?>(subsonicClientProvider, (prev, next) {
      if (next != null) {
        probeServer(silent: true);
      } else {
        state = const ServerReachability();
      }
    });
  }

  /// Probes the server with a hard 3-second timeout.
  Future<bool> probeServer({
    Duration timeout = const Duration(seconds: 3),
    bool silent = false,
  }) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      state = const ServerReachability();
      return true;
    }

    state = state.copyWith(isProbing: true);
    final error = await client.tryPing(timeout: timeout);
    final isReachable = error == null;

    final wasReachable = state.isReachable;
    state = ServerReachability(
      isReachable: isReachable,
      isProbing: false,
      lastError: error,
      lastChecked: DateTime.now(),
    );

    if (!isReachable && wasReachable && !silent) {
      // Trigger toaster notification
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable (3s timeout). Switched to Offline mode.');
    }

    return isReachable;
  }

  void markReachable() {
    state = state.copyWith(isReachable: true, lastError: null);
  }

  void markUnreachable(String reason) {
    final wasReachable = state.isReachable;
    state = state.copyWith(isReachable: false, lastError: reason);
    if (wasReachable) {
      _ref
          .read(offlineToastMessageProvider.notifier)
          .show('Server unreachable ($reason). Switched to Offline mode.');
    }
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

  final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
  if (onCellularSetting) {
    final connectivity =
        ref.watch(connectivityStreamProvider).valueOrNull ??
        ref.watch(connectivityProvider).valueOrNull;
    if (connectivity != null) {
      final hasWifiOrEthernet =
          connectivity.contains(ConnectivityResult.wifi) ||
          connectivity.contains(ConnectivityResult.ethernet);
      if (!hasWifiOrEthernet) {
        return true;
      }
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

  final onCellularSetting = ref.watch(offlineOnCellularSettingProvider);
  if (onCellularSetting) {
    final connectivity =
        ref.watch(connectivityStreamProvider).valueOrNull ??
        ref.watch(connectivityProvider).valueOrNull;
    if (connectivity != null) {
      final hasWifiOrEthernet =
          connectivity.contains(ConnectivityResult.wifi) ||
          connectivity.contains(ConnectivityResult.ethernet);
      if (!hasWifiOrEthernet) {
        return OfflineReason.cellular;
      }
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
