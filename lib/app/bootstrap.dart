import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/app/router.dart';
import 'package:flax/app/screen_recovery.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/car_connection_service.dart';

/// How long any one startup step may hold up the first frame.
///
/// Healthy, these steps take milliseconds. The bound exists for the step that
/// never answers at all, which used to leave the app on its splash screen until
/// it was killed: on Android, main() runs in an engine FlaxApplication starts on
/// every process start — Android Auto, a media button and background sync
/// included — so a call that needs an Activity, made before there is one, never
/// gets a reply. A slow launch beats one that never finishes.
const kStartupStepTimeout = Duration(seconds: 4);

/// Runs one step of startup, logs how long it took, and stops waiting for it
/// after [timeout].
///
/// The step itself is not cancelled — Dart cannot cancel a future — so it may
/// still finish later; only the first frame stops waiting for it. Errors are
/// logged rather than thrown, because no single step is worth not starting for.
Future<void> startupStep(
  String name,
  Future<void> Function() body, {
  Duration timeout = kStartupStepTimeout,
}) async {
  final watch = Stopwatch()..start();
  try {
    await body().timeout(timeout);
    AppLogger.i('Startup', '$name ready in ${watch.elapsedMilliseconds}ms');
  } on TimeoutException {
    AppLogger.w(
      'Startup',
      '$name did not answer within ${timeout.inMilliseconds}ms; '
          'starting without it',
    );
  } catch (e, st) {
    AppLogger.w('Startup', '$name failed', error: e, stackTrace: st);
  }
}

/// Everything that has to be read before the first frame, and nothing else.
///
/// Every await goes through [startupStep], so none of them can keep the app from
/// starting. Do not add anything that waits on an Activity (SystemChrome and the
/// rest of the `flutter/platform` channel): Android drops those calls unanswered
/// when the process was started without one. Phone orientation is locked
/// natively in MainActivity for exactly that reason.
Future<StartupState> bootstrap({
  Future<void> Function() initAudioCache = AudioCacheService.initialize,
  Future<SharedPreferences> Function() loadPrefs =
      SharedPreferences.getInstance,
  Future<bool> Function() queryCarConnected =
      CarConnectionService.queryCarConnected,
  Duration timeout = kStartupStepTimeout,
}) async {
  SharedPreferences? prefs;
  var carConnected = false;
  await Future.wait([
    startupStep('audio cache location', initAudioCache, timeout: timeout),
    startupStep('preferences', () async {
      prefs = await loadPrefs();
    }, timeout: timeout),
    // Read before anything decides whether the app is offline. With the
    // Android Auto offline setting on, that decision hangs on this answer;
    // without it the first moments of every car start ran as if online and
    // went to the server before the real state flipped them offline.
    startupStep('car connection', () async {
      carConnected = await queryCarConnected();
      AppLogger.i('Startup', 'Car connected: $carConnected');
    }, timeout: timeout),
  ]);

  final loaded = prefs;
  if (loaded == null) return StartupState(carConnected: carConnected);
  try {
    return StartupState.fromPrefs(loaded, carConnected: carConnected);
  } catch (e, st) {
    AppLogger.w(
      'Startup',
      'Could not read saved state; using defaults',
      error: e,
      stackTrace: st,
    );
    return StartupState(carConnected: carConnected);
  }
}

/// The saved state the first frame is built from.
class StartupState {
  const StartupState({
    this.prefsLoaded = false,
    this.savedRoute,
    this.servers = const [],
    this.locale,
    this.offlineManual = false,
    this.offlineOnCellular = false,
    this.offlineOnAndroidAuto = false,
    this.lastCellular = false,
    this.lastOffline = false,
    this.lastReachable,
    this.carConnected = false,
  });

  factory StartupState.fromPrefs(
    SharedPreferences prefs, {
    bool carConnected = false,
  }) {
    var savedRoute = prefs.getString(lastRouteStorageKey);
    if (savedRoute != null && !isValidRoute(savedRoute)) {
      savedRoute = null;
      unawaited(prefs.remove(lastRouteStorageKey));
    }
    // The last run ended on a screen that failed to build. Reopening it could
    // fail the same way every time, so start from the library instead.
    if (ScreenRecovery.takePreviousFailure(prefs)) {
      AppLogger.w('Startup', 'Last run ended on a failed screen; opening home');
      savedRoute = null;
    }
    return StartupState(
      prefsLoaded: true,
      savedRoute: savedRoute,
      servers: ServerListNotifier.loadServersFromPrefs(prefs),
      locale: LocaleNotifier.loadLocaleFromPrefs(prefs),
      offlineManual: OfflineManualNotifier.loadFromPrefs(prefs),
      offlineOnCellular: OfflineOnCellularNotifier.loadFromPrefs(prefs),
      offlineOnAndroidAuto: OfflineOnAndroidAutoNotifier.loadFromPrefs(prefs),
      lastCellular: prefs.getBool(kLastIsCellularPrefKey) ?? false,
      lastOffline: prefs.getBool(kLastIsOfflinePrefKey) ?? false,
      lastReachable: prefs.getBool(kLastServerReachablePrefKey),
      carConnected: carConnected,
    );
  }

  /// False when preferences could not be read in time.
  final bool prefsLoaded;
  final String? savedRoute;
  final List<Server> servers;
  final Locale? locale;
  final bool offlineManual;
  final bool offlineOnCellular;
  final bool offlineOnAndroidAuto;
  final bool lastCellular;
  final bool lastOffline;
  final bool? lastReachable;

  /// Whether a car was connected when the app started.
  final bool carConnected;

  /// Provider overrides that hand this state to the first frame.
  ///
  /// Saved state is left out when preferences were not read. Each notifier then
  /// loads its own value once preferences answer, rather than being pinned to a
  /// default — an empty server list pinned here would open server setup as
  /// though the saved server had been forgotten.
  List<Override> get overrides {
    final car = [
      if (carConnected)
        carConnectionServiceProvider.overrideWith((ref) {
          final service = CarConnectionService(initiallyConnected: true);
          ref.onDispose(service.dispose);
          return service;
        }),
    ];
    if (!prefsLoaded) return car;
    return [
      ...car,
      if (savedRoute != null)
        savedRouteProvider.overrideWith((ref) => savedRoute),
      if (servers.isNotEmpty)
        serverListProvider.overrideWith(
          (ref) => ServerListNotifier(initialServers: servers),
        ),
      if (locale != null)
        localeProvider.overrideWith((ref) => LocaleNotifier(locale)),
      offlineManualOverrideProvider.overrideWith(
        (ref) => OfflineManualNotifier(initialValue: offlineManual),
      ),
      offlineOnCellularSettingProvider.overrideWith(
        (ref) => OfflineOnCellularNotifier(initialValue: offlineOnCellular),
      ),
      offlineOnAndroidAutoSettingProvider.overrideWith(
        (ref) =>
            OfflineOnAndroidAutoNotifier(initialValue: offlineOnAndroidAuto),
      ),
      lastKnownCellularProvider.overrideWith((ref) => lastCellular),
      lastKnownOfflineProvider.overrideWith((ref) => lastOffline),
      if (lastReachable != null &&
          PlatformOfflinePolicy.current().persistReachabilityState)
        serverReachabilityProvider.overrideWith(
          (ref) => ServerReachabilityNotifier(
            ref,
            initialReachability: ServerReachability(
              isReachable: lastReachable!,
            ),
          ),
        ),
    ];
  }
}
