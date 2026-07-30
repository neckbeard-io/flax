import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gaplessProvider = StateProvider<bool>((ref) => true);
final exclusiveModeProvider = StateProvider<bool>((ref) => false);
final crossfadeProvider = StateProvider<double>((ref) => 0);
final sampleRateProvider = StateProvider<String>((ref) => 'Auto');
final bitDepthProvider = StateProvider<String>((ref) => 'Auto');
final replayGainProvider = StateProvider<String>((ref) => 'Off');

class AudioOutputScreen extends ConsumerWidget {
  const AudioOutputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gapless = ref.watch(gaplessProvider);
    final exclusive = ref.watch(exclusiveModeProvider);
    final crossfade = ref.watch(crossfadeProvider);
    final sampleRate = ref.watch(sampleRateProvider);
    final bitDepth = ref.watch(bitDepthProvider);
    final replayGain = ref.watch(replayGainProvider);

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
                const SnackBar(content: Text('Device selection requires mpv_audio_kit integration')),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Exclusive Mode'),
            subtitle: const Text('Lock audio device for bit-perfect output'),
            value: exclusive,
            onChanged: (v) => ref.read(exclusiveModeProvider.notifier).state = v,
          ),
          const Divider(),

          _SectionTitle(title: 'Format'),
          ListTile(
            title: const Text('Sample Rate'),
            trailing: DropdownButton<String>(
              value: sampleRate,
              underline: const SizedBox.shrink(),
              items: ['Auto', '44.1 kHz', '48 kHz', '88.2 kHz', '96 kHz', '192 kHz']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
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
              items: ['Auto', '16-bit', '24-bit', '32-bit float']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) ref.read(bitDepthProvider.notifier).state = v;
              },
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Playback'),
          ListTile(
            title: const Text('ReplayGain'),
            trailing: DropdownButton<String>(
              value: replayGain,
              underline: const SizedBox.shrink(),
              items: ['Off', 'Track', 'Album']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) ref.read(replayGainProvider.notifier).state = v;
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Gapless Playback'),
            value: gapless,
            onChanged: (v) => ref.read(gaplessProvider.notifier).state = v,
          ),
          ListTile(
            title: const Text('Crossfade'),
            subtitle: Text(crossfade == 0 ? 'Off' : '${crossfade.round()} seconds'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: crossfade,
                min: 0,
                max: 12,
                divisions: 12,
                label: crossfade == 0 ? 'Off' : '${crossfade.round()}s',
                onChanged: (v) => ref.read(crossfadeProvider.notifier).state = v,
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
