import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

/// Served by MainFlutterWindow.swift. macOS only — there is no Windows/Linux handler,
/// so these buttons route through window_manager on Windows and Linux.
const _channel = MethodChannel('com.flax/window');

/// Minimise the window.
Future<void> _minimize() => (Platform.isWindows || Platform.isLinux)
    ? windowManager.minimize()
    : _channel.invokeMethod('minimize');

/// Toggle maximised (Windows / Linux) or full screen (macOS).
///
/// On Windows and Linux it is maximise/restore, which is what the square glyph means
/// there, while macOS uses full screen.
Future<void> _toggleMaximize() async {
  if (Platform.isWindows || Platform.isLinux) {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    return;
  }
  await _channel.invokeMethod('toggleFullScreen');
}

Future<void> _close() => (Platform.isWindows || Platform.isLinux)
    ? windowManager.close()
    : _channel.invokeMethod('close');

/// Width the window buttons occupy in the top-right corner, plus the shell's
/// inset and offline toggle — zero off desktop, where they are not drawn.
///
/// ShellScaffold paints them in a Stack *over* the routed screen, so anything a
/// screen puts in that corner is overlapped. An AppBar with `actions:` inside
/// the shell must reserve this much trailing room, or move the action elsewhere.
double get windowButtonsReservedWidth =>
    isDesktopPlatform ? (3 * 32 + 8 + 100) : 0;

/// Height of the draggable strip along the top of the window.
///
/// Matches the region macOS gives you for free from `fullSizeContentView`, so
/// the desktop platforms behave the same: the top of the window moves it rather than
/// scrolling whatever is underneath.
const double windowDragStripHeight = 28;

/// Makes the top of the window draggable on Windows and Linux.
///
/// macOS keeps a `.titled` window whose transparent title bar already handles
/// dragging natively. Hit testing is translucent so widgets behind still get their taps.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      // Double-click on a title bar maximises, which is the desktop convention.
      onDoubleTap: _toggleMaximize,
      child: const SizedBox(height: windowDragStripHeight),
    );
  }
}

/// Marks a debug build.
///
/// Flutter's own DEBUG ribbon cannot be used: it is pinned to the top-right
/// corner, which is where the custom window buttons live, and it covered the
/// close button. Sitting this just below the buttons keeps that corner and the
/// screen's own AppBar actions clear.
///
/// It exists because a debug bundle left in `build/` is otherwise identical to
/// an installed release — same name, same icon, same window — which has already
/// cost an afternoon of hunting for changes that were never missing.
class DebugBadge extends StatelessWidget {
  const DebugBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE04040).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'DEBUG',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on desktop platforms
    if (!isDesktopPlatform) {
      return const SizedBox.shrink();
    }

    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.horizontal_rule,
          onTap: _minimize,
          tooltip: 'Minimize',
          color: color,
        ),
        _WindowButton(
          icon: Icons.crop_square,
          iconSize: 14,
          onTap: _toggleMaximize,
          tooltip: (Platform.isWindows || Platform.isLinux)
              ? 'Maximize'
              : 'Full Screen',
          color: color,
        ),
        _WindowButton(
          icon: Icons.close,
          onTap: _close,
          tooltip: 'Close',
          color: color,
          hoverColor: const Color(0xFFE04040),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    this.iconSize = 16,
    required this.onTap,
    required this.tooltip,
    required this.color,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isHover = _hovering;
    final fgColor = isHover
        ? (widget.hoverColor ?? Colors.white)
        : widget.color;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: isHover
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: fgColor),
          ),
        ),
      ),
    );
  }
}
