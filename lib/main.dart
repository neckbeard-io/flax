import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows creates a standard WS_OVERLAPPEDWINDOW caption, which sat above
  // flax's own styled title bar — two stacked bars, each with its own set of
  // window controls. Hide the native one so only the styled bar remains.
  //
  // macOS is not routed through window_manager: MainFlutterWindow.swift already
  // hides the title bar natively (fullSizeContentView + hidden traffic lights)
  // and serves the com.flax/window channel, and that works. Only Windows needs
  // this, so only Windows gets it.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
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

  runApp(
    const ProviderScope(
      child: FlaxApp(),
    ),
  );
}
