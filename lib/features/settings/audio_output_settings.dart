import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;
import 'package:shared_preferences/shared_preferences.dart';

/// Linux and multi-platform audio output engine backends.
enum AudioOutputEngine {
  auto('Auto', 'pipewire,pulse,alsa'),
  pipewire('PipeWire', 'pipewire'),
  pulse('PulseAudio', 'pulse'),
  alsa('ALSA', 'alsa');

  const AudioOutputEngine(this.label, this.aoValue);
  final String label;
  final String aoValue;
}

/// Output device, audio engine, sample rate, bit depth, and exclusive mode settings.
class AudioOutputSettings {
  final AudioOutputEngine engine;
  final String deviceName;
  final String deviceDescription;
  final bool exclusive;
  final String sampleRate;
  final String bitDepth;

  const AudioOutputSettings({
    this.engine = AudioOutputEngine.auto,
    this.deviceName = 'auto',
    this.deviceDescription = 'System Default',
    this.exclusive = false,
    this.sampleRate = 'Auto',
    this.bitDepth = 'Auto',
  });

  AudioOutputSettings copyWith({
    AudioOutputEngine? engine,
    String? deviceName,
    String? deviceDescription,
    bool? exclusive,
    String? sampleRate,
    String? bitDepth,
  }) => AudioOutputSettings(
    engine: engine ?? this.engine,
    deviceName: deviceName ?? this.deviceName,
    deviceDescription: deviceDescription ?? this.deviceDescription,
    exclusive: exclusive ?? this.exclusive,
    sampleRate: sampleRate ?? this.sampleRate,
    bitDepth: bitDepth ?? this.bitDepth,
  );

  Map<String, dynamic> toJson() => {
    'engine': engine.name,
    'deviceName': deviceName,
    'deviceDescription': deviceDescription,
    'exclusive': exclusive,
    'sampleRate': sampleRate,
    'bitDepth': bitDepth,
  };

  factory AudioOutputSettings.fromJson(Map<String, dynamic> json) =>
      AudioOutputSettings(
        engine: AudioOutputEngine.values.firstWhere(
          (e) => e.name == json['engine'],
          orElse: () => AudioOutputEngine.auto,
        ),
        deviceName: json['deviceName'] as String? ?? 'auto',
        deviceDescription:
            json['deviceDescription'] as String? ?? 'System Default',
        exclusive: json['exclusive'] as bool? ?? false,
        sampleRate: json['sampleRate'] as String? ?? 'Auto',
        bitDepth: json['bitDepth'] as String? ?? 'Auto',
      );
}

final audioDevicesProvider = StateProvider<List<mpv.Device>>(
  (ref) => const [mpv.Device(name: 'auto', description: 'System Default')],
);

final audioOutputSettingsProvider =
    StateNotifierProvider<AudioOutputSettingsNotifier, AudioOutputSettings>(
      (ref) => AudioOutputSettingsNotifier(),
    );

class AudioOutputSettingsNotifier extends StateNotifier<AudioOutputSettings> {
  static const storageKey = 'flax_audio_output_settings';

  AudioOutputSettingsNotifier() : super(const AudioOutputSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      state = AudioOutputSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Keep defaults on read failure
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void setEngine(AudioOutputEngine engine) {
    state = state.copyWith(engine: engine);
    _save();
  }

  void setDevice(String name, String description) {
    state = state.copyWith(deviceName: name, deviceDescription: description);
    _save();
  }

  void setExclusive(bool value) {
    state = state.copyWith(exclusive: value);
    _save();
  }

  void setSampleRate(String sampleRate) {
    state = state.copyWith(sampleRate: sampleRate);
    _save();
  }

  void setBitDepth(String bitDepth) {
    state = state.copyWith(bitDepth: bitDepth);
    _save();
  }
}
