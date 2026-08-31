import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';
import 'package:flax/app/router.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/locale_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/audio/audio_handler_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/orientation_service.dart';
import 'package:flax/services/platform/window_state.dart';
import 'package:flax/shared/widgets/art_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('App', 'Flax starting on ${Platform.operatingSystem}');
  MpvAudioKit.ensureInitialized();

  // Lock mobile orientation to portrait.
  await OrientationService.lockToPortrait();

  // Needs the binding, and must happen before any art is decoded.
  ArtCache.configureDecodedImageCache();
  await AudioCacheService.initialize();

  // Load last visited route, servers, and locale for launch persistence across all platforms.
  String? savedRoute;
  List<Server> initialServers = [];
  Locale? initialLocale;
  try {
    final prefs = await SharedPreferences.getInstance();
    savedRoute = prefs.getString(lastRouteStorageKey);
    initialServers = ServerListNotifier.loadServersFromPrefs(prefs);
    initialLocale = LocaleNotifier.loadLocaleFromPrefs(prefs);
  } catch (_) {
    savedRoute = null;
    initialServers = [];
    initialLocale = null;
  }

  if (WindowStateService.isSupported) {
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
    ],
  );

  final audioHandler = await AudioServiceInitializer.initialize(container);
  if (audioHandler != null) {
    container.read(audioHandlerProvider.notifier).state = audioHandler;
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const FlaxApp()),
  );
}
