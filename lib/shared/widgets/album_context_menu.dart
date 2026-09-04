import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/services/cache/audio_cache_service.dart';

/// Wraps a child widget with a context menu (right-click / long-press)
/// providing album-related actions.
class AlbumContextMenu extends ConsumerWidget {
  final Album album;
  final Widget child;

  const AlbumContextMenu({super.key, required this.album, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(downloadedAlbumIdsProvider);
    ref.watch(anyDownloadedAlbumIdsProvider);

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showMenu(context, ref, details.globalPosition),
      onLongPressStart: (details) =>
          _showMenu(context, ref, details.globalPosition),
      child: child,
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final downloadedAlbumIds =
        ref.read(downloadedAlbumIdsProvider).valueOrNull ?? const {};
    final anyDownloadedAlbumIds =
        ref.read(anyDownloadedAlbumIdsProvider).valueOrNull ?? const {};
    final isFullyCached = downloadedAlbumIds.contains(album.id);
    final hasCachedTracks = anyDownloadedAlbumIds.contains(album.id);
    final isPartiallyCached = hasCachedTracks && !isFullyCached;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (album.artistId != null) ...[
          const PopupMenuItem(
            value: 'go_artist',
            child: _MenuRow(icon: Icons.person, label: 'Go to Artist'),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'play_now',
          child: _MenuRow(icon: Icons.play_arrow, label: 'Play Now'),
        ),
        const PopupMenuItem(
          value: 'add_to_queue',
          child: _MenuRow(icon: Icons.queue_music, label: 'Add to Queue'),
        ),
        const PopupMenuDivider(),
        if (isFullyCached) ...[
          const PopupMenuItem(
            value: 'remove_cache',
            child: _MenuRow(
              icon: Icons.delete_outline,
              label: 'Remove from Cache',
            ),
          ),
        ] else if (isPartiallyCached) ...[
          const PopupMenuItem(
            value: 'cache_offline',
            child: _MenuRow(
              icon: Icons.download_for_offline_outlined,
              label: 'Complete Caching',
            ),
          ),
          const PopupMenuItem(
            value: 'remove_cache',
            child: _MenuRow(
              icon: Icons.delete_outline,
              label: 'Remove from Cache',
            ),
          ),
        ] else ...[
          const PopupMenuItem(
            value: 'cache_offline',
            child: _MenuRow(
              icon: Icons.download_for_offline_outlined,
              label: 'Cache Offline',
            ),
          ),
        ],
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'go_artist':
        if (album.artistId != null) {
          context.push('/artists/${album.artistId}');
        }
      case 'play_now':
        await _loadAndPlay(ref, replace: true);
        if (context.mounted &&
            ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
          context.push('/now-playing');
        }
      case 'add_to_queue':
        await _loadAndPlay(ref, replace: false);
      case 'cache_offline':
        ref.read(audioCacheServiceProvider).cacheAlbum(album.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Caching "${album.name}"...'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => context.push('/downloads'),
              ),
            ),
          );
        }
      case 'remove_cache':
        ref.read(audioCacheServiceProvider).removeCachedAlbum(album.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${album.name}" from offline cache'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
    }
  }

  Future<void> _loadAndPlay(WidgetRef ref, {required bool replace}) async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;
    // Cached tracks first, so queuing an album you have already opened works
    // with no network. Only fetch when there is nothing to queue.
    var songs = await repo.watchAlbumSongs(album.id).first;
    if (songs.isEmpty) {
      await repo.refreshAlbum(album.id);
      songs = await repo.watchAlbumSongs(album.id).first;
    }
    if (songs.isEmpty) return;
    final player = ref.read(playerProvider.notifier);
    if (replace) {
      player.replaceQueue(songs);
    } else {
      player.addToQueue(songs);
    }
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
