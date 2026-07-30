import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/server.dart';

class TranscodingScreen extends ConsumerWidget {
  const TranscodingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final server = ref.watch(activeServerProvider);

    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transcoding')),
        body: const Center(child: Text('No server connected')),
      );
    }

    final config = server.transcodingConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('Transcoding')),
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
            subtitle: Text(config.wifiQuality.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(
              context,
              ref,
              title: 'Wi-Fi Streaming Quality',
              current: config.wifiQuality,
              options: StreamQuality.values.where((q) => q != StreamQuality.disabled).toList(),
              onSelected: (q) => _updateConfig(ref, server, config.copyWith(wifiQuality: q)),
            ),
          ),
          ListTile(
            title: const Text('Cellular Quality'),
            subtitle: Text(config.cellularQuality.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(
              context,
              ref,
              title: 'Cellular Streaming Quality',
              current: config.cellularQuality,
              options: StreamQuality.values.toList(),
              onSelected: (q) => _updateConfig(ref, server, config.copyWith(cellularQuality: q)),
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Transcode Format'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Format used when server transcodes audio. Only applies when quality is not Original.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...TranscodeFormat.values.map(
            (fmt) => RadioListTile<TranscodeFormat>(
              title: Text(fmt.name.toUpperCase()),
              value: fmt,
              groupValue: config.transcodeFormat,
              onChanged: (v) {
                if (v != null) _updateConfig(ref, server, config.copyWith(transcodeFormat: v));
              },
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Offline Downloads'),
          ListTile(
            title: const Text('Download Quality'),
            subtitle: Text(config.offlineQuality.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(
              context,
              ref,
              title: 'Offline Download Quality',
              current: config.offlineQuality,
              options: StreamQuality.values
                  .where((q) => q != StreamQuality.disabled && q != StreamQuality.kbps64)
                  .toList(),
              onSelected: (q) => _updateConfig(ref, server, config.copyWith(offlineQuality: q)),
            ),
          ),
        ],
      ),
    );
  }

  void _updateConfig(WidgetRef ref, Server server, TranscodingConfig config) {
    ref.read(serverListProvider.notifier).updateServer(
          server.copyWith(transcodingConfig: config),
        );
  }

  void _showQualityPicker(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required StreamQuality current,
    required List<StreamQuality> options,
    required ValueChanged<StreamQuality> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...options.map(
              (q) => RadioListTile<StreamQuality>(
                title: Text(q.label),
                subtitle: q == StreamQuality.disabled
                    ? const Text('No streaming on this network')
                    : null,
                value: q,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) {
                    onSelected(v);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
