import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getAlbumList(AlbumListType.alphabeticalByName, count: 500);
});

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumsAsync = ref.watch(albumsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Albums',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: albumsAsync.when(
        data: (albums) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: artGridExtent(context),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumContextMenu(
              album: album,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HoverArtwork(
                      onTap: () => context.push('/albums/${album.id}'),
                      showPlayBadge: true,
                      // No explicit size: CoverArtImage measures its own box
                      // and fetches to match, so a wider desktop tile pulls a
                      // correspondingly larger image.
                      child: CoverArtImage(coverArtId: album.coverArtId),
                    ),
                  ),
                  const SizedBox(height: 6),
                  HoverLink(
                    text: album.name,
                    onTap: () => context.push('/albums/${album.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  HoverLink(
                    text: album.artistName ?? '',
                    onTap: album.artistId != null
                        ? () => context.push('/artists/${album.artistId}')
                        : null,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
