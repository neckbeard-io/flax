import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/services/autoeq/autoeq_provider.dart';

class EqBandState {
  final double frequency;
  final double gain;
  final double q;
  final String label;

  const EqBandState({
    required this.frequency,
    this.gain = 0,
    this.q = 1.4,
    required this.label,
  });

  EqBandState copyWith({double? gain, double? q}) =>
      EqBandState(frequency: frequency, gain: gain ?? this.gain, q: q ?? this.q, label: label);

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'gain': gain,
        'q': q,
        'label': label,
      };

  factory EqBandState.fromJson(Map<String, dynamic> json) => EqBandState(
        frequency: (json['frequency'] as num).toDouble(),
        gain: (json['gain'] as num?)?.toDouble() ?? 0,
        q: (json['q'] as num?)?.toDouble() ?? 1.4,
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

final _defaultBands = [
  const EqBandState(frequency: 60, label: '60'),
  const EqBandState(frequency: 170, label: '170'),
  const EqBandState(frequency: 310, label: '310'),
  const EqBandState(frequency: 600, label: '600'),
  const EqBandState(frequency: 1000, label: '1k'),
  const EqBandState(frequency: 3000, label: '3k'),
  const EqBandState(frequency: 6000, label: '6k'),
  const EqBandState(frequency: 12000, label: '12k'),
  const EqBandState(frequency: 14000, label: '14k'),
  const EqBandState(frequency: 16000, label: '16k'),
];

final _rockPreset = [
  const EqBandState(frequency: 60, gain: 8.0, label: '60'),
  const EqBandState(frequency: 170, gain: 4.8, label: '170'),
  const EqBandState(frequency: 310, gain: -5.6, label: '310'),
  const EqBandState(frequency: 600, gain: -8.0, label: '600'),
  const EqBandState(frequency: 1000, gain: -3.2, label: '1k'),
  const EqBandState(frequency: 3000, gain: 4.0, label: '3k'),
  const EqBandState(frequency: 6000, gain: 8.8, label: '6k'),
  const EqBandState(frequency: 12000, gain: 11.2, label: '12k'),
  const EqBandState(frequency: 14000, gain: 11.2, label: '14k'),
  const EqBandState(frequency: 16000, gain: 11.2, label: '16k'),
];

final _presets = <String, List<EqBandState>>{
  'Flat': _defaultBands,
  'Rock': _rockPreset,
};

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
    bands[index] = bands[index].copyWith(gain: gain.clamp(-12.0, 12.0));
    state = state.copyWith(bands: bands, presetName: 'Custom');
    _save();
  }

  void setPreamp(double preamp) {
    state = state.copyWith(preamp: preamp.clamp(-12.0, 12.0));
    _save();
  }

  void applyPreset(String name) {
    final preset = _presets[name];
    if (preset != null) {
      state = state.copyWith(bands: List.of(preset), presetName: name, preamp: 0);
      _save();
    }
  }

  void reset() {
    state = state.copyWith(bands: List.of(_defaultBands), presetName: 'Flat', preamp: 0);
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
    final isCustom = !_presets.containsKey(eq.presetName);
    final dropdownItems = [
      ..._presets.keys,
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
                        if (name != null && _presets.containsKey(name)) {
                          ref.read(eqProvider.notifier).applyPreset(name);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Reset
                IconButton(
                  onPressed: () => ref.read(eqProvider.notifier).reset(),
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Reset to flat',
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
                    min: -12,
                    max: 12,
                    divisions: 48,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dB labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('+12', style: theme.textTheme.labelSmall),
                      Text('0', style: theme.textTheme.labelSmall),
                      Text('-12', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(width: 4),
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
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                                ),
                                child: Slider(
                                  value: band.gain,
                                  min: -12,
                                  max: 12,
                                  onChanged: eq.enabled
                                      ? (v) => ref.read(eqProvider.notifier).setBandGain(i, v)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            band.label,
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            '${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(1)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
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
