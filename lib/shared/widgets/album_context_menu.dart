import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';

/// Wraps a child widget with a context menu (right-click / long-press)
/// providing album-related actions.
class AlbumContextMenu extends ConsumerWidget {
  final Album album;
  final Widget child;

  const AlbumContextMenu({super.key, required this.album, required this.child});

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

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'go_album',
          child: _MenuRow(icon: Icons.album, label: 'Go to Album'),
        ),
        if (album.artistId != null)
          const PopupMenuItem(
            value: 'go_artist',
            child: _MenuRow(icon: Icons.person, label: 'Go to Artist'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'play_now',
          child: _MenuRow(icon: Icons.play_arrow, label: 'Play Now'),
        ),
        const PopupMenuItem(
          value: 'add_to_queue',
          child: _MenuRow(icon: Icons.queue_music, label: 'Add to Queue'),
        ),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'go_album':
        context.push('/albums/${album.id}');
      case 'go_artist':
        if (album.artistId != null) {
          context.push('/artists/${album.artistId}');
        }
      case 'play_now':
        await _loadAndPlay(ref, replace: true);
      case 'add_to_queue':
        await _loadAndPlay(ref, replace: false);
    }
  }

  Future<void> _loadAndPlay(WidgetRef ref, {required bool replace}) async {
    final client = ref.read(subsonicClientProvider);
    if (client == null) return;
    final songs = await client.getAlbumSongs(album.id);
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
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    );
  }
}
