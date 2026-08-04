import 'package:flutter/material.dart';

/// Wraps artwork (album/artist covers) so it responds to the pointer.
///
/// On hover the image lifts slightly, gains a shadow and a tinted scrim, and
/// an optional play badge fades in. Falls back to a plain tap target on
/// touch-only platforms, where hover never fires.
class HoverArtwork extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  /// Show a circular play affordance over the art while hovered.
  final bool showPlayBadge;

  /// How far the artwork scales up while hovered.
  final double scale;

  const HoverArtwork({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.showPlayBadge = false,
    this.scale = 1.03,
  });

  @override
  State<HoverArtwork> createState() => _HoverArtworkState();
}

class _HoverArtworkState extends State<HoverArtwork> {
  bool _hovering = false;

  static const _duration = Duration(milliseconds: 140);
  static const _curve = Curves.easeOut;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    final active = _hovering && enabled;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: active ? widget.scale : 1.0,
          duration: _duration,
          curve: _curve,
          child: AnimatedContainer(
            duration: _duration,
            curve: _curve,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const [],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  widget.child,
                  // Brighten the art slightly so the hover reads on dark themes.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: _duration,
                        curve: _curve,
                        color: active
                            ? theme.colorScheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  if (widget.showPlayBadge)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: active ? 1 : 0,
                            duration: _duration,
                            curve: _curve,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline, clickable text link (artist names and similar) that underlines
/// and brightens under the pointer.
class HoverLink extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;

  const HoverLink({
    super.key,
    required this.text,
    this.onTap,
    this.style,
    this.textAlign,
    this.maxLines = 1,
  });

  @override
  State<HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<HoverLink> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = _hovering && enabled;
    final base = widget.style ?? DefaultTextStyle.of(context).style;

    final child = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 120),
      style: base.copyWith(
        decoration: active ? TextDecoration.underline : TextDecoration.none,
        decorationColor: base.color,
        fontWeight: active ? FontWeight.w600 : base.fontWeight,
      ),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      child: Text(widget.text),
    );

    if (!enabled) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(onTap: widget.onTap, child: child),
    );
  }
}

/// Generic hover surface for non-artwork tap targets — rows, bars and panels.
///
/// Uses a real [InkWell] so hover, focus and press states all come from the
/// theme, then adds the pointer cursor that [GestureDetector] lacks.
class HoverSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        hoverColor: Theme.of(context).colorScheme.primary.withValues(
              alpha: 0.07,
            ),
        child: child,
      ),
    );
  }
}
