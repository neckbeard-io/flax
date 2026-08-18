import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/shared/widgets/art_cache.dart';

class MetadataCachingScreen extends ConsumerWidget {
  const MetadataCachingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final server = ref.watch(activeServerProvider);
    final tasks = ref.watch(taskRegistryProvider);
    final activeTask = tasks
        .where((t) => t.kind == TaskKind.metadataCrawl && t.state.isActive)
        .firstOrNull;

    if (server == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Metadata Caching')),
        body: const Center(child: Text('No server connected')),
      );
    }

    final config = server.metadataCacheConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('Metadata Caching')),
      body: ListView(
        children: [
          _SectionTitle(title: 'Offline Artwork Quality'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Select resolution tiers for caching covers and artist images offline.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            title: const Text('Album Art Quality'),
            subtitle: const Text(
              'Cover art resolution (Low: 256px, Medium: 512px, Original)',
            ),
            trailing: DropdownButton<MetadataQuality>(
              value: config.albumArtQuality,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: MetadataQuality.values
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
              onChanged: (q) {
                if (q != null) {
                  _updateConfig(
                    ref,
                    server,
                    config.copyWith(albumArtQuality: q),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Artist Art Quality'),
            subtitle: const Text('Artist photo and avatar resolution'),
            trailing: DropdownButton<MetadataQuality>(
              value: config.artistArtQuality,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: MetadataQuality.values
                  .map((q) => DropdownMenuItem(value: q, child: Text(q.label)))
                  .toList(),
              onChanged: (q) {
                if (q != null) {
                  _updateConfig(
                    ref,
                    server,
                    config.copyWith(artistArtQuality: q),
                  );
                }
              },
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Artist Information'),
          SwitchListTile(
            title: const Text('Cache Artist Info'),
            subtitle: const Text(
              'Biographies, genres, and MusicBrainz IDs (~1 MB library total)',
            ),
            value: config.cacheArtistInfo,
            onChanged: (v) {
              _updateConfig(ref, server, config.copyWith(cacheArtistInfo: v));
            },
          ),
          ListTile(
            title: const Text('Sync Threads'),
            subtitle: const Text('Parallel download workers during sync'),
            trailing: DropdownButton<int>(
              value: config.concurrency,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: [1, 2, 3, 4, 6, 8]
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        '$t ${t == 1 ? "worker" : "workers"}${t == 4 ? " (default)" : ""}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (c) {
                if (c != null) {
                  _updateConfig(ref, server, config.copyWith(concurrency: c));
                }
              },
            ),
          ),
          const Divider(),

          _SectionTitle(title: 'Synchronization'),
          if (activeTask != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            activeTask.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${activeTask.itemsDone} / ${activeTask.itemsTotal ?? "?"}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: activeTask.fraction),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatProgressLine(activeTask),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(metadataSyncServiceProvider).cancel();
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: () =>
                    _startSyncWithNetworkCheck(context, ref, server),
                icon: const Icon(Icons.sync),
                label: const Text('Sync Metadata & Art Now'),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Artwork Cache?'),
                    content: const Text(
                      'This will remove all locally cached album covers and artist images from disk.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ArtCache.instance.emptyCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Artwork cache cleared')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Artwork Cache'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _updateConfig(WidgetRef ref, Server server, MetadataCacheConfig config) {
    ref
        .read(serverListProvider.notifier)
        .updateServer(server.copyWith(metadataCacheConfig: config));
  }

  Future<void> _startSyncWithNetworkCheck(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    final syncService = ref.read(metadataSyncServiceProvider);
    final client = ref.read(subsonicClientProvider);
    final dao = ref.read(libraryDaoProvider);

    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server client not available')),
      );
      return;
    }

    final isCellular = await syncService.isCellularConnection();
    if (isCellular && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cellular Connection Detected'),
          content: const Text(
            'You are connected via mobile data. Pre-caching metadata and artwork can consume significant cellular bandwidth.\n\nDo you want to proceed with the sync?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    syncService.startSync(server: server, client: client, dao: dao);
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
