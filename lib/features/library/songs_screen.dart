import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:go_router/go_router.dart';

/// A shuffle of the library.
///
/// Like the Random album tab, the order is not persisted — it belongs to this
/// subscription, so it stays put while being browsed and reshuffles on a fresh
/// one. The rows themselves are watched, so hearting a track here updates it.
final randomSongsProvider = StreamProvider<List<Song>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchRandomSongs(count: 100);
});

class SongsScreen extends ConsumerWidget {
  const SongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final songsAsync = ref.watch(randomSongsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Songs',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(randomSongsProvider),
                    tooltip: 'Shuffle',
                  ),
                ],
              ),
            ),
            Expanded(
              child: songsAsync.when(
                data: (songs) => ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: ClipRRect(
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
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          song.artistName,
                          song.albumName,
                        ].whereType<String>().join(' — '),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatDuration(song.duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        ref
                            .read(playerProvider.notifier)
                            .playSong(song, queue: songs, index: index);
                        if (ref
                            .read(playbackSettingsProvider)
                            .autoSwitchToNowPlaying) {
                          context.push('/now-playing');
                        }
                      },
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
