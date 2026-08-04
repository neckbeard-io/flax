import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/player/volume_control.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final progress = playerState.duration.inMilliseconds > 0
        ? playerState.position.inMilliseconds /
            playerState.duration.inMilliseconds
        : 0.0;

    return HoverSurface(
      onTap: () => context.push('/now-playing'),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  HoverArtwork(
                    onTap: () => context.push('/now-playing'),
                    borderRadius: BorderRadius.circular(6),
                    scale: 1.06,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: CoverArtImage(
                        coverArtId: song.coverArtId,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.artistName != null)
                        Row(
                          children: [
                            Flexible(
                              child: HoverLink(
                                text: song.artistName!,
                                onTap: song.artistId != null
                                    ? () => context
                                        .push('/artists/${song.artistId}')
                                    : null,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_formatLabel(song) != null) ...[
                              Text(
                                ' · ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                _formatLabel(song)!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _isHiRes(song)
                                      ? Colors.amber[700]
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: _isHiRes(song) ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () =>
                        ref.read(playerProvider.notifier).previous(),
                    iconSize: 24,
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () =>
                        ref.read(playerProvider.notifier).togglePlayPause(),
                    iconSize: 32,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () =>
                        ref.read(playerProvider.notifier).next(),
                    iconSize: 24,
                  ),
                  const SizedBox(width: 4),
                  const VolumeControl(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatLabel(Song song) {
    final parts = <String>[];
    if (song.suffix != null) parts.add(song.suffix!.toUpperCase());
    if (song.bitDepth != null && song.sampleRate != null) {
      final rateKhz = song.sampleRate! >= 1000
          ? (song.sampleRate! / 1000).toStringAsFixed(song.sampleRate! % 1000 == 0 ? 0 : 1)
          : song.sampleRate.toString();
      parts.add('${song.bitDepth}/$rateKhz');
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  bool _isHiRes(Song song) =>
      (song.bitDepth ?? 0) > 16 || (song.sampleRate ?? 0) > 48000;
}
