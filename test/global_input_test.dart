import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/input/back_swipe.dart';
import 'package:flax/shared/input/global_keys.dart';

KeyEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.space,
      timeStamp: Duration.zero,
    );

KeyEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.space,
      timeStamp: Duration.zero,
    );

void main() {
  group('global keys', () {
    test('space plays and pauses', () {
      expect(
        globalKeyAction(_down(LogicalKeyboardKey.space), isEditing: false),
        GlobalKeyAction.togglePlayback,
      );
    });

    test('space in a text field is a space', () {
      expect(
        globalKeyAction(_down(LogicalKeyboardKey.space), isEditing: true),
        GlobalKeyAction.none,
      );
      expect(
        globalKeyAction(_down(LogicalKeyboardKey.slash), isEditing: true),
        GlobalKeyAction.none,
      );
    });

    test('only the press counts, not the release', () {
      // Acting on both edges would toggle playback twice per press, which
      // looks like the shortcut not working at all.
      expect(
        globalKeyAction(_up(LogicalKeyboardKey.space), isEditing: false),
        GlobalKeyAction.none,
      );
    });

    test('slash still focuses search', () {
      expect(
        globalKeyAction(_down(LogicalKeyboardKey.slash), isEditing: false),
        GlobalKeyAction.focusSearch,
      );
    });

    test('other keys are left alone', () {
      for (final key in [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowRight,
      ]) {
        expect(globalKeyAction(_down(key), isEditing: false),
            GlobalKeyAction.none);
      }
    });
  });

  group('the back swipe', () {
    late BackSwipeTracker tracker;
    setUp(() => tracker = BackSwipeTracker()..start());

    /// Feeds a swipe in steps, as a trackpad does, and returns how many times
    /// it asked to navigate.
    int swipe(double dx, double dy, {int steps = 10}) {
      var fired = 0;
      for (var i = 0; i < steps; i++) {
        if (tracker.update(dx / steps, dy / steps)) fired++;
      }
      return fired;
    }

    test('a long swipe right goes back, exactly once', () {
      expect(swipe(200, 0), 1);
    });

    test('a short nudge does not', () {
      expect(swipe(BackSwipeTracker.distanceThreshold - 10, 0), 0);
    });

    test('a swipe left does nothing', () {
      // Forward has no meaning here, and it must not read as back either.
      expect(swipe(-200, 0), 0);
    });

    test('a mostly-vertical drift does not count', () {
      // Scrolling a long list rarely travels in a straight line.
      expect(swipe(150, 400), 0);
    });

    test('a shelf that scrolled swallows the swipe', () {
      // The home screen's album shelves scroll horizontally. Without this the
      // same gesture both scrolls the shelf and leaves the screen.
      tracker.noteScrolled();
      expect(swipe(400, 0), 0);
    });

    test('reaching the end of a shelf mid-swipe still does not navigate', () {
      // The latch matters: the shelf stops emitting scroll updates once it is
      // at its end, and the rest of the same gesture would otherwise qualify.
      swipe(40, 0, steps: 2);
      tracker.noteScrolled();
      expect(swipe(400, 0), 0);
    });

    test('a new gesture starts clean', () {
      tracker.noteScrolled();
      expect(swipe(400, 0), 0);
      tracker.start();
      expect(swipe(200, 0), 1);
    });

    test('holding past the threshold does not fire again', () {
      expect(swipe(200, 0), 1);
      expect(swipe(200, 0), 0);
    });
  });

  test('mouse button 4 is the back button', () {
    // Guards the bit, which is easy to confuse with kForwardMouseButton.
    expect(kBackMouseButton & kBackMouseButton, isNonZero);
    expect(kForwardMouseButton & kBackMouseButton, 0);
  });
}
