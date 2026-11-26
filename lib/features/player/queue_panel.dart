import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/domain/models/album.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/services/transcoding/transcoding_service.dart';
import 'package:flax/shared/widgets/album_group_header.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/genre_chips.dart';
import 'package:flax/shared/widgets/song_context_menu.dart';
import 'package:flax/shared/widgets/star_rating.dart';

/// The play queue, grouped by album, that keeps the playing track in view.
///
/// When the track changes the list scrolls to it, as long as the old one was
/// on screen: scroll away to look further down and the list stays where you
/// put it, with a button to come back. Issue #211.
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  final _scroll = ScrollController();
  final _playingRowKey = GlobalKey();

  /// Which way the playing track lies when it is out of view; null in view.
  final _playingOffscreen = ValueNotifier<AxisDirection?>(null);

  /// The playing track's group as a share of the list, 0 to 1. A lazily built
  /// list has no row to scroll to until it is near, so a far reveal jumps by
  /// this first.
  double _playingFraction = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _playingOffscreen.dispose();
    super.dispose();
  }

  /// Where the playing row sits relative to the viewport: null when any of it
  /// shows, otherwise the direction to scroll to find it.
  AxisDirection? _playingRowDirection() {
    if (!_scroll.hasClients) return null;
    final pos = _scroll.position;
    final box = _playingRowKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) {
      // Not built, so well outside the cache extent: guess from its share.
      return _playingFraction * pos.maxScrollExtent < pos.pixels
          ? AxisDirection.up
          : AxisDirection.down;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final top = viewport.getOffsetToReveal(box, 0).offset - pos.pixels;
    if (top + box.size.height <= 0) return AxisDirection.up;
    if (top >= pos.viewportDimension) return AxisDirection.down;
    return null;
  }

  void _updateIndicator() {
    if (!mounted) return;
    _playingOffscreen.value = _playingRowDirection();
  }

  /// Scrolls the playing row to near the top, leaving what plays next below.
  void _reveal({bool animate = false, int attempts = 4}) {
    if (!mounted || !_scroll.hasClients) return;
    final context = _playingRowKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
      ).then((_) => _updateIndicator());
      return;
    }
    if (attempts == 0) {
      _updateIndicator();
      return;
    }
    final pos = _scroll.position;
    _scroll.jumpTo(
      (_playingFraction * pos.maxScrollExtent).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: animate, attempts: attempts - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Not the whole state: position ticks several times a second, and only the
    // summary line needs it.
    final (queue, queueIndex, currentSong) = ref.watch(
      playerProvider.select((s) => (s.queue, s.queueIndex, s.currentSong)),
    );
    final theme = Theme.of(context);

    ref.listen(playerProvider.select((s) => s.queueIndex), (previous, next) {
      // Still the old row: this runs before the rebuild moves the key.
      final wasWatching = _playingRowDirection() == null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (wasWatching) {
          _reveal(animate: true);
        } else {
          _updateIndicator();
        }
      });
    });

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'Queue is empty',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final groups = groupByAlbum(queue);
    final starts = <int>[];
    var playingGroup = 0;
    var next = 0;
    for (var g = 0; g < groups.length; g++) {
      starts.add(next);
      next += groups[g].songs.length;
      if (queueIndex >= starts[g] && queueIndex < next) playingGroup = g;
    }
    _playingFraction = groups.length > 1
        ? playingGroup / (groups.length - 1)
        : 0;

    return Column(
      children: [
        // ── Now playing album header ──
        if (currentSong != null) _NowPlayingAlbumHeader(song: currentSong),

        _QueueSummaryLine(queue: queue, queueIndex: queueIndex),

        // ── Grouped track list ──
        Expanded(
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _updateIndicator();
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _updateIndicator();
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: groups.length,
                    itemBuilder: (context, groupIndex) {
                      return _AlbumGroup(
                        group: groups[groupIndex],
                        startIndex: starts[groupIndex],
                        playingIndex: queueIndex,
                        playingRowKey: _playingRowKey,
                        onSongTap: (song, index) => ref
                            .read(playerProvider.notifier)
                            .playSong(song, queue: queue, index: index),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ValueListenableBuilder<AxisDirection?>(
                  valueListenable: _playingOffscreen,
                  builder: (context, direction, _) {
                    if (direction == null) return const SizedBox.shrink();
                    return IconButton.filledTonal(
                      key: const ValueKey('queue-show-playing'),
                      tooltip:
                          AppLocalizations.of(context)?.queueShowPlaying ??
                          'Show the playing track',
                      icon: Icon(
                        direction == AxisDirection.up
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      onPressed: () => _reveal(animate: true),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seconds from [position] in the track at [index] to the end of [queue].
int queueSecondsLeft(List<Song> queue, int index, Duration position) {
  if (index < 0 || index >= queue.length) return 0;
  final current = queue[index].duration - position.inSeconds;
  var left = current > 0 ? current : 0;
  for (var i = index + 1; i < queue.length; i++) {
    left += queue[i].duration;
  }
  return left;
}

/// "Track 5 of 42 · 2:41:07 total · 1:58:30 left" above the queue.
class _QueueSummaryLine extends ConsumerWidget {
  const _QueueSummaryLine({required this.queue, required this.queueIndex});

  final List<Song> queue;
  final int queueIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final seconds = ref.watch(
      playerProvider.select((s) => s.position.inSeconds),
    );
    final total = queue.fold<int>(0, (sum, s) => sum + s.duration);
    final playing = queueIndex >= 0 && queueIndex < queue.length;
    final totalText = formatDuration(total);

    final parts = [
      if (playing)
        l10n?.queuePosition(queueIndex + 1, queue.length) ??
            'Track ${queueIndex + 1} of ${queue.length}',
      l10n?.queueTotalTime(totalText) ?? '$totalText total',
      if (playing)
        () {
          final left = formatDuration(
            queueSecondsLeft(queue, queueIndex, Duration(seconds: seconds)),
          );
          return l10n?.queueTimeLeft(left) ?? '$left left';
        }(),
    ];

    return Container(
      key: const ValueKey('queue-summary'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NowPlayingAlbumHeader extends ConsumerWidget {
  final Song song;
  const _NowPlayingAlbumHeader({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playerState = ref.watch(playerProvider);
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
                if (song.suffix != null ||
                    playerState.playingTranscode?.isTranscoded == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatInfo(song, playerState.playingTranscode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                // The playing track's genres, read from the song in hand rather
                // than the album provider, so nothing arrives late and shoves
                // the queue down. One line: the album page lists them all.
                if (song.displayGenres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GenreChips(
                      genres: song.displayGenres,
                      singleLine: true,
                      size: GenreChipSize.dense,
                    ),
                  ),
                const SizedBox(height: 4),
                // Fixed height whether or not the album has loaded: the rating
                // row appearing later would shove the queue down by its height.
                SizedBox(
                  height: 28,
                  child:
                      albumAsync?.when(
                        data: (album) => _AlbumRatingRow(album: album),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ) ??
                      StarRating(rating: 0, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatInfo(Song song, [TranscodeParameters? transcode]) {
    final parts = <String>[];
    if (song.suffix != null) parts.add(song.suffix!.toUpperCase());
    if (song.bitDepth != null && song.sampleRate != null) {
      final rateKhz = song.sampleRate! >= 1000
          ? (song.sampleRate! / 1000).toStringAsFixed(
              song.sampleRate! % 1000 == 0 ? 0 : 1,
            )
          : song.sampleRate.toString();
      parts.add('${song.bitDepth}/$rateKhz');
    }
    if (transcode?.isTranscoded == true) {
      final source = parts.join(' ');
      final target = transcode!.shortLabel;
      return source.isNotEmpty ? '$source → $target' : target;
    }
    if (song.bitRate != null) parts.add('${song.bitRate}kbps');
    return parts.join(' · ');
  }
}

/// Rating and favorite for the album being played.
///
/// Both act on the *album*, not the track — the mini player already carries the
/// track's pair, and having two identical controls mean different things a few
/// hundred pixels apart is worse than having neither.
class _AlbumRatingRow extends ConsumerWidget {
  const _AlbumRatingRow({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This used to be a ConsumerStatefulWidget holding a `_pendingStarred` flag,
    // so the heart could fill on click instead of after a round trip, plus an
    // invalidate of the album so the change stuck. Both are gone: the repository
    // writes locally first and every view of this album watches the same row.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarRating(
          rating: album.userRating ?? 0,
          size: 20,
          onRatingChanged: (newRating) async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setRating(
                  EntityRef(EntityType.album, album.id),
                  rating: newRating,
                );
          },
        ),
        const SizedBox(width: 4),
        FavoriteButton(
          isFavorite: album.starred,
          onToggle: () async {
            await ref
                .read(libraryRepositoryProvider)
                ?.setFavorite(
                  EntityRef(EntityType.album, album.id),
                  favorite: !album.starred,
                );
          },
          tooltip: album.starred
              ? 'Remove album from favorites'
              : 'Add album to favorites',
        ),
      ],
    );
  }
}

class _AlbumGroup extends ConsumerWidget {
  final AlbumGroup group;

  /// Queue index of this group's first song.
  final int startIndex;
  final int playingIndex;
  final GlobalKey playingRowKey;

  /// Called with the song and its queue index.
  final void Function(Song song, int queueIndex) onSongTap;

  const _AlbumGroup({
    required this.group,
    required this.startIndex,
    required this.playingIndex,
    required this.playingRowKey,
    required this.onSongTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadedSongIds =
        ref.watch(downloadedSongIdsProvider).valueOrNull ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlbumGroupHeader(group: group),

        // ── Tracks ──
        ...group.songs.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          // By position, not id: a song queued twice is playing only once.
          final isCurrent = startIndex + index == playingIndex;
          final isCached = downloadedSongIds.contains(song.id);

          return SongContextMenu(
            key: isCurrent ? playingRowKey : null,
            song: song,
            queue: group.songs,
            index: index,
            child: _QueueRowHover(
              isCurrent: isCurrent,
              onTap: () => onSongTap(song, startIndex + index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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
                      child: Row(
                        children: [
                          Flexible(
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
                          if (isCached) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.offline_pin,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
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
            ),
          );
        }),
      ],
    );
  }

  String _formatTrackDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// A queue row that highlights under the pointer.
///
/// The current-track tint and the hover tint are composited into a single
/// background color, so the row background can't hide the hover feedback the
/// way an opaque child would cover an [InkWell]'s ink.
class _QueueRowHover extends StatefulWidget {
  final Widget child;
  final bool isCurrent;
  final VoidCallback onTap;

  const _QueueRowHover({
    required this.child,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_QueueRowHover> createState() => _QueueRowHoverState();
}

class _QueueRowHoverState extends State<_QueueRowHover> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color? background;
    if (widget.isCurrent) {
      background = scheme.primaryContainer.withValues(
        alpha: _hovering ? 0.45 : 0.3,
      );
    } else if (_hovering) {
      background = scheme.primary.withValues(alpha: 0.08);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          color: background ?? Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}
