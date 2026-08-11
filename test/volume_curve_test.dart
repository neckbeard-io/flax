import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flax/features/player/player_provider.dart';

/// Reproduces what mpv does to the `volume` property internally, from
/// audio_get_gain() in mpv's player/audio.c:
///
///     float gain = MPMAX(opts->softvol_volume / 100.0, 0);
///     gain = pow(gain, 3);
///
/// Everything here asserts on the gain that actually reaches the output, not on
/// the number we hand mpv — the whole point of the fader curve is to cancel this
/// cubing out, so testing our side in isolation would prove nothing.
double mpvGainFor(double faderPos) {
  final volume = PlayerNotifier.faderToMpvVolume(faderPos);
  return math.pow(math.max(volume / 100.0, 0), 3).toDouble();
}

double gainToDb(double gain) => 20 * math.log(gain) / math.ln10;

void main() {
  group('square-law fader after mpv cubing', () {
    test('unity at the top of the fader', () {
      expect(PlayerNotifier.faderToMpvVolume(1.0), closeTo(100, 1e-9));
      expect(gainToDb(mpvGainFor(1.0)), closeTo(0, 1e-6));
    });

    test('half travel is a usable level, not near-silence', () {
      // The regression that prompted this curve: a 60 dB dB-linear fader put
      // half travel at -30 dB, which stacked with a low OS volume and an AutoEQ
      // preamp read as the audio cutting out entirely. Square law gives -12 dB.
      final halfDb = gainToDb(mpvGainFor(0.5));
      expect(halfDb, closeTo(-12.04, 0.01));
      expect(
        halfDb,
        greaterThan(-15),
        reason: 'half travel must stay clearly audible',
      );
    });

    test('amplitude follows pos^2', () {
      for (final pos in [0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final expectedGain = math
            .pow(pos, PlayerNotifier.kFaderAmplitudeExponent)
            .toDouble();
        expect(
          mpvGainFor(pos),
          closeTo(expectedGain, 1e-9),
          reason: 'gain at $pos should be pos^2',
        );
      }
    });

    test('reaches deep attenuation near the bottom', () {
      expect(gainToDb(mpvGainFor(0.1)), closeTo(-40, 0.01));
      expect(gainToDb(mpvGainFor(0.0316)), lessThan(-59));
    });

    test('bottom of the fader is true silence', () {
      expect(PlayerNotifier.faderToMpvVolume(0.0), 0);
      expect(mpvGainFor(0.0), 0);
    });

    test('faderToDb agrees with the gain that reaches the output', () {
      for (final pos in [0.05, 0.25, 0.5, 0.75, 1.0]) {
        expect(
          PlayerNotifier.faderToDb(pos),
          closeTo(gainToDb(mpvGainFor(pos)), 1e-6),
          reason: 'readout must match reality at $pos',
        );
      }
    });

    test('dbToFader inverts faderToDb', () {
      for (final pos in [0.05, 0.2, 0.5, 0.8, 1.0]) {
        expect(
          PlayerNotifier.dbToFader(PlayerNotifier.faderToDb(pos)),
          closeTo(pos, 1e-9),
        );
      }
    });

    test('fader is monotonic', () {
      var prev = -1.0;
      for (var i = 0; i <= 100; i++) {
        final gain = mpvGainFor(i / 100);
        expect(gain, greaterThanOrEqualTo(prev));
        prev = gain;
      }
    });

    test('out-of-range positions are clamped, not extrapolated', () {
      expect(PlayerNotifier.faderToMpvVolume(1.5), closeTo(100, 1e-9));
      expect(PlayerNotifier.faderToMpvVolume(-0.5), 0);
    });

    test('no position produces a louder-than-unity gain', () {
      for (var i = 0; i <= 100; i++) {
        expect(mpvGainFor(i / 100), lessThanOrEqualTo(1.0));
      }
    });
  });
}
