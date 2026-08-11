import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/audio/eq_filter.dart';

/// The ffmpeg filter string the equalizer is actually applied through.
///
/// This replaced superequalizer, which was the cause of the stutter between
/// gapless tracks — mpv rebuilds the filter chain at every track boundary, and
/// an FFT filter audibly refills its window each time. Getting the string wrong
/// fails silently: ffmpeg rejects the filter and the EQ just stops working, so
/// the format is pinned here.
List<double> _flat() => List<double>.filled(eqBandCount, 0);

void main() {
  test('the band table is the length everything else assumes', () {
    expect(eqBandFrequencies.length, eqBandCount);
  });

  test('bands are a half-octave apart', () {
    // The width ratio below is derived from this spacing; if the table is ever
    // re-tuned, the widths have to move with it.
    for (var i = 1; i < eqBandFrequencies.length - 1; i++) {
      final ratio = eqBandFrequencies[i] / eqBandFrequencies[i - 1];
      expect(ratio, closeTo(1.414, 0.03),
          reason: 'band $i is not a half-octave above ${i - 1}');
    }
  });

  group('anequalizerParams', () {
    test('a flat curve needs no filter at all', () {
      // The empty string is the caller's signal to leave anequalizer out of the
      // chain, so an untouched EQ costs nothing at each track boundary.
      expect(anequalizerParams(_flat()), isEmpty);
    });

    test('emits ffmpeg syntax for a moved band', () {
      final gains = _flat()..[0] = -3;
      // 65 Hz, width 0.35 * 65 = 22.75, Butterworth.
      expect(
        anequalizerParams(gains, channels: 1),
        'c0 f=65 w=22.75 g=-3 t=0',
      );
    });

    test('says everything once per channel', () {
      // anequalizer applies a band to the one channel named in it, so stereo
      // means each band twice — a correction on c0 alone would shift the image.
      final gains = _flat()..[2] = 4.5;
      expect(
        anequalizerParams(gains),
        'c0 f=131 w=45.85 g=4.5 t=0|c1 f=131 w=45.85 g=4.5 t=0',
      );
    });

    test('skips bands nobody moved', () {
      final gains = _flat()
        ..[0] = 2
        ..[17] = -2;
      final entries = anequalizerParams(gains, channels: 1).split('|');
      expect(entries, hasLength(2));
      expect(entries.first, contains('f=65'));
      expect(entries.last, contains('f=20000'));
    });

    test('a gain too small to hear is not worth a biquad', () {
      expect(anequalizerParams(_flat()..[5] = 0.01), isEmpty);
      expect(anequalizerParams(_flat()..[5] = 0.5), isNotEmpty);
    });

    test('widths track the center frequency', () {
      // A constant width in Hz would be an octave wide in the bass and a
      // hairline at the top.
      final gains = _flat()
        ..[0] = 1
        ..[16] = 1;
      final entries = anequalizerParams(gains, channels: 1).split('|');
      expect(entries[0], contains('w=22.75')); // 65 Hz
      expect(entries[1], contains('w=5860.4')); // 16744 Hz
    });

    test('extra gains beyond the band table are ignored', () {
      // Defensive: a preset from a future build with more bands should apply
      // the ones that exist rather than index off the end of the frequencies.
      final gains = List<double>.filled(eqBandCount + 4, 1);
      final entries = anequalizerParams(gains, channels: 1).split('|');
      expect(entries, hasLength(eqBandCount));
    });

    test('negative and positive gains both survive the round trip', () {
      final params = anequalizerParams(_flat()..[3] = -7.25, channels: 1);
      expect(params, contains('g=-7.25'));
    });
  });

  group('superequalizerParams', () {
    test('a flat curve needs no filter at all', () {
      expect(superequalizerParams(_flat()), isEmpty);
    });

    test('takes linear multipliers, not dB', () {
      // 1.0 is unity; +6 dB is roughly twice the amplitude. Handing it dB was
      // the kind of mistake that sounds like a broken EQ rather than an error.
      final params = superequalizerParams(_flat()..[0] = 6);
      expect(params['1b'], closeTo(1.995, 0.01));
      expect(params['2b'], closeTo(1.0, 0.001));
    });

    test('keys every band, one-indexed', () {
      final params = superequalizerParams(_flat()..[0] = 3);
      expect(params, hasLength(eqBandCount));
      expect(params.keys.first, '1b');
      expect(params.keys.last, '${eqBandCount}b');
    });

    test('clamps to the range the filter accepts', () {
      // +20 dB is the UI limit and is inside 0..20 linear; the clamp is a
      // backstop against a preset from somewhere else.
      final params = superequalizerParams(_flat()..[0] = 60);
      expect(params['1b'], 20.0);
    });

    test('a cut is a multiplier below unity', () {
      expect(superequalizerParams(_flat()..[0] = -6)['1b'],
          closeTo(0.501, 0.01));
    });
  });

  group('the engine choice', () {
    test('defaults to the one that survives a track change', () {
      expect(EqEngine.defaultEngine, EqEngine.parametric);
    });

    test('is stored by name, not by index', () {
      expect(decodeEqEngine('graphic'), EqEngine.graphic);
      expect(decodeEqEngine('parametric'), EqEngine.parametric);
    });

    test('an unrecognized name falls back rather than throwing', () {
      expect(decodeEqEngine('firequalizer'), EqEngine.defaultEngine);
    });

    test('both engines agree on when there is nothing to do', () {
      // Otherwise switching engine on a flat curve would insert a filter in one
      // case and not the other, which is a difference with no cause.
      expect(anequalizerParams(_flat()), isEmpty);
      expect(superequalizerParams(_flat()), isEmpty);
      expect(anequalizerParams(_flat()..[4] = 2), isNotEmpty);
      expect(superequalizerParams(_flat()..[4] = 2), isNotEmpty);
    });
  });
}
