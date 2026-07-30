import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/star_rating.dart';

class QueuePanel extends ConsumerWidget {
  const QueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final theme = Theme.of(context);

    if (state.queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final groups = _groupByAlbum(state.queue);
    final currentSong = state.currentSong;

    return Column(
      children: [
        // ── Now playing album header ──
        if (currentSong != null) _NowPlayingAlbumHeader(song: currentSong),

        // ── Grouped track list ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: groups.length,
            itemBuilder: (context, groupIndex) {
              final group = groups[groupIndex];
              return _AlbumGroup(
                group: group,
                currentSong: currentSong,
                onSongTap: (song, index) {
                  final queueIndex = state.queue.indexOf(song);
                  if (queueIndex >= 0) {
                    ref.read(playerProvider.notifier).playSong(
                          song,
                          queue: state.queue,
                          index: queueIndex,
                        );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<_AlbumGroupData> _groupByAlbum(List<Song> songs) {
    final groups = <_AlbumGroupData>[];
    _AlbumGroupData? current;

    for (final song in songs) {
      final albumKey = song.albumId ?? song.albumName ?? '';
      if (current == null || current.albumKey != albumKey) {
        current = _AlbumGroupData(
          albumKey: albumKey,
          albumId: song.albumId,
          albumName: song.albumName ?? 'Unknown Album',
          artistName: song.artistName ?? 'Unknown Artist',
          coverArtId: song.coverArtId,
          year: song.year,
          songs: [],
        );
        groups.add(current);
      }
      current.songs.add(song);
    }

    return groups;
  }
}

class _AlbumGroupData {
  final String albumKey;
  final String? albumId;
  final String albumName;
  final String artistName;
  final String? coverArtId;
  final int? year;
  final List<Song> songs;

  _AlbumGroupData({
    required this.albumKey,
    this.albumId,
    required this.albumName,
    required this.artistName,
    this.coverArtId,
    this.year,
    required this.songs,
  });

  int get totalDuration => songs.fold(0, (sum, s) => sum + s.duration);
}

class _NowPlayingAlbumHeader extends ConsumerWidget {
  final Song song;
  const _NowPlayingAlbumHeader({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final albumAsync = song.albumId != null
        ? ref.watch(albumDetailProvider(song.albumId!))
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: CoverArtImage(
                key: ValueKey('queue-cover-${song.coverArtId}'),
                coverArtId: song.coverArtId,
                size: 160,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.albumName ?? 'Unknown Album',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  song.artistName ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.suffix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatInfo(song),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                albumAsync?.when(
                  data: (album) => StarRating(
                    rating: album.userRating ?? 0,
                    size: 20,
                    onRatingChanged: (newRating) async {
                      final client = ref.read(subsonicClientProvider);
                      if (client == null) return;
                      await client.setRating(album.id, newRating);
                      ref.invalidate(albumDetailProvider(album.id));
                    },
                  ),
                  loading: () => const SizedBox(height: 20),
                  error: (_, _) => const SizedBox(height: 20),
                ) ?? StarRating(rating: 0, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatInfo(Song song) {
    final parts = <String>[];
    if (song.suffix != null) parts.add(song.suffix!.toUpperCase());
    if (song.bitDepth != null && song.sampleRate != null) {
      final rateKhz = song.sampleRate! >= 1000
          ? (song.sampleRate! / 1000).toStringAsFixed(
              song.sampleRate! % 1000 == 0 ? 0 : 1)
          : song.sampleRate.toString();
      parts.add('${song.bitDepth}/$rateKhz');
    }
    if (song.bitRate != null) parts.add('${song.bitRate}kbps');
    return parts.join(' · ');
  }
}

class _AlbumGroup extends StatelessWidget {
  final _AlbumGroupData group;
  final Song? currentSong;
  final void Function(Song song, int index) onSongTap;

  const _AlbumGroup({
    required this.group,
    this.currentSong,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Album group header ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CoverArtImage(
                    coverArtId: group.coverArtId,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.albumName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      group.artistName,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDurationHMS(group.totalDuration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  if (group.year != null)
                    Text(
                      '${group.year}',
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

        // ── Tracks ──
        ...group.songs.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          final isCurrent = currentSong?.id == song.id;

          return InkWell(
            onTap: () => onSongTap(song, index),
            child: Container(
              color: isCurrent
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${song.track ?? index + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      song.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isCurrent ? FontWeight.w600 : null,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTrackDuration(song.duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDurationHMS(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '0:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTrackDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
