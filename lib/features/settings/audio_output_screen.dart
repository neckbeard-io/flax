import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/features/settings/playback_settings.dart';

final exclusiveModeProvider = StateProvider<bool>((ref) => false);
final sampleRateProvider = StateProvider<String>((ref) => 'Auto');
final bitDepthProvider = StateProvider<String>((ref) => 'Auto');

class AudioOutputScreen extends ConsumerWidget {
  const AudioOutputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exclusive = ref.watch(exclusiveModeProvider);
    final sampleRate = ref.watch(sampleRateProvider);
    final bitDepth = ref.watch(bitDepthProvider);
    final playback = ref.watch(playbackSettingsProvider);
    final playbackNotifier = ref.read(playbackSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Output')),
      body: ListView(
        children: [
          _SectionTitle(title: 'Output Device'),
          ListTile(
            title: const Text('Output Device'),
            subtitle: const Text('System Default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: enumerate devices from mpv_audio_kit
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Device selection requires mpv_audio_kit integration',
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Exclusive Mode'),
            subtitle: const Text('Lock audio device for bit-perfect output'),
            value: exclusive,
            onChanged: (v) =>
                ref.read(exclusiveModeProvider.notifier).state = v,
          ),
          const Divider(),

          _SectionTitle(title: 'Format'),
          ListTile(
            title: const Text('Sample Rate'),
            trailing: DropdownButton<String>(
              value: sampleRate,
              underline: const SizedBox.shrink(),
              items: [
                'Auto',
                '44.1 kHz',
                '48 kHz',
                '88.2 kHz',
                '96 kHz',
                '192 kHz',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) ref.read(sampleRateProvider.notifier).state = v;
              },
            ),
          ),
          ListTile(
            title: const Text('Bit Depth'),
            trailing: DropdownButton<String>(
              value: bitDepth,
              underline: const SizedBox.shrink(),
              items: [
                'Auto',
                '16-bit',
                '24-bit',
                '32-bit float',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) ref.read(bitDepthProvider.notifier).state = v;
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
            trailing: DropdownButton<ReplayGainMode>(
              value: playback.replayGain,
              underline: const SizedBox.shrink(),
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
            // Says so out loud rather than silently ignoring the switch: the
            // two cannot both apply, and a toggle that is on while doing
            // nothing is worse than one that explains itself.
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
            // Not called a crossfade, because it is not one: mpv decodes one
            // track at a time, so the tail and the head cannot overlap.
            subtitle: Text(
              playback.fading
                  ? '${playback.fadeSeconds.round()} seconds — fades out and in; '
                        'tracks do not overlap'
                  : 'Off',
            ),
            trailing: SizedBox(
              width: 200,
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
