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
    this.visualDensity,
  });

  /// Where to go when there is no route to pop — the natural parent: an album's
  /// artist, an artist's list of artists.
  final String fallbackLocation;

  final String tooltip;
  final IconData icon;
  final double? iconSize;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      visualDensity: visualDensity,
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

/// A desktop page's [UpBackButton], in a bar of its own above [child], the
/// page's scroll view.
///
/// AppChrome draws the Offline toggle and window buttons over the top of every
/// route. A page that scrolled its back button away with everything else slid
/// its content up under them: track lengths, ratings and hearts sat beneath
/// the window buttons. Here the scroll view starts below the bar, which is
/// taller than the controls, so nothing scrolls into that band.
///
/// A compact button level with the window controls, in a bar barely taller
/// than they are, so it costs as little height as it can.
///
/// The top 28pt is the window's drag strip on Windows and Linux. Taps still
/// reach the button there, a moment later while a double-click is ruled out,
/// as with Now Playing's back button.
class PinnedBackBar extends StatelessWidget {
  /// Clears the window controls, which end about 32pt down.
  static const double pinnedBackBarHeight = 40;

  const PinnedBackBar({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: pinnedBackBarHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: UpBackButton(
                fallbackLocation: fallbackLocation,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
