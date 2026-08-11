import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';
import 'package:flax/services/platform/window_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (WindowStateService.isSupported) {
    await windowManager.ensureInitialized();

    // Windows creates a standard WS_OVERLAPPEDWINDOW caption, which sat above
    // flax's own styled title bar — two stacked bars, each with its own set of
    // window controls. Hide the native one so only the styled bar remains.
    //
    // macOS does not go through this: MainFlutterWindow.swift already hides the
    // title bar natively (fullSizeContentView + hidden traffic lights) and
    // serves the com.flax/window channel. Only the *sizing* below is shared.
    if (Platform.isWindows) {
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

  runApp(const ProviderScope(child: FlaxApp()));
}
