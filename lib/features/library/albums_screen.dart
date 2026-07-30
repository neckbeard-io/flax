import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

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
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumContextMenu(
              album: album,
              child: GestureDetector(
                onTap: () => context.push('/albums/${album.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CoverArtImage(
                          coverArtId: album.coverArtId,
                          size: 180,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      album.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      album.artistName ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
