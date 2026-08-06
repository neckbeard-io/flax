import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/services/autoeq/autoeq_provider.dart';

/// Maximum boost/cut per band, in dB (matches foobar2000's range).
const eqGainLimit = 20.0;

class EqBandState {
  final double frequency;
  final double gain;
  final String label;

  const EqBandState({
    required this.frequency,
    this.gain = 0,
    required this.label,
  });

  EqBandState copyWith({double? gain}) =>
      EqBandState(frequency: frequency, gain: gain ?? this.gain, label: label);

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'gain': gain,
        'label': label,
      };

  factory EqBandState.fromJson(Map<String, dynamic> json) => EqBandState(
        frequency: (json['frequency'] as num).toDouble(),
        gain: (json['gain'] as num?)?.toDouble() ?? 0,
        label: json['label'] as String,
      );
}

class EqState {
  final bool enabled;
  final List<EqBandState> bands;
  final double preamp;
  final String presetName;

  const EqState({
    this.enabled = false,
    this.bands = const [],
    this.preamp = 0,
    this.presetName = 'Flat',
  });

  EqState copyWith({bool? enabled, List<EqBandState>? bands, double? preamp, String? presetName}) =>
      EqState(
        enabled: enabled ?? this.enabled,
        bands: bands ?? this.bands,
        preamp: preamp ?? this.preamp,
        presetName: presetName ?? this.presetName,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'bands': bands.map((b) => b.toJson()).toList(),
        'preamp': preamp,
        'presetName': presetName,
      };

  factory EqState.fromJson(Map<String, dynamic> json) => EqState(
        enabled: json['enabled'] as bool? ?? false,
        bands: (json['bands'] as List<dynamic>?)
                ?.map((e) => EqBandState.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        preamp: (json['preamp'] as num?)?.toDouble() ?? 0,
        presetName: json['presetName'] as String? ?? 'Flat',
      );
}

/// The 18 band center frequencies, in Hz.
///
/// These are the fixed bands of ffmpeg's `superequalizer` filter, which is what
/// actually performs the filtering. foobar2000 uses 18 log-spaced bands too, so
/// its preset files map onto these one-for-one by index.
const _bandFrequencies = <double>[
  65, 92, 131, 185, 262, 370, 523, 740, 1047,
  1480, 2093, 2960, 4186, 5920, 8372, 11840, 16744, 20000,
];

const _bandLabels = <String>[
  '65', '92', '131', '185', '262', '370', '523', '740', '1k',
  '1.5k', '2.1k', '3k', '4.2k', '5.9k', '8.4k', '12k', '17k', '20k',
];

/// Stock foobar2000 equalizer presets (`.feq` files are 18 dB values).
const _presetGains = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  '1965': [-20, -16, -7, -4, -4, -4, -7, -7, 3, 3, -2, -4, 4, 1, 1, -4, -6, -12],
  'Air': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 2],
  'Brittle': [-12, -10, -9, -8, -7, -6, -5, -3, -2, -2, -2, -2, -1, 1, 4, 4, 1, 0],
  'Car Stereo': [-5, 0, 1, 0, 0, -4, -4, -5, -5, -5, -3, -2, -2, 0, 1, 0, -2, -5],
  'Classic V': [5, 2, 0, -2, -5, -6, -8, -8, -7, -7, -4, -3, -1, 1, 3, 5, 5, 4],
  'Clear': [1, 1, 0, 0, 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 1],
  'Dark': [-6, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -5, -8, -10, -12, -14, -18, -18],
  'DEATH': [20, 17, 12, 8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Drums': [2, 1, 0, 0, 0, -2, 0, -2, 0, 0, 0, 0, 2, 0, 0, 3, 0, 0],
  'Home Theater': [5, 2, 0, -2, -3, -5, -6, -6, -5, -2, -1, 0, -1, -3, 3, 4, 3, 0],
  'Loudness': [4, 4, 4, 2, -2, -2, -2, -2, -2, -2, -2, -4, -10, -7, 0, 3, 4, 4],
  'Metal': [4, 5, 5, 3, 0, -1, -2, -1, 0, 1, 1, 1, 1, 0, -1, -1, -1, -1],
  'Pop': [6, 5, 3, 0, -2, -4, -4, -6, -3, 1, 0, 0, 2, 1, 2, 4, 5, 6],
  'Premaster': [0, 1, 3, 0, -3, -3, 0, 0, 0, 2, 0, 0, 3, 0, 3, 1, 3, 2],
  'Presence': [0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 5, 4, 3, 2, 0, 0, 0, 0],
  'Punch & Sparkle': [3, 5, 3, -1, -3, -5, -5, -3, -2, 1, 1, 1, 0, 2, 1, 3, 5, 3],
  'Rock': [4, 3, 1, -1, -3, -4, -6, -6, -5, -5, -3, -2, 0, 2, 4, 5, 5, 4],
  'Rock 2': [2, 1, 0, -2, -3, -4, -5, -5, -4, -4, -2, -1, 1, 2, 3, 4, 4, 3],
  'Shimmer': [0, 0, 0, -2, -2, -7, -5, 0, 0, 0, 0, 0, 4, 1, 3, 3, 4, 0],
  'Soft Bass': [3, 5, 4, 0, -13, -7, -5, -5, -1, 2, 5, 1, -1, -1, -2, -7, -9, -14],
  'Strings': [-3, -4, -4, -5, -5, -4, -4, -3, -2, -2, -2, -2, -1, 2, 3, 0, -2, -2],
};

