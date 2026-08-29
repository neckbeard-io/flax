import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/services/cache/audio_cache_service.dart';

/// Wraps a child widget with a context menu (right-click / long-press)
/// providing song-related actions.
class SongContextMenu extends ConsumerWidget {
  final Song song;
  final List<Song> queue;
  final int index;
  final Widget child;

  const SongContextMenu({
    super.key,
    required this.song,
    this.queue = const [],
    this.index = 0,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final downloadedSongIds =
        ref.read(downloadedSongIdsProvider).valueOrNull ?? const {};
    final isCached = downloadedSongIds.contains(song.id);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'play_now',
          child: _MenuRow(icon: Icons.play_arrow, label: 'Play Now'),
        ),
        const PopupMenuItem(
          value: 'add_to_queue',
          child: _MenuRow(icon: Icons.queue_music, label: 'Add to Queue'),
        ),
        if (song.artistId != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'go_artist',
            child: _MenuRow(icon: Icons.person, label: 'Go to Artist'),
          ),
        ],
        if (song.albumId != null)
          const PopupMenuItem(
            value: 'go_album',
            child: _MenuRow(icon: Icons.album, label: 'Go to Album'),
          ),
        const PopupMenuDivider(),
        if (isCached)
          const PopupMenuItem(
            value: 'remove_cache',
            child: _MenuRow(
              icon: Icons.delete_outline,
              label: 'Remove from Cache',
            ),
          )
        else
          const PopupMenuItem(
            value: 'cache_offline',
            child: _MenuRow(
              icon: Icons.download_for_offline_outlined,
              label: 'Cache Offline',
            ),
          ),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'play_now':
        final effectiveQueue = queue.isNotEmpty ? queue : [song];
        ref
            .read(playerProvider.notifier)
            .playSong(song, queue: effectiveQueue, index: index);
        if (context.mounted &&
            ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
          context.push('/now-playing');
        }
      case 'add_to_queue':
        ref.read(playerProvider.notifier).addToQueue([song]);
      case 'go_artist':
        if (song.artistId != null) {
          context.push('/artists/${song.artistId}');
        }
      case 'go_album':
        if (song.albumId != null) {
          context.push('/albums/${song.albumId}');
        }
      case 'cache_offline':
        ref.read(audioCacheServiceProvider).cacheSong(song, isPinned: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading "${song.title}"...'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => context.push('/downloads'),
              ),
            ),
          );
        }
      case 'remove_cache':
        ref.read(audioCacheServiceProvider).removeCachedSong(song.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${song.title}" from offline cache'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    );
  }
}
