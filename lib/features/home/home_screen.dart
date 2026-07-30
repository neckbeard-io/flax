import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/flax_logo.dart';

final _recentAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getAlbumList(AlbumListType.newest, count: 20);
});

final _randomAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getAlbumList(AlbumListType.random, count: 20);
});

final _frequentAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getAlbumList(AlbumListType.frequent, count: 20);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 100, 0),
              child: Row(
                children: [
                  const FlaxLogo(size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      server?.name ?? 'Flax',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_recentAlbumsProvider);
                  ref.invalidate(_randomAlbumsProvider);
                  ref.invalidate(_frequentAlbumsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _AlbumRow(
                      title: 'Recently Added',
                      provider: _recentAlbumsProvider,
                    ),
                    _AlbumRow(
                      title: 'Random Picks',
                      provider: _randomAlbumsProvider,
                    ),
                    _AlbumRow(
                      title: 'Most Played',
                      provider: _frequentAlbumsProvider,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumRow extends ConsumerWidget {
  final String title;
  final FutureProvider<List<Album>> provider;

  const _AlbumRow({required this.title, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumsAsync = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 196,
          child: albumsAsync.when(
            data: (albums) => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return _AlbumCard(album: album);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e', style: theme.textTheme.bodySmall),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AlbumContextMenu(
        album: album,
        child: GestureDetector(
          onTap: () => context.push('/albums/${album.id}'),
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: CoverArtImage(
                      coverArtId: album.coverArtId,
                      size: 140,
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
        ),
      ),
    );
  }
}
