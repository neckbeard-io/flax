import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Served by MainFlutterWindow.swift. macOS only — there is no Windows handler,
/// so these buttons did nothing at all on Windows until they were routed
/// through window_manager below. That was survivable only because the native
/// Windows caption was still visible and provided working controls; once it is
/// hidden, these are the only controls the window has.
const _channel = MethodChannel('com.flax/window');

/// Minimise the window.
Future<void> _minimize() =>
    Platform.isWindows ? windowManager.minimize() : _channel.invokeMethod('minimize');

/// Toggle maximised (Windows) or full screen (macOS).
///
/// The two platforms mean different things by the middle button: on Windows it
/// is maximise/restore, which is what the square glyph means there, while macOS
/// uses full screen.
Future<void> _toggleMaximize() async {
  if (Platform.isWindows) {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    return;
  }
  await _channel.invokeMethod('toggleFullScreen');
}

Future<void> _close() =>
    Platform.isWindows ? windowManager.close() : _channel.invokeMethod('close');

/// Width the window buttons occupy in the top-right corner, plus the shell's
/// inset — zero off desktop, where they are not drawn.
///
/// ShellScaffold paints them in a Stack *over* the routed screen, so anything a
/// screen puts in that corner is overlapped. An AppBar with `actions:` inside
/// the shell must reserve this much trailing room, or move the action elsewhere.
double get windowButtonsReservedWidth =>
    (Platform.isMacOS || Platform.isWindows) ? 3 * 32 + 8 : 0;

/// Height of the draggable strip along the top of the window.
///
/// Matches the region macOS gives you for free from `fullSizeContentView`, so
/// the two platforms behave the same: the top of the window moves it rather than
/// scrolling whatever is underneath.
const double windowDragStripHeight = 28;

/// Makes the top of the window draggable on Windows.
///
/// Only needed there. macOS keeps a `.titled` window whose transparent title bar
/// already handles dragging natively, and on Linux/mobile there is nothing to
/// drag. Hit testing is translucent so widgets behind still get their taps — an
/// AppBar back button under this strip stays clickable, because a tap loses the
/// gesture arena to the button while a drag is claimed here.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      // Double-click on a title bar maximises, which is the Windows convention.
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
    if (!Platform.isMacOS && !Platform.isWindows) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

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
          tooltip: Platform.isWindows ? 'Maximize' : 'Full Screen',
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
    final fgColor = isHover ? (widget.hoverColor ?? Colors.white) : widget.color;

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
