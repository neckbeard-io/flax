import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/services/platform/orientation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrientationService', () {
    test('locks orientation to portrait when on mobile', () async {
      List<DeviceOrientation>? applied;

      await OrientationService.lockToPortrait(
        isMobileOverride: true,
        setOrientations: (orientations) async {
          applied = orientations;
        },
      );

      expect(
        applied,
        equals([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]),
      );
    });

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
