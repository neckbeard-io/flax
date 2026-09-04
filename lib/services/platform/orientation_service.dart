import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Manages device screen orientation constraints across platforms.
class OrientationService {
  OrientationService._();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Locks screen orientation to portrait on phone devices (Android/iOS).
  ///
  /// On desktop platforms (macOS, Windows, Linux) and tablet / automotive screens
  /// (width > height or shortestSide >= 600dp), orientation locking is skipped so
  /// wide-screen in-car displays and landscape layouts remain unaffected.
  static Future<void> lockToPortrait({
    bool? isMobileOverride,
    Future<void> Function(List<DeviceOrientation>)? setOrientations,
    ui.FlutterView? viewOverride,
  }) async {
    final mobile = isMobileOverride ?? isMobile;
    if (!mobile) return;

    try {
      final view =
          viewOverride ??
          (WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
              ? WidgetsBinding.instance.platformDispatcher.views.first
              : null);
      if (view != null &&
          view.physicalSize.width > 0 &&
          view.physicalSize.height > 0) {
        final dpr = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1.0;
        final widthDp = view.physicalSize.width / dpr;
        final heightDp = view.physicalSize.height / dpr;
        final shortestSide = math.min(widthDp, heightDp);
        final isLandscape = widthDp > heightDp;

        // Skip locking on landscape (automotive) or tablet (shortestSide >= 600) form factors.
        if (isLandscape || shortestSide >= 600) {
          return;
        }
      }
    } catch (_) {
      // Fall through to standard lock if view inspection fails.
    }

    final setter = setOrientations ?? SystemChrome.setPreferredOrientations;
    await setter(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
