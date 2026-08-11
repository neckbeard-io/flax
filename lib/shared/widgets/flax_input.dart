import 'package:flutter/material.dart';

/// The one text-field look in flax: a filled, rounded box that brightens its
/// border when focused.
///
/// Defined once so every field matches the sidebar search box rather than each
/// screen inventing its own. Use it for any new field.
///
/// Hint text is deliberately dimmer than body text. A hint is an example of what
/// to type, not content — at full contrast it reads as a value already entered,
/// which is exactly the confusion a pre-filled "My Server" caused.
///
/// Prefer a hint alone over a label plus a hint. With both, Material shows the
/// label inside the box while it is empty and only reveals the hint once focus
/// floats the label away — so the dimmed example is never what you actually see
/// at rest, which defeats the point.
InputDecoration flaxInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool dense = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(8);

  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: dense,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: dense ? 10 : 14,
    ),
    // Roughly half the contrast of body text: legible, clearly not a value.
    hintStyle: TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    ),
    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    floatingLabelStyle: TextStyle(color: scheme.primary),
    border: border(scheme.outlineVariant, 1),
    enabledBorder: border(scheme.outlineVariant, 1),
    // The focus highlight, matching the search box.
    focusedBorder: border(scheme.primary, 1.6),
    errorBorder: border(scheme.error, 1),
    focusedErrorBorder: border(scheme.error, 1.6),
  );
}
