import 'dart:io';

import 'package:flutter/services.dart';

/// Manages device screen orientation constraints across platforms.
class OrientationService {
  OrientationService._();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Locks screen orientation to portrait on mobile devices (Android/iOS).
  ///
  /// On desktop platforms (macOS, Windows, Linux), orientation locking is skipped
  /// so window resizing and multi-monitor layouts remain unaffected.
  static Future<void> lockToPortrait({
    bool? isMobileOverride,
    Future<void> Function(List<DeviceOrientation>)? setOrientations,
  }) async {
    final mobile = isMobileOverride ?? isMobile;
    if (!mobile) return;

    final setter = setOrientations ?? SystemChrome.setPreferredOrientations;
    await setter(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
