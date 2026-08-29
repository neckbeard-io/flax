import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button that always has somewhere to go.
///
/// Prefers popping, so you return to wherever you actually came from — the album
/// you opened from the Random tab goes back to that tab, not to its artist. When
/// there
/// is nothing on the stack it navigates to [fallbackLocation], the screen that
/// logically contains this one.
///
/// The alternative was hiding the button when the stack was empty, which is what
/// this replaces. That left deep links and a directly-launched screen with no
/// way out at all, and it hid the button in precisely the case worth inspecting.
class UpBackButton extends StatelessWidget {
  const UpBackButton({
    super.key,
    required this.fallbackLocation,
    this.tooltip = 'Back',
    this.icon = Icons.arrow_back,
    this.iconSize,
  });

  /// Where to go when there is no route to pop — the natural parent: an album's
  /// artist, an artist's list of artists.
  final String fallbackLocation;

  final String tooltip;
  final IconData icon;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go(fallbackLocation);
        }
      },
    );
  }
}
