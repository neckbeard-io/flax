import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Remembers where the window was, and picks somewhere sensible the first time.
///
/// The window used to open at whatever the macOS storyboard said, which is a
/// fixed size chosen years before any of this layout existed: small enough that
/// the now-playing panel switcher had to wrap its own labels, and identical on
/// a 13" laptop and a 4K display.

/// Smallest window worth allowing. Well under the 700pt panel breakpoint, so
/// the narrow single-column layout is still reachable by dragging — this only
/// rules out sizes where nothing at all can be read.
const Size kMinWindowSize = Size(460, 480);

/// Fraction of the display the window takes on first run.
const double _firstRunScreenFraction = 0.8;

/// Ceiling for the first-run size.
///
/// Not a limit on what the user may drag to — only on what we choose for them.
/// 80% of a 4K display is a 3000pt window, which is not a considerate default
/// for a music player; past roughly this size the panels stop gaining anything
/// and just hold more whitespace.
const Size _firstRunMaxSize = Size(1900, 1250);

/// Window size to open at on a display of [screen], having never run before.
Size firstRunWindowSize(Size screen) {
  final width = (screen.width * _firstRunScreenFraction)
      .clamp(kMinWindowSize.width, _firstRunMaxSize.width);
  final height = (screen.height * _firstRunScreenFraction)
      .clamp(kMinWindowSize.height, _firstRunMaxSize.height);
  return Size(width, height);
}

/// Fits [wanted] onto [screen], so a restored window is always reachable.
///
/// Monitors come and go: a window saved on a second display, or on a screen
/// that was larger last time, would otherwise be restored somewhere the user
/// cannot see it, which looks exactly like the app failing to start.
Rect fitToScreen(Rect wanted, Rect screen) {
  final width = wanted.width
      .clamp(kMinWindowSize.width, screen.width)
      .toDouble();
  final height = wanted.height
      .clamp(kMinWindowSize.height, screen.height)
      .toDouble();
  final left = wanted.left.clamp(screen.left, screen.right - width).toDouble();
  final top = wanted.top.clamp(screen.top, screen.bottom - height).toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

/// Encodes a window rectangle for preferences. Deliberately a plain string:
/// four doubles do not need a JSON document, and a malformed one decodes to
/// null rather than throwing on launch.
String encodeWindowBounds(Rect bounds) =>
    '${bounds.left},${bounds.top},${bounds.width},${bounds.height}';

Rect? decodeWindowBounds(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(',');
  if (parts.length != 4) return null;
  final values = [for (final p in parts) double.tryParse(p)];
  if (values.any((v) => v == null || !v.isFinite)) return null;
  if (values[2]! <= 0 || values[3]! <= 0) return null;
  return Rect.fromLTWH(values[0]!, values[1]!, values[2]!, values[3]!);
}

/// Restores and persists the window rectangle. Desktop only; on a phone the
/// window is the screen.
class WindowStateService with WindowListener {
  WindowStateService._();

  static final instance = WindowStateService._();

  static const _boundsKey = 'flax_window_bounds';

  static bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Sizes the window before the first frame. Call after
  /// [WindowManager.ensureInitialized].
  Future<void> restore() async {
    if (!isSupported) return;

    final screen = _screenBounds();
    final prefs = await SharedPreferences.getInstance();
    final saved = decodeWindowBounds(prefs.getString(_boundsKey));

    await windowManager.setMinimumSize(kMinWindowSize);

    if (saved != null) {
      await windowManager.setBounds(fitToScreen(saved, screen));
    } else {
      final size = firstRunWindowSize(screen.size);
      await windowManager.setSize(size);
      await windowManager.center();
    }

    windowManager.addListener(this);
  }

  // Both the continuous events and the terminal ones.
  //
  // `onWindowResized` alone is not enough: macOS raises it from
  // windowDidEndLiveResize, which only happens at the end of a *drag*. A window
  // resized by zooming, by another process, or by anything that is not a mouse
  // held down never fires it, and those sizes were silently not saved.
  // `onWindowResize` covers those, at the cost of firing every frame of a drag
  // — hence the debounce.

  @override
  void onWindowResize() => _saveSoon();

  @override
  void onWindowMove() => _saveSoon();

  @override
  void onWindowMaximize() => _saveSoon();

  @override
  void onWindowUnmaximize() => _saveSoon();

  /// Terminal events, written immediately: the drag is over, and waiting for a
  /// timer that a quit could outrun is how the last resize gets lost.
  @override
  void onWindowResized() => _saveNow();

  @override
  void onWindowMoved() => _saveNow();

  Timer? _pending;

  void _saveSoon() {
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 400), _saveNow);
  }

  Future<void> _saveNow() async {
    _pending?.cancel();
    try {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_boundsKey, encodeWindowBounds(bounds));
    } catch (_) {
      // A window that cannot be measured is not worth failing a resize over.
    }
  }

  /// The display the app is opening on, in logical pixels.
  Rect _screenBounds() {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) return const Rect.fromLTWH(0, 0, 1440, 900);
    final display = view.display;
    final ratio = display.devicePixelRatio;
    return Rect.fromLTWH(
      0,
      0,
      display.size.width / ratio,
      display.size.height / ratio,
    );
  }
}
