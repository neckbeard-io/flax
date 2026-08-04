import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/player/queue_panel.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    if (song == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 28,
                  ),
                ),
              ),
              const Expanded(child: Center(child: Text('Nothing playing'))),
            ],
          ),
        ),
      );
    }

    final progress = state.duration.inMilliseconds > 0
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 28,
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        _showQueue ? 'Queue' : 'Now Playing',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        song.albumName ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showQueue ? Icons.music_note : Icons.queue_music,
                      color: _showQueue ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => setState(() => _showQueue = !_showQueue),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: _showQueue
                  ? const QueuePanel()
                  : _buildPlayerView(context, theme, state, song, progress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerView(
    BuildContext context,
    ThemeData theme,
    PlayerState state,
    Song song,
    double progress,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxArtSize = (constraints.maxWidth - 80).clamp(0.0, 360.0);
        final availableHeight = constraints.maxHeight;
        final artSize = maxArtSize.clamp(0.0, (availableHeight - 290).clamp(120.0, 360.0));

        return Column(
          children: [

                const Spacer(flex: 1),

                // ── Album art ──
                SizedBox(
                  width: artSize,
                  height: artSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CoverArtImage(
                      key: ValueKey('cover-${song.coverArtId}'),
                      coverArtId: song.coverArtId,
                      size: 600,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // ── Song info ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      HoverLink(
                        text: song.artistName ?? '',
                        onTap: song.artistId != null
                            ? () {
                                Navigator.of(context).pop();
                                context.push('/artists/${song.artistId}');
                              }
                            : null,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: song.artistId != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Audio format info ──
                if (song.suffix != null || song.bitRate != null)
                  _AudioFormatBadge(song: song),

                const SizedBox(height: 8),

                // ── Progress bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            final pos = Duration(
                              milliseconds:
                                  (v * state.duration.inMilliseconds).toInt(),
                            );
                            ref.read(playerProvider.notifier).seek(pos);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(state.position),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _formatDuration(state.duration),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Transport controls ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: state.shuffle
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).toggleShuffle(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        iconSize: 36,
                        onPressed: () =>
                            ref.read(playerProvider.notifier).previous(),
                      ),
                      FilledButton(
                        onPressed: () =>
                            ref.read(playerProvider.notifier).togglePlayPause(),
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Icon(
                          state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        iconSize: 36,
                        onPressed: () =>
                            ref.read(playerProvider.notifier).next(),
                      ),
                      IconButton(
                        icon: Icon(
                          state.repeatMode == RepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: state.repeatMode != RepeatMode.off
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).cycleRepeatMode(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _AudioFormatBadge extends StatelessWidget {
  final Song song;

  const _AudioFormatBadge({required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];

    // Format name (e.g. FLAC, MP3, AAC)
    if (song.suffix != null) {
      parts.add(song.suffix!.toUpperCase());
    }

    // Bit depth / sample rate (e.g. 24/96)
    if (song.bitDepth != null && song.sampleRate != null) {
      final rateKhz = song.sampleRate! >= 1000
          ? (song.sampleRate! / 1000).toStringAsFixed(song.sampleRate! % 1000 == 0 ? 0 : 1)
          : song.sampleRate.toString();
      parts.add('${song.bitDepth}/$rateKhz');
    } else if (song.sampleRate != null) {
      final rateKhz = song.sampleRate! >= 1000
          ? '${(song.sampleRate! / 1000).toStringAsFixed(song.sampleRate! % 1000 == 0 ? 0 : 1)}kHz'
          : '${song.sampleRate}Hz';
      parts.add(rateKhz);
    }

    // Bitrate (e.g. 1268kbps)
    if (song.bitRate != null) {
      parts.add('${song.bitRate}kbps');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    final isHiRes = (song.bitDepth ?? 0) > 16 || (song.sampleRate ?? 0) > 48000;
    final isLossless = const ['flac', 'alac', 'wav', 'aiff', 'dsf', 'dff']
        .contains(song.suffix?.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHiRes
            ? Colors.amber.withValues(alpha: 0.15)
            : isLossless
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHiRes
              ? Colors.amber.withValues(alpha: 0.4)
              : isLossless
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHiRes) ...[
            Icon(Icons.stars_rounded, size: 14, color: Colors.amber[700]),
            const SizedBox(width: 4),
          ],
          Text(
            parts.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isHiRes
                  ? Colors.amber[800]
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isHiRes ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
