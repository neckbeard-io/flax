import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/core/logging/app_logger.dart';

/// Set while a screen-sized part of the UI has failed, and still set at the
/// next launch if the app never recovered.
const kScreenBrokenPrefKey = 'flax_screen_broken';

/// Getting out of a screen that failed to build.
///
/// A widget that throws while building is replaced by its error widget, and
/// nothing rebuilds it by itself. On Android the app's engine also outlives
/// its screen, so swiping flax away and opening it again showed the same
/// failed screen — release builds paint it plain grey — until a force stop.
///
/// Three ways out, from least to most disruptive:
/// - The failed screen is replaced by [RecoveryView], which says what went
///   wrong and offers a restart.
/// - Coming back to the app while a screen is broken rebuilds every widget and
///   returns to the library, which clears a failure that was a one-off.
/// - The next launch after a failure opens the library instead of the screen
///   that was open, so a screen that fails every time cannot trap the app.
class ScreenRecovery {
  ScreenRecovery._();

  static const _channel = MethodChannel('com.flax/app');

  static bool _broken = false;
  static VoidCallback? _goHome;
  static AppLifecycleListener? _lifecycle;

  /// Overrides the platform restart, for tests.
  @visibleForTesting
  static Future<void> Function()? restartOverride;

  /// Whether a screen-sized part of the UI has failed and not been rebuilt.
  static bool get isBroken => _broken;

  /// Starts watching for the app coming back to the foreground. [goHome]
  /// navigates to the library.
  static void install({required VoidCallback goHome}) {
    _goHome = goHome;
    _lifecycle ??= AppLifecycleListener(onResume: heal);
  }

  /// Records that a screen-sized part of the UI failed to build.
  static void markBroken() {
    if (_broken) return;
    _broken = true;
    AppLogger.w('Recovery', 'A screen failed to build');
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool(kScreenBrokenPrefKey, true))
          .catchError((Object _) => false),
    );
  }

  /// Whether the previous run ended with a broken screen. Clears the record.
  static bool takePreviousFailure(SharedPreferences prefs) {
    final failed = prefs.getBool(kScreenBrokenPrefKey) ?? false;
    if (failed) unawaited(prefs.remove(kScreenBrokenPrefKey));
    return failed;
  }

  /// Rebuilds every widget from the library, if a screen is broken.
  static void heal() {
    if (!_broken) return;
    AppLogger.w('Recovery', 'Rebuilding after a failed screen');
    _broken = false;
    try {
      _goHome?.call();
    } catch (e, st) {
      AppLogger.w(
        'Recovery',
        'Could not return home',
        error: e,
        stackTrace: st,
      );
    }
    unawaited(WidgetsBinding.instance.reassembleApplication());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_broken) return;
      unawaited(
        SharedPreferences.getInstance()
            .then((prefs) => prefs.remove(kScreenBrokenPrefKey))
            .catchError((Object _) => false),
      );
    });
  }

  /// Restarts the app: a fresh process on Android, the same as a force stop
  /// and reopen, and a rebuild from the library elsewhere.
  static Future<void> restart() async {
    final override = restartOverride;
    if (override != null) return override();
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('restart');
        return;
      } catch (e, st) {
        AppLogger.w('Recovery', 'Restart failed', error: e, stackTrace: st);
      }
    }
    _broken = true;
    heal();
  }

  @visibleForTesting
  static void resetForTest() {
    _broken = false;
    _goHome = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    restartOverride = null;
  }
}

/// What a widget that failed to build is replaced with, in place of release
/// builds' plain grey box.
///
/// It depends on nothing above it — no theme, no localization, no media
/// query — because whatever failed may be the thing that provides them.
class RecoveryView extends StatelessWidget {
  const RecoveryView(this.details, {super.key});

  final FlutterErrorDetails details;

  /// The smallest area treated as a screen. Smaller failures, such as one
  /// tile in a list, get a quiet placeholder instead.
  static const minScreenSize = Size(240, 160);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isScreen =
            constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight &&
            constraints.maxWidth >= minScreenSize.width &&
            constraints.maxHeight >= minScreenSize.height;
        final dark =
            PlatformDispatcher.instance.platformBrightness == Brightness.dark;
        final background = dark
            ? const Color(0xFF1C1B1F)
            : const Color(0xFFF4F1F7);
        if (!isScreen) {
          return SizedBox(
            width: constraints.hasBoundedWidth ? constraints.maxWidth : 24,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : 24,
            child: ColoredBox(color: background),
          );
        }
        ScreenRecovery.markBroken();
        return _RecoveryPanel(
          details: details,
          dark: dark,
          background: background,
        );
      },
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({
    required this.details,
    required this.dark,
    required this.background,
  });

  final FlutterErrorDetails details;
  final bool dark;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? const Color(0xFFE6E1E5) : const Color(0xFF1C1B1F);
    final muted = dark ? const Color(0xFFCAC4D0) : const Color(0xFF49454F);
    final accent = dark ? const Color(0xFFD0BCFF) : const Color(0xFF6750A4);
    final onAccent = dark ? const Color(0xFF381E72) : const Color(0xFFFFFFFF);
    final error = details.exceptionAsString();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: background,
        child: DefaultTextStyle(
          style: TextStyle(
            color: foreground,
            fontSize: 15,
            height: 1.4,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.normal,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Flax hit an error drawing this screen. Restarting '
                        'flax fixes it.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _PanelButton(
                            label: 'Restart flax',
                            color: accent,
                            textColor: onAccent,
                            onTap: ScreenRecovery.restart,
                          ),
                          _PanelButton(
                            label: 'Copy error',
                            color: background,
                            textColor: accent,
                            border: accent,
                            onTap: () => Clipboard.setData(
                              ClipboardData(text: '$error\n\n${details.stack}'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color? border;
  final FutureOr<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(Future.sync(onTap)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: border == null ? null : Border.all(color: border!),
          ),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
