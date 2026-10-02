import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';
import 'package:flax/app/bootstrap.dart';
import 'package:flax/app/router.dart';
import 'package:flax/app/screen_recovery.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/logging/crash_log.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/audio/audio_handler_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/background_sync_service.dart';
import 'package:flax/services/platform/window_state.dart';
import 'package:flax/shared/widgets/art_cache.dart';
import 'package:flax/shared/widgets/cover_art_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(CrashLog.init());

  // Catch unhandled Flutter and platform errors to prevent silent startup crashes.
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.e(
      'FlutterError',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    CrashLog.record('FlutterError', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.e(
      'PlatformDispatcher',
      'Uncaught platform error: $error',
      error: error,
      stackTrace: stack,
    );
    CrashLog.record('Uncaught', error, stack);
    return true;
  };
  // Debug builds keep the red error screen, which shows the whole error.
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => RecoveryView(details);
  }

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

  // Everything awaited before runApp goes through bootstrap()/startupStep(),
  // which bound every step — see kStartupStepTimeout for why that matters.
  final startup = await bootstrap();

  if (WindowStateService.isSupported) {
    await startupStep('window', _initDesktopWindow);
  }

  final container = ProviderContainer(overrides: startup.overrides);
  ScreenRecovery.install(
    goHome: () => container.read(routerProvider).go('/albums'),
  );

  // Media service first, then the UI. When Android Auto starts the app there
  // is no screen to show, and its browse requests wait on this; starting it
  // before mounting means it is not queued behind building the first frame.
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

  AppLogger.i(
    'Startup',
    'Offline at start: ${container.read(offlineReasonProvider).name}',
  );

  // Mount UI immediately so the initial frame renders without delay.
  runApp(
    UncontrolledProviderScope(container: container, child: const FlaxApp()),
  );
  AppLogger.i('Startup', 'UI mounted');

  // Reconcile local downloads in background to prune ghost downloads and heal paths
  unawaited(
    container.read(audioCacheServiceProvider).reconcileLocalDownloads(),
  );

  // Once, well after launch: covers earlier downloads filed under their
  // request URL become findable offline. Delayed so it never competes with
  // startup or an Android Auto connection for disk.
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 20),
      CoverArtCache.rekeyLegacyEntriesOnce,
    ),
  );

  // Ensure periodic background sync is scheduled on Android if enabled
  if (Platform.isAndroid) {
    try {
      final activeServer =
          startup.servers.where((s) => s.isActive).firstOrNull ??
          startup.servers.firstOrNull;
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

/// Sizes and shows the desktop window before the first frame.
Future<void> _initDesktopWindow() async {
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
}
