import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';
import 'package:flax/app/router.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/orientation_service.dart';
import 'package:flax/services/platform/window_state.dart';
import 'package:flax/shared/widgets/art_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock mobile orientation to portrait.
  await OrientationService.lockToPortrait();

  // Needs the binding, and must happen before any art is decoded.
  ArtCache.configureDecodedImageCache();
  await AudioCacheService.initialize();

  // Load last visited route for launch persistence across all platforms.
  String? savedRoute;
  try {
    final prefs = await SharedPreferences.getInstance();
    savedRoute = prefs.getString(lastRouteStorageKey);
  } catch (_) {
    savedRoute = null;
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

  runApp(
    ProviderScope(
      overrides: [
        if (savedRoute != null)
          savedRouteProvider.overrideWith((ref) => savedRoute),
      ],
      child: const FlaxApp(),
    ),
  );
}
