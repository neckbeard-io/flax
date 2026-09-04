import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// Screen displaying all downloaded/cached music, active download tasks, and offline storage metrics.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeServer = ref.watch(activeServerProvider);
    final downloadedAlbumsAsync = ref.watch(downloadedAlbumsProvider);
    final downloadedSongsAsync = ref.watch(downloadedSongsProvider);
    final activeTasks = ref.watch(activeTasksProvider);
    final isOffline = ref.watch(isOfflineModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                4,
                isDesktopPlatform ? windowButtonsReservedWidth + 12 : 16,
                4,
              ),
              child: Row(
                children: [
                  const UpBackButton(fallbackLocation: '/albums'),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Downloads',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isDesktopPlatform) const OfflineModeToggle(),
                ],
              ),
            ),
            const OfflineStatusBanner(),
            if (activeServer != null)
              _StorageSummaryCard(serverId: activeServer.id),
            if (activeTasks.isNotEmpty ||
                (ref
                        .watch(activeDownloadSongsProvider)
                        .valueOrNull
                        ?.isNotEmpty ??
                    false))
              _ActiveDownloadsSection(
                tasks: activeTasks,
                activeSongs:
                    ref.watch(activeDownloadSongsProvider).valueOrNull ??
                    const [],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    text:
                        'Albums (${downloadedAlbumsAsync.valueOrNull?.length ?? 0})',
                  ),
                  Tab(
                    text:
                        'Tracks (${downloadedSongsAsync.valueOrNull?.length ?? 0})',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DownloadedAlbumsTab(
                    albumsAsync: downloadedAlbumsAsync,
                    isOffline: isOffline,
                  ),
                  _DownloadedTracksTab(
                    songsAsync: downloadedSongsAsync,
                    isOffline: isOffline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageSummaryCard extends ConsumerWidget {
  const _StorageSummaryCard({required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(audioCacheConfigProvider);
    final summaryAsync = ref.watch(audioCacheSummaryProvider(serverId));

    return summaryAsync.when(
      data: (summary) {
        final usedMb = summary.audioBytes / (1024 * 1024);
        final limitMb = config.rollingCacheLimitMb;
        final progress = limitMb > 0 ? (usedMb / limitMb).clamp(0.0, 1.0) : 0.0;
        final usedStr = usedMb > 1024
            ? '${(usedMb / 1024).toStringAsFixed(1)} GB'
            : '${usedMb.toStringAsFixed(0)} MB';

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audio Storage · $usedStr used (${config.limitDisplayString} quota)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => context.push('/settings/metadata-cache'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Manage Cache',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ActiveDownloadsSection extends ConsumerStatefulWidget {
  const _ActiveDownloadsSection({
    required this.tasks,
    required this.activeSongs,
  });

  final List<Task> tasks;
  final List<Song> activeSongs;

  @override
  ConsumerState<_ActiveDownloadsSection> createState() =>
      _ActiveDownloadsSectionState();
}

class _ActiveDownloadsSectionState
    extends ConsumerState<_ActiveDownloadsSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadTasks = widget.tasks
        .where((t) => t.kind == TaskKind.audioDownload)
        .toList();
    final tasksToDisplay = downloadTasks.isNotEmpty
        ? downloadTasks
        : widget.tasks;

    if (tasksToDisplay.isEmpty && widget.activeSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemsDone = tasksToDisplay.fold<int>(
      0,
      (sum, t) => sum + t.itemsDone,
    );
    final itemsTotal = tasksToDisplay.fold<int>(
      0,
      (sum, t) => sum + (t.itemsTotal ?? 0),
    );
    final effectiveTotal = itemsTotal > 0
        ? itemsTotal
        : widget.activeSongs.length;
    final fraction = effectiveTotal > 0
        ? (itemsDone / effectiveTotal).clamp(0.0, 1.0)
        : null;

    final totalRate = tasksToDisplay.fold<double>(
      0.0,
      (sum, t) => sum + (t.ratePerSecond ?? 0.0),
    );
    final primaryUnit =
        tasksToDisplay.firstOrNull?.kind.unit ?? ProgressUnit.bytes;
    final rateStr = totalRate > 0 ? formatRate(totalRate, primaryUnit) : null;

    final primaryTask = tasksToDisplay.firstOrNull;
    final etaStr = primaryTask?.eta != null
        ? formatEta(primaryTask!.eta!)
        : null;

    final titleLabel = tasksToDisplay.length == 1
        ? tasksToDisplay.first.label
        : (tasksToDisplay.isNotEmpty
              ? 'Downloading ${tasksToDisplay.length} batches'
              : 'Active Downloads');

    final canCancel = tasksToDisplay.any((t) => t.cancelable);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Summary ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  effectiveTotal > 0
                                      ? '$itemsDone of $effectiveTotal tracks'
                                      : '${widget.activeSongs.length} tracks queued',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (rateStr != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.speed_rounded,
                                          size: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          rateStr,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (etaStr != null)
                                  Text(
                                    'ETA: $etaStr',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (canCancel)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Cancel Downloads',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final registry = ref.read(
                              taskRegistryProvider.notifier,
                            );
                            for (final t in tasksToDisplay) {
                              if (t.cancelable) {
                                registry.cancel(t.id);
                              }
                            }
                          },
                        ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (fraction != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Individual Track Breakdown ──
          if (_isExpanded && widget.activeSongs.isNotEmpty) ...[
            const Divider(height: 1, thickness: 0.5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.activeSongs.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, thickness: 0.5, indent: 48),
                itemBuilder: (context, index) {
                  final song = widget.activeSongs[index];
                  final isDownloading =
                      song.downloadState == DownloadState.downloading;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: song.coverArtId != null
                                ? CoverArtImage(
                                    coverArtId: song.coverArtId,
                                    size: 32,
                                  )
                                : Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                song.artistName ?? song.albumName ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isDownloading)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (rateStr != null) ...[
                                Text(
                                  rateStr,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Queued',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadedAlbumsTab extends StatelessWidget {
  const _DownloadedAlbumsTab({
    required this.albumsAsync,
    required this.isOffline,
  });

  final AsyncValue<List<Album>> albumsAsync;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return albumsAsync.when(
      data: (albums) => albums.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.offline_pin_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No downloaded albums',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the download icon on any album sleeve to cache it for offline playback.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : AlbumGrid(albums: albums),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DownloadedTracksTab extends ConsumerWidget {
  const _DownloadedTracksTab({
    required this.songsAsync,
    required this.isOffline,
  });

  final AsyncValue<List<Song>> songsAsync;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return songsAsync.when(
      data: (songs) => songs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No downloaded tracks',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tracks you stream or download will be available offline.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongContextMenu(
                  song: song,
                  index: index,
                  queue: songs,
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CoverArtImage(
                          coverArtId: song.coverArtId,
                          size: 42,
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${song.artistName ?? ""} · ${song.albumName ?? ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(song.duration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Remove from cache',
                          onPressed: () {
                            ref
                                .read(audioCacheServiceProvider)
                                .removeCachedSong(song.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .playSong(song, queue: songs, index: index);
                    },
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, "0")}';
  }
}
