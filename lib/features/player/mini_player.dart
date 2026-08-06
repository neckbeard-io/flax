import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/player/seek_bar.dart';
import 'package:flax/features/player/volume_control.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/star_rating.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

/// Window width at which the mini player gains its seek bar, rating and
/// favorite. Matches the now-playing panel floor, so the bar fills out at the
/// same moment the screen above it does.
const double kMiniPlayerRoomyWidth = 700;

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

    // The desktop now-playing screen keeps the shell, and so keeps this bar.
    // Without the guard, clicking it there pushes /now-playing on top of
    // /now-playing, and each click costs another press of Back to undo.
    //
    // Checked when tapped, not when built. Reading the route during build left
    // the answer stale: this bar does not rebuild on navigation, so once it had
    // seen /now-playing it stayed unclickable after leaving — until some
    // unrelated player change happened to rebuild it, which made the bar look
    // like it only worked while playing.
    void openNowPlaying() {
      if (GoRouter.maybeOf(context)?.state.uri.path == '/now-playing') return;
      context.push('/now-playing');
    }

    // Wide enough for a seek bar, a rating and a favorite in the same row.
    //
    // Measured against the window rather than the platform, matching the
    // now-playing breakpoints: a tablet in landscape has as much room for
    // these as a Mac does.
    final roomy = MediaQuery.sizeOf(context).width >= kMiniPlayerRoomyWidth;

    // Only the artwork and the track's name open now playing.
    //
    // The whole bar used to be one tap target, which quietly broke the seek
    // bar the moment it was added: an ancestor InkWell competes with the
    // slider for the tap and wins, so clicking the bar navigated instead of
    // seeking. Clicking a transport control to mean "show me the now-playing
    // screen" was never the intent anyway.
    return Container(
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
          // A hairline of progress, for when there is no room for the real
          // seek bar. Alongside one it is the same fact drawn twice.
          if (!roomy)
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
                  onTap: openNowPlaying,
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
                  // Two shares to the seek bar's three: the track's name
                  // needs enough room to be read, but the empty space this
                  // used to swallow is better spent on somewhere to drag.
                  flex: 2,
                  child: HoverSurface(
                    onTap: openNowPlaying,
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
                ),
                if (roomy) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    flex: 3,
                    child: TrackSeekBar(inlineLabels: true),
                  ),
                  const SizedBox(width: 16),
                ],
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
                // Rating and favorite for the playing track. Only where
                // there is room: the phone bar is already tight, and these
                // belong on the now-playing screen there.
                if (roomy) ...[
                  const SizedBox(width: 12),
                  StarRating(
                    rating: song.userRating ?? 0,
                    size: 16,
                    onRatingChanged: (r) =>
                        ref.read(playerProvider.notifier).rateCurrentSong(r),
                  ),
                  const SizedBox(width: 4),
                  FavoriteButton(
                    isFavorite: song.starred,
                    onToggle: () => ref
                        .read(playerProvider.notifier)
                        .toggleCurrentSongStarred(),
                  ),
                ],
                const SizedBox(width: 4),
                const VolumeControl(),
              ],
            ),
          ),
        ],
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
