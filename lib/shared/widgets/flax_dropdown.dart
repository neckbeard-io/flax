import 'package:flutter/material.dart';

/// The one dropdown look in flax: a bare value plus a caret, with no focus box
/// left behind after you pick something.
///
/// Defined once so every dropdown behaves the same, and so a screen written
/// later inherits the fix rather than reintroducing the bug.
///
/// **Why this wrapper exists.** Material's [DropdownButton] builds an [InkWell]
/// with `focusColor: widget.focusColor ?? Theme.of(context).focusColor`. Picking
/// an option leaves focus on the button, so the InkWell paints that color and
/// keeps painting it — a grey slab sitting behind the value for as long as
/// nothing else takes focus. Because only one widget can hold focus, exactly one
/// dropdown per screen wears it at a time, which reads as a selection state that
/// means nothing: the highlighted dropdown is simply the one you touched last.
///
/// Flutter has no `DropdownButtonTheme`, so this cannot come from
/// `flax_theme.dart`. Setting `focusColor` on the [ThemeData] would work, but it
/// is the same value every other [InkWell] uses for its focus ring, so it would
/// strip keyboard focus from every button and list tile in the app to fix four
/// dropdowns.
///
/// Hover is deliberately left alone — that one is a real affordance, saying the
/// caret is clickable. It is only given a radius so it reads as a button rather
/// than a hard-edged block.
class FlaxDropdown<T> extends StatelessWidget {
  const FlaxDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isDense = false,
    this.isExpanded = false,
    this.icon,
    this.style,
    this.borderRadius,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isDense;
  final bool isExpanded;
  final Widget? icon;
  final TextStyle? style;

  /// Rounds the popup menu and the hover highlight. Defaults to 8, matching
  /// [flaxInputDecoration]; pass a value to line up with a specific container.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isDense: isDense,
      isExpanded: isExpanded,
      icon: icon,
      style: style,
      borderRadius: radius,
      // The whole point of this widget. Transparent rather than absent: absent
      // falls back to the theme's focus color, which is the grey slab.
      focusColor: Colors.transparent,
      // Every call site removed the underline by hand; none of them wanted it.
      underline: const SizedBox.shrink(),
    );
  }
}
