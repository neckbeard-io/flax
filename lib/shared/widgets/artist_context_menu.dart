import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/services/cache/audio_cache_service.dart';

/// Wraps a child widget with a context menu (right-click / long-press)
/// providing artist-related actions.
class ArtistContextMenu extends ConsumerWidget {
  final Artist artist;
  final Widget child;

  const ArtistContextMenu({
    super.key,
    required this.artist,
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
    final downloadedArtistIds =
        ref.read(downloadedArtistIdsProvider).valueOrNull ?? const {};
    final isCached = downloadedArtistIds.contains(artist.id);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'open_artist',
          child: _MenuRow(icon: Icons.person, label: 'View Artist'),
        ),
        const PopupMenuItem(
          value: 'play_now',
          child: _MenuRow(icon: Icons.play_arrow, label: 'Play Artist'),
        ),
        const PopupMenuItem(
          value: 'add_to_queue',
          child: _MenuRow(icon: Icons.queue_music, label: 'Add to Queue'),
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
      case 'open_artist':
        context.push('/artists/${artist.id}');
      case 'play_now':
        await _loadAndPlay(ref, replace: true);
        if (context.mounted &&
            ref.read(playbackSettingsProvider).autoSwitchToNowPlaying) {
          context.push('/now-playing');
        }
      case 'add_to_queue':
        await _loadAndPlay(ref, replace: false);
      case 'cache_offline':
        ref.read(audioCacheServiceProvider).cacheArtist(artist.id);
      case 'remove_cache':
        ref.read(audioCacheServiceProvider).removeCachedArtist(artist.id);
    }
  }

  Future<void> _loadAndPlay(WidgetRef ref, {required bool replace}) async {
    final repo = ref.read(libraryRepositoryProvider);
    if (repo == null) return;

    final albums = await repo.watchArtistAlbums(artist.id).first;
    final allSongs = <Song>[];
    for (final album in albums) {
      final songs = await repo.watchAlbumSongs(album.id).first;
      allSongs.addAll(songs);
    }

    if (allSongs.isEmpty) return;

    final player = ref.read(playerProvider.notifier);
    if (replace) {
      player.replaceQueue(allSongs);
    } else {
      player.addToQueue(allSongs);
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
