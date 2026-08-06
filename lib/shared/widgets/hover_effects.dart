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

/// Hover treatment for a single glyph-sized control — hearts, stars, and any
/// other bare icon that is a button.
///
/// An [IconButton] is the obvious choice and the wrong one at this size: its
/// ink splash is drawn inside its own bounds, so at 16-20px with zero padding
/// there is almost nothing to see, and on a dark surface the overlay is close
/// to invisible. A heart sitting in a row of text simply did not read as
/// something you could click.
///
/// So the feedback is explicit: the glyph grows, brightens toward
/// [hoverColor], and — where there is room for it — a tinted disc fades in
/// behind. Timing and scale live here rather than at each call site so every
/// icon button in the app feels the same.
class HoverIcon extends StatefulWidget {
  const HoverIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 18,
    this.hoverColor,
    this.onTap,
    this.tooltip,
    this.onHoverChanged,
    this.scale = 1.18,
    this.backdrop = true,
    this.padding = const EdgeInsets.all(6),
  });

  final IconData icon;
  final double size;
  final Color color;

  /// Colour under the pointer. Defaults to the theme's primary.
  final Color? hoverColor;

  final VoidCallback? onTap;
  final String? tooltip;

  /// Told when the pointer enters or leaves, for controls whose neighbours
  /// react too — hovering one star previews the whole rating.
  final ValueChanged<bool>? onHoverChanged;

  final double scale;

  /// Whether to fade in a disc behind the glyph. Off for tightly packed runs
  /// of icons, where five overlapping discs are noise rather than affordance.
  final bool backdrop;

  /// Kept constant between states, so growing the glyph never moves anything.
  final EdgeInsets padding;

  @override
  State<HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<HoverIcon> {
  bool _hovering = false;

  static const _duration = Duration(milliseconds: 120);
  static const _curve = Curves.easeOut;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;
    final active = _hovering && enabled;
    final hoverColor = widget.hoverColor ?? theme.colorScheme.primary;

    Widget child = AnimatedContainer(
      duration: _duration,
      curve: _curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active && widget.backdrop
            ? hoverColor.withValues(alpha: 0.16)
            : Colors.transparent,
      ),
      child: AnimatedScale(
        scale: active ? widget.scale : 1.0,
        duration: _duration,
        curve: _curve,
        child: Icon(
          widget.icon,
          size: widget.size,
          color: active ? hoverColor : widget.color,
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: child,
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      ),
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