/// Build a band list from 18 dB gain values.
List<EqBandState> _bandsFromGains(List<double> gains) => [
      for (var i = 0; i < _bandFrequencies.length; i++)
        EqBandState(
          frequency: _bandFrequencies[i],
          gain: gains[i],
          label: _bandLabels[i],
        ),
    ];

final _defaultBands = _bandsFromGains(_presetGains['Flat']!);

final _presetNames = _presetGains.keys.toList();

final eqProvider = StateNotifierProvider<EqNotifier, EqState>((ref) {
  return EqNotifier();
});

class EqNotifier extends StateNotifier<EqState> {
  static const _storageKey = 'flax_eq_settings';

  EqNotifier() : super(EqState(bands: List.of(_defaultBands))) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final restored = EqState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // Guard against a stale/empty band list from an older schema
      if (restored.bands.length != _defaultBands.length) return;
      state = restored;
    } catch (_) {
      // Corrupt prefs — keep defaults
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore write failures
    }
  }

  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
    _save();
  }

  void setBandGain(int index, double gain) {
    final bands = List.of(state.bands);
    bands[index] =
        bands[index].copyWith(gain: gain.clamp(-eqGainLimit, eqGainLimit));
    state = state.copyWith(bands: bands, presetName: 'Custom');
    _save();
  }

  void setPreamp(double preamp) {
    state = state.copyWith(preamp: preamp.clamp(-eqGainLimit, eqGainLimit));
    _save();
  }

  void applyPreset(String name) {
    final gains = _presetGains[name];
    if (gains != null) {
      state = state.copyWith(
        bands: _bandsFromGains(gains),
        presetName: name,
        preamp: 0,
      );
      _save();
    }
  }

  /// Zero every band, leaving the preamp untouched.
  void zeroAll() {
    state = state.copyWith(
      bands: List.of(_defaultBands),
      presetName: 'Flat',
    );
    _save();
  }

  /// Slide the whole curve down so the loudest band sits at 0 dB.
  ///
  /// This preserves the shape of the response while removing the positive
  /// gain that causes clipping — the same idea as foobar2000's "Auto level".
  void autoLevel() {
    if (state.bands.isEmpty) return;
    final peak = state.bands.map((b) => b.gain).reduce(math.max);
    if (peak <= 0) return;
    final bands = [
      for (final b in state.bands)
        b.copyWith(gain: (b.gain - peak).clamp(-eqGainLimit, eqGainLimit)),
    ];
    state = state.copyWith(bands: bands, presetName: 'Custom');
    _save();
  }

  void reset() {
    state = state.copyWith(
      bands: List.of(_defaultBands),
      presetName: 'Flat',
      preamp: 0,
    );
    _save();
  }
}

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eq = ref.watch(eqProvider);

    // Preset dropdown entries, including a read-only 'Custom' marker
    // when band gains have been hand-adjusted.
    final isCustom = !_presetGains.containsKey(eq.presetName);
    final dropdownItems = [
      ..._presetNames,
      if (isCustom) eq.presetName,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
      ),
      body: Column(
        children: [
          // ── Enable + Preset + Reset ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Switch(
                  value: eq.enabled,
                  onChanged: (_) => ref.read(eqProvider.notifier).toggle(),
                ),
                const SizedBox(width: 12),
                Text(
                  eq.enabled ? 'EQ On' : 'EQ Off',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                // Preset selector
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: eq.presetName,
                      isDense: true,
                      borderRadius: BorderRadius.circular(10),
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.arrow_drop_down, size: 20),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      items: dropdownItems
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ))
                          .toList(),
                      onChanged: (name) {
                        if (name != null && _presetGains.containsKey(name)) {
                          ref.read(eqProvider.notifier).applyPreset(name);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Auto level — drops the curve so the peak sits at 0 dB
                _EqActionButton(
                  label: 'Auto level',
                  icon: Icons.vertical_align_bottom,
                  onPressed: () => ref.read(eqProvider.notifier).autoLevel(),
                  tooltip: 'Lower the whole curve so the loudest band is 0 dB',
                ),
                const SizedBox(width: 8),
                _EqActionButton(
                  label: 'Zero all',
                  icon: Icons.horizontal_rule,
                  onPressed: () => ref.read(eqProvider.notifier).zeroAll(),
                  tooltip: 'Flatten all bands',
                ),
                const SizedBox(width: 8),
                // Reset
                IconButton(
                  onPressed: () => ref.read(eqProvider.notifier).reset(),
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Reset bands and preamp',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Preamp ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'Pre',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: eq.preamp,
                    min: -eqGainLimit,
                    max: eqGainLimit,
                    divisions: (eqGainLimit * 4).round(),
                    label: '${eq.preamp.toStringAsFixed(1)} dB',
                    onChanged: (v) => ref.read(eqProvider.notifier).setPreamp(v),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${eq.preamp.toStringAsFixed(1)} dB',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Band sliders ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dB scale — aligned to the slider track, not the labels below
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('+20', style: theme.textTheme.labelSmall),
                        Text('0', style: theme.textTheme.labelSmall),
                        Text('-20', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Band sliders
                  ...List.generate(eq.bands.length, (i) {
                    final band = eq.bands[i];
                    return Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                    disabledThumbRadius: 4,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                                child: Slider(
                                  value: band.gain,
                                  min: -eqGainLimit,
                                  max: eqGainLimit,
                                  onChanged: eq.enabled
                                      ? (v) => ref
                                          .read(eqProvider.notifier)
                                          .setBandGain(i, v)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            band.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            band.gain == 0
                                ? '0'
                                : '${band.gain > 0 ? '+' : ''}'
                                    '${band.gain.round()}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: band.gain == 0
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.primary,
                              fontSize: 9,
                              fontWeight: band.gain == 0
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── AutoEQ ──
          const Divider(height: 1),
          Builder(builder: (context) {
            final autoEq = ref.watch(autoEqProvider);
            final profileName = autoEq.activeProfile?.name;
            return ListTile(
              leading: Icon(
                Icons.headphones,
                color: profileName != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('AutoEQ Headphone Correction'),
              subtitle: Text(profileName ?? 'None selected'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/autoeq'),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Small outlined button matching the preset dropdown's styling.
class _EqActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _EqActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: theme.textTheme.bodyMedium,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
