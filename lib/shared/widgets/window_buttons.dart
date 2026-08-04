import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.flax/window');

/// Width the window buttons occupy in the top-right corner, plus the shell's
/// inset — zero off desktop, where they are not drawn.
///
/// ShellScaffold paints them in a Stack *over* the routed screen, so anything a
/// screen puts in that corner is overlapped. An AppBar with `actions:` inside
/// the shell must reserve this much trailing room, or move the action elsewhere.
double get windowButtonsReservedWidth =>
    (Platform.isMacOS || Platform.isWindows) ? 3 * 32 + 8 : 0;

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
          onTap: () => _channel.invokeMethod('minimize'),
          tooltip: 'Minimize',
          color: color,
        ),
        _WindowButton(
          icon: Icons.crop_square,
          iconSize: 14,
          onTap: () => _channel.invokeMethod('toggleFullScreen'),
          tooltip: 'Full Screen',
          color: color,
        ),
        _WindowButton(
          icon: Icons.close,
          onTap: () => _channel.invokeMethod('close'),
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
