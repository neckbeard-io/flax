import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/star_rating.dart';

final albumDetailProvider =
    FutureProvider.family<Album, String>((ref, id) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) throw Exception('No server');
  return client.getAlbum(id);
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getAlbumSongs(albumId);
});

class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumAsync = ref.watch(albumDetailProvider(albumId));
    final songsAsync = ref.watch(albumSongsProvider(albumId));

    return Scaffold(
      body: albumAsync.when(
        data: (album) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  album.name,
                  style: const TextStyle(fontSize: 16),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArtImage(
                      coverArtId: album.coverArtId,
                      size: 600,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: album.artistId != null
                                    ? () => context.push('/artists/${album.artistId}')
                                    : null,
                                child: Text(
                                  album.artistName ?? '',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: album.artistId != null
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (album.year != null) '${album.year}',
                                  '${album.songCount} tracks',
                                  _formatDuration(album.duration),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            final songs = ref.read(albumSongsProvider(albumId)).valueOrNull;
                            if (songs != null && songs.isNotEmpty) {
                              ref.read(playerProvider.notifier).playSong(
                                    songs.first,
                                    queue: songs,
                                    index: 0,
                                  );
                            }
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StarRating(
                      rating: album.userRating ?? 0,
                      size: 24,
                      onRatingChanged: (newRating) async {
                        final client = ref.read(subsonicClientProvider);
                        if (client == null) return;
                        await client.setRating(album.id, newRating);
                        ref.invalidate(albumDetailProvider(albumId));
                      },
                    ),
                  ],
                ),
              ),
            ),
            songsAsync.when(
              data: (songs) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Center(
                              child: Text(
                                '${song.track ?? index + 1}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CoverArtImage(
                                coverArtId: song.coverArtId,
                                size: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: song.artistName != null
                          ? Text(
                              song.artistName!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Text(
                        _formatDuration(song.duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        ref.read(playerProvider.notifier).playSong(
                              song,
                              queue: songs,
                              index: index,
                            );
                      },
                    );
                  },
                  childCount: songs.length,
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
