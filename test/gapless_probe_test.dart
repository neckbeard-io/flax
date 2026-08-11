import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/player/gapless_probe.dart';

/// The one piece of arithmetic the probe's conclusions rest on.
///
/// Everything the probe reports about a track boundary is judged against this
/// number, so getting it wrong would mean chasing a gap that was never there —
/// or missing one that was.
void main() {
  final t0 = DateTime.utc(2026, 8, 11, 12, 0, 0);

  test('measures wall-clock silence since audio last flowed', () {
    expect(
      gapSince(t0, t0.add(const Duration(milliseconds: 340))),
      const Duration(milliseconds: 340),
    );
  });

  test('nothing having played yet is not a gap of zero', () {
    // Null, not zero: the first track of a session has no boundary before it,
    // and reporting 0ms there would read as a perfect transition.
    expect(gapSince(null, t0), isNull);
  });

  test('a clock that went backwards reads as no gap', () {
    // NTP steps and sleep/wake both do this. A negative gap would otherwise
    // print as a suspiciously good result.
    expect(
      gapSince(t0, t0.subtract(const Duration(seconds: 2))),
      Duration.zero,
    );
  });

  test('the probe is off unless it is asked for', () {
    // It raises mpv's log level to debug, which is not something to leave on
    // in every debug build.
    expect(gaplessProbeEnabled, isFalse);
  });
}
