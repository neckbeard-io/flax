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
          const Divider(),

          _SectionTitle(title: 'Offline Downloads'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Quality and concurrency settings for offline caching.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            title: const Text('Download Quality'),
            subtitle: const Text('Audio quality for offline tracks'),
            trailing: DropdownButton<StreamQuality>(
              value: config.offlineQuality,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: StreamQuality.values
                  .where(
                    (q) =>
                        q != StreamQuality.disabled &&
                        q != StreamQuality.kbps64,
                  )
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
              onChanged: (q) {
                if (q != null) {
                  _updateConfig(
                    ref,
                    server,
                    config.copyWith(offlineQuality: q),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Transcode & Download Threads'),
            subtitle: const Text('Parallel track conversions during sync'),
            trailing: DropdownButton<int>(
              value: config.offlineConcurrency,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: [1, 2, 3, 4, 5, 6]
                  .map(
                    (threads) => DropdownMenuItem(
                      value: threads,
                      child: Text(
                        '$threads ${threads == 1 ? "thread" : "threads"}${threads == 2 ? " (default)" : ""}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (c) {
                if (c != null) {
                  _updateConfig(
                    ref,
                    server,
                    config.copyWith(offlineConcurrency: c),
                  );
                }
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
