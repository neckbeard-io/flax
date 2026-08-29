import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;

import 'package:flax/features/settings/audio_output_settings.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/shared/widgets/flax_dropdown.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

export 'package:flax/features/settings/audio_output_settings.dart';

final exclusiveModeProvider = Provider<bool>((ref) {
  return ref.watch(audioOutputSettingsProvider).exclusive;
});
final sampleRateProvider = Provider<String>((ref) {
  return ref.watch(audioOutputSettingsProvider).sampleRate;
});
final bitDepthProvider = Provider<String>((ref) {
  return ref.watch(audioOutputSettingsProvider).bitDepth;
});

class AudioOutputScreen extends ConsumerWidget {
  const AudioOutputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioSettings = ref.watch(audioOutputSettingsProvider);
    final audioNotifier = ref.read(audioOutputSettingsProvider.notifier);
    final devices = ref.watch(audioDevicesProvider);
    final playback = ref.watch(playbackSettingsProvider);
    final playbackNotifier = ref.read(playbackSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: const Text('Audio Output'),
      ),
      body: ListView(
        children: [
          _SectionTitle(title: 'Engine & Device'),
          if (Platform.isLinux) ...[
            ListTile(
              title: const Text('Audio Engine'),
              subtitle: const Text(
                'PipeWire is standard on Ubuntu 24.04+; Auto provides dynamic fallback',
              ),
              trailing: FlaxDropdown<AudioOutputEngine>(
                value: audioSettings.engine,
                items: AudioOutputEngine.values
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text(e.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) audioNotifier.setEngine(v);
                },
              ),
            ),
          ],
          ListTile(
            title: const Text('Output Device'),
            subtitle: Text(audioSettings.deviceDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showDevicePicker(context, ref, devices, audioSettings),
          ),
          SwitchListTile(
            title: const Text('Exclusive Mode'),
            subtitle: const Text('Lock audio device for bit-perfect output'),
            value: audioSettings.exclusive,
            onChanged: audioNotifier.setExclusive,
          ),
          const Divider(),

          _SectionTitle(title: 'Format'),
          ListTile(
            title: const Text('Sample Rate'),
            trailing: FlaxDropdown<String>(
              value: audioSettings.sampleRate,
              items: [
                'Auto',
                '44.1 kHz',
                '48 kHz',
                '88.2 kHz',
                '96 kHz',
                '192 kHz',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) audioNotifier.setSampleRate(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Bit Depth'),
            trailing: FlaxDropdown<String>(
              value: audioSettings.bitDepth,
              items: [
                'Auto',
                '16-bit',
                '24-bit',
                '32-bit float',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) audioNotifier.setBitDepth(v);
              },
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Playback'),
          ListTile(
            title: const Text('ReplayGain'),
            subtitle: const Text(
              "Levels tracks using the server's own loudness tags",
            ),
            trailing: FlaxDropdown<ReplayGainMode>(
              value: playback.replayGain,
              items: ReplayGainMode.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) playbackNotifier.setReplayGain(v);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Gapless Playback'),
            subtitle: Text(
              playback.fading
                  ? 'Off while fading between tracks'
                  : 'No silence between consecutive tracks',
            ),
            value: playback.gapless,
            onChanged: playbackNotifier.setGapless,
          ),
          ListTile(
            title: const Text('Fade Between Tracks'),
            subtitle: Text(
              playback.fading
                  ? '${playback.fadeSeconds.round()} seconds — fades out and in; '
                        'tracks do not overlap'
                  : 'Off',
            ),
            trailing: SizedBox(
              width: 120,
              child: Slider(
                value: playback.fadeSeconds,
                min: 0,
                max: maxFadeSeconds,
                divisions: maxFadeSeconds.round(),
                label: playback.fading
                    ? '${playback.fadeSeconds.round()}s'
                    : 'Off',
                onChanged: playbackNotifier.setFadeSeconds,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevicePicker(
    BuildContext context,
    WidgetRef ref,
    List<mpv.Device> devices,
    AudioOutputSettings current,
  ) {
    // Ensure System Default is always present as the first item
    final allDevices = <mpv.Device>[
      const mpv.Device(name: 'auto', description: 'System Default'),
      ...devices.where((d) => d.name != 'auto'),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Audio Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final device in allDevices)
                ListTile(
                  leading: Icon(
                    current.deviceName == device.name
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: current.deviceName == device.name
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(device.description),
                  subtitle: device.name != 'auto'
                      ? Text(
                          device.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                  selected: current.deviceName == device.name,
                  onTap: () {
                    ref
                        .read(audioOutputSettingsProvider.notifier)
                        .setDevice(device.name, device.description);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
