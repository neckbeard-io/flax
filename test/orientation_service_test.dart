import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/platform/orientation_service.dart';

void main() {
  group('OrientationService', () {
    testWidgets('locks orientation to portrait on mobile phone dimensions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      List<DeviceOrientation>? applied;

      await OrientationService.lockToPortrait(
        isMobileOverride: true,
        viewOverride: tester.view,
        setOrientations: (orientations) async {
          applied = orientations;
        },
      );

      expect(
        applied,
        equals([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]),
      );
    });

    testWidgets(
      'skips locking orientation on wide/automotive/tablet dimensions',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        var called = false;

        await OrientationService.lockToPortrait(
          isMobileOverride: true,
          viewOverride: tester.view,
          setOrientations: (orientations) async {
            called = true;
          },
        );

        expect(called, isFalse);
      },
    );

    test('does not lock orientation on desktop platforms', () async {
      var called = false;

      await OrientationService.lockToPortrait(
        isMobileOverride: false,
        setOrientations: (orientations) async {
          called = true;
        },
      );

      expect(called, isFalse);
    });
  });
}
