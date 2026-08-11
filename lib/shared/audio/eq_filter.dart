import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which ffmpeg filter the band gains are applied through.
///
/// Both engines are fed the identical curve — the 18 band gains in dB, with the
/// preamp and any AutoEQ correction already summed in — so this changes only
/// how that curve is realized, never what it is asking for. That is what makes
/// A/B-ing them meaningful: nothing above this line differs.
enum EqEngine {
  /// `anequalizer`: a cascade of biquads, one per band per channel.
  parametric('Parametric', 'IIR biquads. Survives a gapless track change.'),

  /// `superequalizer`: an 18-band FFT graphic equalizer.
  ///
  /// mpv rebuilds the filter chain at every track boundary, and this one drops
  /// its FFT window and audibly refills it each time — the stutter between
  /// gapless tracks. Kept because it is what every tuning before this was
  /// judged against, and because "different" and "worse" are not the same
  /// thing to an ear that knows the material.
  graphic('Graphic', 'FFT. Stutters at gapless track changes.');

  const EqEngine(this.label, this.description);

  final String label;
  final String description;

  static const EqEngine defaultEngine = EqEngine.parametric;
}

/// Center frequencies of the 18 EQ bands, in Hz.
///
/// Half-octave spacing: each is 2^0.5 times the one before it. The manual EQ,
/// the preset table and the AutoEQ interpolation all sample the same list, so
/// a band means the same frequency everywhere.
// Two rows of nine, so the half-octave doubling is visible down the columns —
// one frequency per line hides the pattern the spacing is the whole point of.
// The marker has to read exactly `// dart format off` with nothing after it;
// append a comment to that line and the formatter ignores it and reformats.
// dart format off
const eqBandFrequencies = <double>[
  65, 92, 131, 185, 262, 370, 523, 740, 1047,
  1480, 2093, 2960, 4186, 5920, 8372, 11840, 16744, 20000,
];
// dart format on

/// Number of bands, kept next to the frequencies so the two cannot disagree.
/// Asserted against the list in the tests rather than derived from it, because
/// `.length` is not a constant expression.
const int eqBandCount = 18;

/// Width of a band as a fraction of its center frequency.
///
/// The bands sit a half-octave apart, so a band that reaches exactly to its
/// neighbours has width f * (2^0.25 − 2^−0.25) ≈ 0.35 f — a Q of about 2.9.
/// Wider and equal-gain neighbours stack into a boost; narrower and the
/// response dips between them.
const double eqBandWidthRatio = 0.35;

/// Gains smaller than this are not worth a filter. A band nobody moved should
/// cost nothing, and dropping it shortens the chain mpv rebuilds at every
/// track boundary.
const double _audibleGainDb = 0.05;

/// Builds an `anequalizer` parameter string for [gainsDb].
///
/// Format is ffmpeg's: `c<chn> f=<hz> w=<hz> g=<dB> t=<type>`, bands separated
/// by `|`, one entry per band **per channel** — anequalizer applies a band to
/// the single channel named in it, so a stereo correction has to say everything
/// twice.
///
/// Returns the empty string when no band needs moving, which is the caller's
/// signal to leave the filter out of the chain entirely.
///
/// This replaced `superequalizer`, which was the cause of the stutter between
/// gapless tracks: mpv tears down and rebuilds the filter chain at every track
/// boundary, and superequalizer is FFT-based, so each rebuild threw away its
/// window and audibly refilled it. anequalizer is a cascade of biquads whose
/// entire state is a couple of samples, so the same rebuild costs a transient
/// rather than a frame.
String anequalizerParams(List<double> gainsDb, {int channels = 2}) {
  final entries = <String>[];
  for (var channel = 0; channel < channels; channel++) {
    for (var i = 0; i < gainsDb.length && i < eqBandCount; i++) {
      final gain = gainsDb[i];
      if (gain.abs() < _audibleGainDb) continue;
      final frequency = eqBandFrequencies[i];
      final width = frequency * eqBandWidthRatio;
      entries.add(
        'c$channel f=${_num(frequency)} w=${_num(width)} '
        'g=${_num(gain)} t=0',
      );
    }
  }
  return entries.join('|');
}

/// Trims trailing zeros so the filter string stays readable in a log without
/// changing the value ffmpeg parses.
String _num(double value) {
  final fixed = value.toStringAsFixed(2);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Builds `superequalizer` parameters for [gainsDb].
///
/// Its 18 bands are exactly [eqBandFrequencies], so band i is key `${i + 1}b`.
/// It takes **linear multipliers**, not dB — 1.0 is unity — and clamps to the
/// filter's own 0–20 range.
///
/// Returns an empty map when no band needs moving, which is the caller's signal
/// to leave the filter out of the chain.
Map<String, double> superequalizerParams(List<double> gainsDb) {
  if (!gainsDb.any((g) => g.abs() >= _audibleGainDb)) return const {};
  final params = <String, double>{};
  for (var i = 0; i < eqBandCount; i++) {
    final gain = i < gainsDb.length ? gainsDb[i] : 0.0;
    params['${i + 1}b'] = math
        .pow(10.0, gain / 20.0)
        .toDouble()
        .clamp(0.0, 20.0);
  }
  return params;
}

/// The chosen engine, remembered across launches.
///
/// Deliberately its own preference rather than a field on the EQ settings: that
/// blob holds a carefully tuned curve, and widening its schema to carry an A/B
/// switch risks the curve for the sake of the switch.
final eqEngineProvider = StateNotifierProvider<EqEngineNotifier, EqEngine>((
  ref,
) {
  return EqEngineNotifier();
});

class EqEngineNotifier extends StateNotifier<EqEngine> {
  static const storageKey = 'flax_eq_engine';

  EqEngineNotifier() : super(EqEngine.defaultEngine) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved == null) return;
      state = decodeEqEngine(saved);
    } catch (_) {
      // Unreadable prefs — keep the default.
    }
  }

  Future<void> setEngine(EqEngine engine) async {
    if (engine == state) return;
    state = engine;
    try {
      final prefs = await SharedPreferences.getInstance();
      // By name, never by index: an ordinal would silently remap the moment a
      // third engine is added or the two are reordered.
      await prefs.setString(storageKey, engine.name);
    } catch (_) {
      // Ignore write failures; the choice still applies this run.
    }
  }
}

/// Resolves a stored name back to an engine, falling back to the default for
/// anything unrecognized.
EqEngine decodeEqEngine(String name) => EqEngine.values.firstWhere(
  (e) => e.name == name,
  orElse: () => EqEngine.defaultEngine,
);
