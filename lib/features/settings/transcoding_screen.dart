import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/shared/widgets/up_back_button.dart';

class TranscodingScreen extends ConsumerWidget {
  const TranscodingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final server = ref.watch(activeServerProvider);

    if (server == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const UpBackButton(fallbackLocation: '/settings'),
          title: const Text('Transcoding'),
        ),
        body: const Center(child: Text('No server connected')),
      );
    }

    final config = server.transcodingConfig;
    final offlineOnCellular = ref.watch(offlineOnCellularSettingProvider);
    final offlineOnAndroidAuto = ref.watch(offlineOnAndroidAutoSettingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: const Text('Transcoding'),
      ),
      body: ListView(
        children: [
          _SectionTitle(title: 'Streaming Quality'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Control audio quality per network type. Lower quality uses less data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            title: const Text('Wi-Fi Quality'),
            subtitle: const Text('Streaming quality on Wi-Fi or Ethernet'),
            trailing: DropdownButton<StreamQuality>(
              value: config.wifiQuality,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: StreamQuality.values
                  .where((q) => q != StreamQuality.disabled)
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
              onChanged: (q) {
                if (q != null) {
                  _updateConfig(ref, server, config.copyWith(wifiQuality: q));
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Cellular Quality'),
            subtitle: const Text('Streaming quality on mobile data'),
            trailing: DropdownButton<StreamQuality>(
              value: config.cellularQuality,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: StreamQuality.values
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
              onChanged: (q) {
                if (q != null) {
                  _updateConfig(
                    ref,
                    server,
                    config.copyWith(cellularQuality: q),
                  );
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Offline when not on Wi-Fi'),
            subtitle: const Text(
              'Automatically switch to offline mode when using cellular data or disconnected',
            ),
            value: offlineOnCellular,
            onChanged: (v) =>
                ref.read(offlineOnCellularSettingProvider.notifier).set(v),
          ),
          SwitchListTile(
            title: const Text('Auto-offline on Android Auto'),
            subtitle: const Text(
              'Automatically switch to offline mode and filter to downloaded music when connected to Android Auto',
            ),
            value: offlineOnAndroidAuto,
            onChanged: (v) =>
                ref.read(offlineOnAndroidAutoSettingProvider.notifier).set(v),
          ),
          const Divider(),

          _SectionTitle(title: 'Transcode Format'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Audio format used when server transcodes. Only applies when quality is not Original.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            title: const Text('Format'),
            trailing: SegmentedButton<TranscodeFormat>(
              segments: TranscodeFormat.values
                  .map(
                    (fmt) => ButtonSegment(
                      value: fmt,
                      label: Text(fmt.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              selected: {config.transcodeFormat},
              onSelectionChanged: (s) {
                _updateConfig(
                  ref,
                  server,
                  config.copyWith(transcodeFormat: s.first),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfig(WidgetRef ref, Server server, TranscodingConfig config) {
    ref
        .read(serverListProvider.notifier)
        .updateServer(server.copyWith(transcodingConfig: config));
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
