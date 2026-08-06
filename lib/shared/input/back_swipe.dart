/// Recognises the two-finger "go back" swipe every browser has on a Mac
/// trackpad.
///
/// Kept as a plain object rather than a gesture recognizer because the
/// interesting part is the arbitration, not the geometry: a horizontal
/// two-finger swipe is *also* how you scroll the album shelves on the home
/// screen, and firing both would make those shelves impossible to scroll
/// without navigating away.
class BackSwipeTracker {
  /// How far the fingers must travel before this counts as a navigation.
  ///
  /// Generous on purpose. A short horizontal nudge is usually someone drifting
  /// while scrolling vertically, and going back by accident costs the user
  /// their place.
  static const double distanceThreshold = 110;

  /// How much more horizontal than vertical the swipe has to be.
  static const double directionRatio = 2.0;

  double _dx = 0;
  double _dy = 0;
  bool _fired = false;
  bool _scrolled = false;

  void start() {
    _dx = 0;
    _dy = 0;
    _fired = false;
    _scrolled = false;
  }

  /// A scrollable consumed part of this gesture, so it was a scroll, not a
  /// navigation. Latches for the rest of the swipe: reaching the end of a
  /// shelf mid-swipe must not then throw you back a screen.
  void noteScrolled() => _scrolled = true;

  /// Feeds one update. Returns true exactly once per gesture, at the moment
  /// the swipe becomes unambiguous.
  bool update(double dx, double dy) {
    _dx += dx;
    _dy += dy;
    if (_fired || _scrolled) return false;
    if (_dx < distanceThreshold) return false;
    if (_dx.abs() < _dy.abs() * directionRatio) return false;
    _fired = true;
    return true;
  }
}
