import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/scrobble_settings.dart';

/// When a track counts as played, and whether plays are reported at all.
///
/// The threshold is the whole of the client's job here: `scrobble` with
/// `submission=true` records the play the moment the server sees it, so
/// submitting at track start would count every skip as a listen.
void main() {
  group('scrobbleThreshold', () {
    test('half of a short track', () {
      expect(
        scrobbleThreshold(const Duration(minutes: 3)),
        const Duration(seconds: 90),
      );
    });

    test('four minutes into a long one', () {
      // Half of a 20-minute track would be ten minutes, well past the point
      // anyone would call it listened to.
      expect(
        scrobbleThreshold(const Duration(minutes: 20)),
        const Duration(minutes: 4),
      );
    });

    test('the cap takes over at eight minutes', () {
      expect(
        scrobbleThreshold(const Duration(minutes: 8)),
        const Duration(minutes: 4),
      );
      expect(
        scrobbleThreshold(const Duration(minutes: 7, seconds: 58)),
        const Duration(minutes: 3, seconds: 59),
      );
    });

    test('very short tracks never count', () {
      expect(scrobbleThreshold(const Duration(seconds: 29)), isNull);
      expect(
        scrobbleThreshold(const Duration(seconds: 30)),
        const Duration(seconds: 15),
      );
    });

    test('an unknown duration submits nothing', () {
      // mpv reports the real duration a moment after the stream opens. Until
      // some length is known, a threshold of zero would fire immediately and
      // scrobble every track the instant it started.
      expect(scrobbleThreshold(Duration.zero), isNull);
      expect(scrobbleThreshold(const Duration(seconds: -5)), isNull);
    });
  });

  group('the setting', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('reports plays unless told otherwise', () {
      // Off by default would mean the server's history silently stops the
      // moment someone starts using flax, which is the bug this fixes.
      expect(ScrobbleEnabledNotifier.defaultEnabled, isTrue);
      expect(ScrobbleEnabledNotifier().state, isTrue);
    });

    test('remembers being turned off', () async {
      final notifier = ScrobbleEnabledNotifier();
      await notifier.setEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ScrobbleEnabledNotifier.storageKey), isFalse);
    });

    test('reads the saved choice back', () async {
      SharedPreferences.setMockInitialValues({
        ScrobbleEnabledNotifier.storageKey: false,
      });

      final notifier = ScrobbleEnabledNotifier();
      // The load is async, so the first frame shows the default.
      expect(notifier.state, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state, isFalse);
    });
  });
}
