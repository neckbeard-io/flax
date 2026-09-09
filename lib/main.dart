import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';
import 'package:flax/app/router.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/audio/audio_handler_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/background_sync_service.dart';
import 'package:flax/services/platform/orientation_service.dart';
import 'package:flax/services/platform/window_state.dart';
import 'package:flax/shared/widgets/art_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch unhandled Flutter and platform errors to prevent silent startup crashes.
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.e(
      'FlutterError',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.e(
      'PlatformDispatcher',
      'Uncaught platform error: $error',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  AppLogger.i('App', 'Flax starting on ${Platform.operatingSystem}');

  try {
    MpvAudioKit.ensureInitialized();
  } catch (e, st) {
    AppLogger.w(
      'App',
      'MpvAudioKit.ensureInitialized failed',
      error: e,
      stackTrace: st,
    );
  }

  // Lock mobile orientation to portrait.
  try {
    await OrientationService.lockToPortrait();
  } catch (e, st) {
    AppLogger.w(
      'App',
      'OrientationService.lockToPortrait failed',
      error: e,
      stackTrace: st,
    );
  }

  // Needs the binding, and must happen before any art is decoded.
  try {
    ArtCache.configureDecodedImageCache();
  } catch (e, st) {
    AppLogger.w(
      'App',
      'ArtCache.configureDecodedImageCache failed',
      error: e,
      stackTrace: st,
    );
  }

  try {
    await AudioCacheService.initialize();
  } catch (e, st) {
    AppLogger.w(
      'App',
      'AudioCacheService.initialize failed',
      error: e,
      stackTrace: st,
    );
  }

  // Load last visited route, servers, locale, and offline preferences for launch persistence across all platforms.
  String? savedRoute;
  List<Server> initialServers = [];
  Locale? initialLocale;
  bool initialOfflineManual = false;
  bool initialOfflineOnCellular = false;
  bool initialOfflineOnAndroidAuto = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    savedRoute = prefs.getString(lastRouteStorageKey);
    initialServers = ServerListNotifier.loadServersFromPrefs(prefs);
    initialLocale = LocaleNotifier.loadLocaleFromPrefs(prefs);
    initialOfflineManual = OfflineManualNotifier.loadFromPrefs(prefs);
    initialOfflineOnCellular = OfflineOnCellularNotifier.loadFromPrefs(prefs);
    initialOfflineOnAndroidAuto = OfflineOnAndroidAutoNotifier.loadFromPrefs(
      prefs,
    );
  } catch (_) {
    savedRoute = null;
    initialServers = [];
    initialLocale = null;
    initialOfflineManual = false;
    initialOfflineOnCellular = false;
    initialOfflineOnAndroidAuto = false;
  }

  if (WindowStateService.isSupported) {
    try {
      await windowManager.ensureInitialized();

      // Windows and Linux create standard window captions, which sat above
      // flax's own styled title bar. Hide the native one so only the styled bar remains.
      //
      // macOS does not go through this: MainFlutterWindow.swift already hides the
      // title bar natively (fullSizeContentView + hidden traffic lights) and
      // serves the com.flax/window channel. Only the *sizing* below is shared.
      if (Platform.isWindows || Platform.isLinux) {
        await windowManager.waitUntilReadyToShow(
          const WindowOptions(
            titleBarStyle: TitleBarStyle.hidden,
            // Deliberately shown only once the title bar has been hidden, so the
            // native caption never flashes on startup.
            skipTaskbar: false,
          ),
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );
      }

      // Before runApp, so the window is the right size for the first frame
      // rather than being resized out from under a laid-out UI.
      await WindowStateService.instance.restore();
    } catch (e, st) {
      AppLogger.w(
        'App',
        'WindowStateService initialization failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  final container = ProviderContainer(
    overrides: [
      if (savedRoute != null)
        savedRouteProvider.overrideWith((ref) => savedRoute),
      if (initialServers.isNotEmpty)
        serverListProvider.overrideWith(
          (ref) => ServerListNotifier(initialServers: initialServers),
        ),
      if (initialLocale != null)
        localeProvider.overrideWith((ref) => LocaleNotifier(initialLocale)),
      offlineManualOverrideProvider.overrideWith(
        (ref) => OfflineManualNotifier(initialValue: initialOfflineManual),
      ),
      offlineOnCellularSettingProvider.overrideWith(
        (ref) =>
            OfflineOnCellularNotifier(initialValue: initialOfflineOnCellular),
      ),
      offlineOnAndroidAutoSettingProvider.overrideWith(
        (ref) => OfflineOnAndroidAutoNotifier(
          initialValue: initialOfflineOnAndroidAuto,
        ),
      ),
    ],
  );

  // Mount UI immediately so the initial frame renders without delay.
  runApp(
    UncontrolledProviderScope(container: container, child: const FlaxApp()),
  );

  // Initialize audio service asynchronously after runApp so the UI renders immediately.
  // This guarantees the app opens instantly on Android even if audio service initialization is delayed.
  unawaited(
    AudioServiceInitializer.initialize(container)
        .then((audioHandler) {
          if (audioHandler != null) {
            container.read(audioHandlerProvider.notifier).state = audioHandler;
            final currentState = container.read(playerProvider);
            audioHandler.updateFromPlayerState(currentState);
          }
        })
        .catchError((e, st) {
          AppLogger.e(
            'App',
            'Failed to initialize audioHandler after launch',
            error: e,
            stackTrace: st,
          );
        }),
  );

  // Ensure periodic background sync is scheduled on Android if enabled
  if (Platform.isAndroid) {
    try {
      final activeServer =
          initialServers.where((s) => s.isActive).firstOrNull ??
          initialServers.firstOrNull;
      if (activeServer != null &&
          activeServer.metadataCacheConfig.backgroundSyncEnabled) {
        final cfg = activeServer.metadataCacheConfig;
        container
            .read(backgroundSyncServiceProvider)
            .schedulePeriodicSync(
              intervalHours: cfg.backgroundSyncIntervalHours,
              requiresCharging: cfg.backgroundSyncRequiresCharging,
              wifiOnly: cfg.backgroundSyncWifiOnly,
            );
      }
    } catch (e, st) {
      AppLogger.w(
        'App',
        'Failed to schedule periodic sync',
        error: e,
        stackTrace: st,
      );
    }
  }
}
