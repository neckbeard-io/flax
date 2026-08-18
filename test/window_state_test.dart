import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:flax/services/platform/window_state.dart';

void main() {
  group('first-run size', () {
    test('a 4K display gets a large window, not the whole screen', () {
      final size = firstRunWindowSize(const Size(3840, 2160));
      expect(size.width, lessThan(3840));
      expect(size.height, lessThan(2160));
      // Wide enough for all three now-playing panels, which is the point of
      // sizing from the display at all.
      expect(size.width, greaterThanOrEqualTo(1400));
    });

    test('a laptop display gets most of itself', () {
      final size = firstRunWindowSize(const Size(1512, 982));
      expect(size.width, closeTo(1512 * 0.8, 1));
      expect(size.height, closeTo(982 * 0.8, 1));
    });

    test('a small display never yields a window bigger than it', () {
      const screen = Size(1024, 640);
      final size = firstRunWindowSize(screen);
      expect(size.width, lessThanOrEqualTo(screen.width));
      expect(size.height, lessThanOrEqualTo(screen.height));
    });

    test('the result is never below the minimum', () {
      final size = firstRunWindowSize(const Size(300, 300));
      expect(size.width, greaterThanOrEqualTo(kMinWindowSize.width));
      expect(size.height, greaterThanOrEqualTo(kMinWindowSize.height));
    });
  });

  group('restoring onto the current display', () {
    const screen = Rect.fromLTWH(0, 0, 1512, 982);

    test('a window that still fits is left exactly where it was', () {
      const saved = Rect.fromLTWH(100, 80, 1200, 800);
      expect(fitToScreen(saved, screen), saved);
    });

    test('a window saved on a monitor that is gone comes back into view', () {
      // Second display to the right, now unplugged. Restoring this verbatim
      // puts the window somewhere the user cannot see or reach.
      const saved = Rect.fromLTWH(2400, 200, 1200, 800);
      final fitted = fitToScreen(saved, screen);
      expect(screen.contains(fitted.topLeft), isTrue);
      expect(fitted.right, lessThanOrEqualTo(screen.right));
    });

    test('a window larger than the display is shrunk to fit', () {
      const saved = Rect.fromLTWH(0, 0, 3000, 2000);
      final fitted = fitToScreen(saved, screen);
      expect(fitted.width, screen.width);
      expect(fitted.height, screen.height);
    });

    test('a window off the top left is pulled back on', () {
      final fitted = fitToScreen(
        const Rect.fromLTWH(-500, -300, 900, 600),
        screen,
      );
      expect(fitted.left, greaterThanOrEqualTo(screen.left));
      expect(fitted.top, greaterThanOrEqualTo(screen.top));
    });
  });

  group('encoding', () {
    test('a rectangle survives a round trip', () {
      const bounds = Rect.fromLTWH(12, 34, 1280, 800);
      expect(decodeWindowBounds(encodeWindowBounds(bounds)), bounds);
    });

    test('junk decodes to nothing rather than throwing on launch', () {
      for (final raw in [
        null,
        '',
        'not,a,rect',
        '1,2,3',
        '1,2,3,4,5',
        '0,0,0,0',
        '0,0,-100,-100',
        '0,0,NaN,800',
      ]) {
        expect(
          decodeWindowBounds(raw),
          isNull,
          reason: 'a bad saved value must fall back to the default size',
        );
      }
    });
  });

  group('multi-monitor support', () {
    const primary = Rect.fromLTWH(0, 0, 1920, 1080);
    const secondaryRight = Rect.fromLTWH(1920, 0, 2560, 1440);
    const secondaryLeft = Rect.fromLTWH(-1920, 0, 1920, 1080);

    test('findTargetScreen picks the display the window is currently on', () {
      const savedOnSecondary = Rect.fromLTWH(2000, 100, 1200, 800);
      final target = findTargetScreen(savedOnSecondary, [
        primary,
        secondaryRight,
      ]);
      expect(target, secondaryRight);
    });

    test('findTargetScreen picks display with negative coordinate space', () {
      const savedOnLeft = Rect.fromLTWH(-1500, 100, 1200, 800);
      final target = findTargetScreen(savedOnLeft, [primary, secondaryLeft]);
      expect(target, secondaryLeft);
    });

    test('findTargetScreen picks display with largest overlap', () {
      // 900px of width on primary, 300px on secondaryRight
      const straddling = Rect.fromLTWH(1020, 100, 1200, 800);
      final target = findTargetScreen(straddling, [primary, secondaryRight]);
      expect(target, primary);
    });

    test(
      'findTargetScreen falls back to primary when second display was unplugged',
      () {
        // Saved on secondary monitor that is no longer in the screens list
        const savedOnOldSecondary = Rect.fromLTWH(2400, 200, 1200, 800);
        final target = findTargetScreen(savedOnOldSecondary, [primary]);
        expect(target, primary);
      },
    );

    test('window restores exactly onto second monitor when present', () {
      const saved = Rect.fromLTWH(2000, 100, 1200, 800);
      final target = findTargetScreen(saved, [primary, secondaryRight]);
      final fitted = fitToScreen(saved, target);
      expect(fitted, saved);
    });

    test(
      'window restores within bounds on second monitor if slightly overflowing',
      () {
        const saved = Rect.fromLTWH(4000, 100, 1200, 800);
        final target = findTargetScreen(saved, [primary, secondaryRight]);
        final fitted = fitToScreen(saved, target);
        expect(fitted.right, secondaryRight.right);
        expect(fitted.left, secondaryRight.right - 1200);
      },
    );

    test('displayBounds converts visible position and size', () {
      const display = Display(
        id: '1',
        name: 'Secondary',
        size: Size(2560, 1440),
        visiblePosition: Offset(1920, 25),
        visibleSize: Size(2560, 1415),
      );
      expect(displayBounds(display), const Rect.fromLTWH(1920, 25, 2560, 1415));
    });

    test(
      'displayBounds falls back to size when visiblePosition is missing',
      () {
        const display = Display(
          id: '2',
          name: 'Fallback',
          size: Size(1920, 1080),
        );
        expect(displayBounds(display), const Rect.fromLTWH(0, 0, 1920, 1080));
      },
    );
  });
}
