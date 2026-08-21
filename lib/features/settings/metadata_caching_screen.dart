import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/cache/storage_manager.dart';
import 'package:flax/services/metadata/metadata_sync_service.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';
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
        appBar: AppBar(title: const Text('Caching')),
        body: const Center(child: Text('No server connected')),
      );
    }
    ref.listen<List<Task>>(taskRegistryProvider, (prev, next) {
      final prevActive =
          prev
              ?.where(
                (t) =>
                    (t.kind == TaskKind.metadataCrawl ||
                        t.kind == TaskKind.audioDownload) &&
                    t.state.isActive,
              )
              .isNotEmpty ??
          false;
      final nextActive = next
          .where(
            (t) =>
                (t.kind == TaskKind.metadataCrawl ||
                    t.kind == TaskKind.audioDownload) &&
                t.state.isActive,
          )
          .isNotEmpty;
      if (prevActive && !nextActive) {
        ref.invalidate(metadataCacheSummaryProvider(server.id));
        ref.invalidate(audioCacheSummaryProvider(server.id));
      }
    });

    final summaryAsync = ref.watch(metadataCacheSummaryProvider(server.id));
    final audioSummaryAsync = ref.watch(audioCacheSummaryProvider(server.id));
    final audioSummary =
        audioSummaryAsync.valueOrNull ?? const AudioCacheSummary();
    final config = server.metadataCacheConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('Caching')),
      body: ListView(
        children: [
          // ── Cache Status Overview ──
          _SectionTitle(title: 'Cache Status'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: summaryAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              error: (err, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error reading cache status: $err'),
                ),
              ),
              data: (summary) => _CacheStatusCard(
                summary: summary,
                audioSummary: audioSummary,
                config: config,
              ),
            ),
          ),
          const Divider(),

          // ── Artwork Quality Tiers ──
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

          // ── Artist Info & Concurrency ──
          _SectionTitle(title: 'Artist Information & Metadata Sync'),
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
            title: const Text('Metadata & Art Sync Workers'),
            subtitle: const Text(
              'Parallel workers during library metadata and artwork sync',
            ),
            trailing: DropdownButton<int>(
              value: config.concurrency,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(8),
              items: [1, 2, 3, 4, 6, 8, 12, 16, 24]
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

          // ── Synchronization Controls ──
          _SectionTitle(title: 'Synchronization'),
          if (activeTask != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: theme.colorScheme.surfaceContainerHighest,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${activeTask.itemsDone} / ${activeTask.itemsTotal ?? "?"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (activeTask.ratePerSecond != null &&
                                  activeTask.state == TaskState.running) ...[
                                Text(
                                  ' · ${activeTask.ratePerSecond! < 10 ? activeTask.ratePerSecond!.toStringAsFixed(1) : activeTask.ratePerSecond!.round()} items/s',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (activeTask.eta != null &&
                                  activeTask.state == TaskState.running) ...[
                                Text(
                                  ' · ${formatEta(activeTask.eta!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: activeTask.fraction),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              activeTask.note ?? 'Processing...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _startSyncWithNetworkCheck(context, ref, server),
                    icon: const Icon(Icons.sync),
                    label: Text(
                      summaryAsync.valueOrNull?.isFullyCached ?? false
                          ? 'Sync Again (Incremental)'
                          : 'Sync Metadata & Art Now',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sync is incremental: only missing or updated artwork and metadata are downloaded. Already cached items are skipped.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),

          // ── Audio Caching ──
          _SectionTitle(title: 'Audio Caching'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Configure offline downloads and automatic caching for streamed tracks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final audioConfig = ref.watch(audioCacheConfigProvider);
              final isMobile = Platform.isAndroid || Platform.isIOS;

              return Column(
                children: [
                  if (isMobile) ...[_StorageLocationTile(server: server)],
                  SwitchListTile(
                    title: const Text('Auto-Cache Streamed Music'),
                    subtitle: const Text(
                      'Automatically save streamed tracks to local cache for offline playback',
                    ),
                    value: audioConfig.autoCacheStreamed,
                    onChanged: (val) {
                      ref
                          .read(audioCacheConfigProvider.notifier)
                          .setAutoCacheStreamed(val);
                    },
                  ),
                  ListTile(
                    title: const Text('Audio Cache Size Limit'),
                    subtitle: const Text(
                      'Maximum storage space for all cached audio tracks (LRU eviction)',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          audioConfig.limitDisplayString,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                    onTap: () =>
                        _showCacheSizeDialog(context, ref, audioConfig),
                  ),
                  ListTile(
                    title: const Text('Audio Download Workers'),
                    subtitle: const Text(
                      'Parallel download workers when caching songs, albums, and artists',
                    ),
                    trailing: DropdownButton<int>(
                      value: audioConfig.downloadConcurrency,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(8),
                      items: [1, 2, 3, 4, 6, 8]
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                '$t ${t == 1 ? "worker" : "workers"}${t == 2 ? " (default)" : ""}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(audioCacheConfigProvider.notifier)
                              .setDownloadConcurrency(val);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Audio Cache?'),
                    content: const Text(
                      'This will remove all downloaded and cached audio files from disk.',
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
                  await ref.read(audioCacheServiceProvider).clearAudioCache();
                  ref.invalidate(audioCacheSummaryProvider(server.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audio cache cleared')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.music_off_outlined),
              label: const Text('Clear Audio Cache'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Metadata & Artwork Cache?'),
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
                  ref.invalidate(metadataCacheSummaryProvider(server.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Metadata & artwork cache cleared'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Metadata & Artwork Cache'),
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
    ref.invalidate(metadataCacheSummaryProvider(server.id));
  }

  Future<void> _startSyncWithNetworkCheck(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    final syncService = ref.read(metadataSyncServiceProvider);
    final client =
        ref.read(subsonicClientProvider) ?? SubsonicClient(server: server);
    final dao = ref.read(libraryDaoProvider);

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

    await syncService.startSync(server: server, client: client, dao: dao);
    ref.invalidate(metadataCacheSummaryProvider(server.id));
  }

  Future<void> _showCacheSizeDialog(
    BuildContext context,
    WidgetRef ref,
    AudioCacheConfig audioConfig,
  ) async {
    final controller = TextEditingController(
      text: audioConfig.rollingCacheLimitMb > 0
          ? '${audioConfig.rollingCacheLimitGb}'
          : '0',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Audio Cache Size Limit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the maximum storage space for cached audio tracks. When exceeded, the oldest tracks are automatically evicted (LRU).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick Presets:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetChip(label: '1 GB', gb: 1, controller: controller),
                    _PresetChip(label: '2 GB', gb: 2, controller: controller),
                    _PresetChip(label: '5 GB', gb: 5, controller: controller),
                    _PresetChip(label: '10 GB', gb: 10, controller: controller),
                    _PresetChip(label: '20 GB', gb: 20, controller: controller),
                    _PresetChip(label: '50 GB', gb: 50, controller: controller),
                    _PresetChip(
                      label: 'Unlimited',
                      gb: 0,
                      controller: controller,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Custom Limit (in GB)',
                    hintText: 'Enter GB (0 for unlimited)',
                    suffixText: 'GB',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                final parsed = double.tryParse(text);
                if (parsed != null && parsed >= 0) {
                  ref
                      .read(audioCacheConfigProvider.notifier)
                      .setRollingCacheLimitGb(parsed);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final double gb;
  final TextEditingController controller;

  const _PresetChip({
    required this.label,
    required this.gb,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        controller.text = gb == 0 ? '0' : gb.round().toString();
      },
    );
  }
}

class _StorageLocationTile extends ConsumerStatefulWidget {
  final Server server;
  const _StorageLocationTile({required this.server});

  @override
  ConsumerState<_StorageLocationTile> createState() =>
      _StorageLocationTileState();
}

class _StorageLocationTileState extends ConsumerState<_StorageLocationTile> {
  List<StorageVolume> _volumes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVolumes();
  }

  Future<void> _loadVolumes() async {
    final vols = await StorageManager.getAvailableStorageVolumes();
    if (mounted) {
      setState(() {
        _volumes = vols;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioConfig = ref.watch(audioCacheConfigProvider);

    final activeVolume =
        _volumes
            .where((v) => v.id == audioConfig.storageLocationId)
            .firstOrNull ??
        _volumes.firstOrNull;

    final volumeLabel = activeVolume?.label ?? 'Internal Storage';
    final freeSpaceStr = activeVolume != null && activeVolume.availableBytes > 0
        ? ' · ${formatBytes(activeVolume.availableBytes)} free'
        : '';

    return ListTile(
      title: const Text('Cache Storage Location'),
      subtitle: Text('$volumeLabel$freeSpaceStr'),
      trailing: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sd_card_outlined, size: 20),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
      onTap: _loading || _volumes.isEmpty
          ? null
          : () => _showLocationPicker(context, activeVolume),
    );
  }

  Future<void> _showLocationPicker(
    BuildContext context,
    StorageVolume? currentVolume,
  ) async {
    final selected = await showModalBottomSheet<StorageVolume>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Storage Location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose where to store offline downloads and audio caches.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ..._volumes.map((vol) {
                  final isSelected = vol.id == currentVolume?.id;
                  final usedFraction = vol.totalBytes > 0
                      ? ((vol.totalBytes - vol.availableBytes) / vol.totalBytes)
                            .clamp(0.0, 1.0)
                      : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: isSelected ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, vol),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  vol.isRemovable
                                      ? Icons.sd_card
                                      : Icons.phone_android,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vol.label,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        '${formatBytes(vol.availableBytes)} free of ${formatBytes(vol.totalBytes)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: usedFraction,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                usedFraction > 0.9
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected.id != currentVolume?.id && mounted) {
      await _confirmAndSwitchStorage(selected);
    }
  }

  Future<void> _confirmAndSwitchStorage(StorageVolume targetVolume) async {
    final audioService = ref.read(audioCacheServiceProvider);
    final currentBytes = await audioService.getAudioCacheBytes();

    if (currentBytes > 0 && mounted) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch Storage Location'),
          content: Text(
            'You have ${formatBytes(currentBytes)} of cached audio. Would you like to migrate your cached files to "${targetVolume.label}", or start clean?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: const Text('Start Clean'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'migrate'),
              child: const Text('Migrate Files'),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null || !mounted) return;

      final migrate = action == 'migrate';
      if (migrate) {
        _showMigrationProgressDialog(targetVolume);
      } else {
        await audioService.switchStorageLocation(
          targetVolume,
          migrateData: false,
        );
        ref.invalidate(audioCacheSummaryProvider(widget.server.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched cache storage to ${targetVolume.label}'),
            ),
          );
        }
      }
    } else {
      await audioService.switchStorageLocation(
        targetVolume,
        migrateData: false,
      );
      ref.invalidate(audioCacheSummaryProvider(widget.server.id));
    }
  }

  void _showMigrationProgressDialog(StorageVolume targetVolume) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            var fraction = 0.0;
            var statusText = 'Preparing migration...';

            ref
                .read(audioCacheServiceProvider)
                .switchStorageLocation(
                  targetVolume,
                  migrateData: true,
                  onProgress: (f, s) {
                    setDialogState(() {
                      fraction = f;
                      statusText = s;
                    });
                  },
                )
                .then((success) {
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                    ref.invalidate(audioCacheSummaryProvider(widget.server.id));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Successfully migrated cache to ${targetVolume.label}'
                                : 'Migration failed. Reverted to previous storage.',
                          ),
                        ),
                      );
                    }
                  }
                });

            return AlertDialog(
              title: const Text('Migrating Cache Files'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: fraction > 0 ? fraction : null,
                  ),
                  const SizedBox(height: 16),
                  Text(statusText),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CacheStatusCard extends StatelessWidget {
  final MetadataCacheSummary summary;
  final AudioCacheSummary audioSummary;
  final MetadataCacheConfig config;

  const _CacheStatusCard({
    required this.summary,
    required this.audioSummary,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBytes = summary.totalBytes + audioSummary.audioBytes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Cached',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatBytes(totalBytes),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (summary.lastSyncedAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Synced',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(summary.lastSyncedAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 24),
            _StatusRow(
              icon: Icons.album_outlined,
              label: 'Album Covers',
              cachedCount: summary.albumArtCached,
              totalCount: summary.albumArtTotal,
              bytes: summary.albumArtBytes,
              enabled: config.albumArtQuality != MetadataQuality.disabled,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.person_outline,
              label: 'Artist Photos',
              cachedCount: summary.artistArtCached,
              totalCount: summary.artistArtTotal,
              bytes: summary.artistArtBytes,
              enabled: config.artistArtQuality != MetadataQuality.disabled,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.description_outlined,
              label: 'Artist Biographies',
              cachedCount: summary.artistInfoCached,
              totalCount: summary.artistInfoTotal,
              bytes: summary.artistInfoBytes,
              enabled: config.cacheArtistInfo,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              icon: Icons.music_note_outlined,
              label: 'Audio Cache',
              cachedCount: audioSummary.cachedSongCount,
              bytes: audioSummary.audioBytes,
              enabled: true,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int cachedCount;
  final int? totalCount;
  final int bytes;
  final bool enabled;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.cachedCount,
    this.totalCount,
    required this.bytes,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete =
        enabled &&
        totalCount != null &&
        totalCount! > 0 &&
        cachedCount >= totalCount!;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.outline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : theme.colorScheme.outline,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              Text(
                !enabled
                    ? 'Disabled'
                    : totalCount != null
                    ? '$cachedCount of $totalCount cached (${formatBytes(bytes)})'
                    : '$cachedCount ${cachedCount == 1 ? "track" : "tracks"} cached (${formatBytes(bytes)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
