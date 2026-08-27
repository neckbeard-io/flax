import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/lyrics_provider.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/lyrics_settings.dart';

/// The lyrics column: the sheet for the playing track, following along when
/// the server sends timings.
class LyricsPanel extends ConsumerWidget {
  const LyricsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    if (song == null) return const _LyricsMessage('Nothing playing');

    return ref
        .watch(currentLyricsProvider)
        .when(
          // Blank rather than a spinner: lyrics land in well under a second and
          // a spinner that appears and vanishes reads as a flicker.
          loading: () => const _LyricsMessage(''),
          error: (_, _) => const _LyricsMessage('Lyrics unavailable'),
          data: (lyrics) => lyrics == null
              ? const _LyricsMessage('No lyrics for this track')
              : _LyricsView(lyrics: lyrics, songId: song.id),
        );
  }
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LyricsView extends ConsumerStatefulWidget {
  const _LyricsView({required this.lyrics, required this.songId});

  final Lyrics lyrics;
  final String songId;

  @override
  ConsumerState<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<_LyricsView> {
  final _scrollController = ScrollController();
  final _lineKeys = <int, GlobalKey>{};

  /// When the user last scrolled by hand. Auto-scroll stands down for a while
  /// afterwards, so reading ahead is not undone by the next line change.
  DateTime? _scrolledByHandAt;
  static const _handsOff = Duration(seconds: 6);

  int _lastCenteredLine = -1;

  @override
  void didUpdateWidget(_LyricsView old) {
    super.didUpdateWidget(old);
    // A new track starts at the top with a clean slate.
    if (old.songId != widget.songId) {
      _lastCenteredLine = -1;
      _scrolledByHandAt = null;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Only a drag counts as the user's doing; the animation below also emits
    // scroll notifications and must not silence itself.
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _scrolledByHandAt = DateTime.now();
    }
    return false;
  }

  void _centerOn(int line) {
    if (line < 0 || line == _lastCenteredLine) return;
    final handsOff =
        _scrolledByHandAt != null &&
        DateTime.now().difference(_scrolledByHandAt!) < _handsOff;
    if (handsOff) return;

    _lastCenteredLine = line;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _lineKeys[line]?.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(lyricsSettingsProvider);
    final current = widget.lyrics.synced
        ? ref.watch(currentLyricLineProvider)
        : -1;
    _centerOn(current);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: SingleChildScrollView(
        controller: _scrollController,
        // Half a panel of padding at each end so the first and last lines can
        // still reach the middle of the view.
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        // Capped and centered rather than filling the column: with the artist
        // panel hidden the lyrics column is over 1000px wide, and text ragged
        // against its left edge with a void beside it reads as broken layout.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.lyrics.lines.length; i++)
                  _LyricLineText(
                    key: _lineKeys.putIfAbsent(i, GlobalKey.new),
                    line: widget.lyrics.lines[i],
                    active: i == current,
                    dimmed: current >= 0 && i != current,
                    onTap: widget.lyrics.lines[i].start == null
                        ? null
                        : () => ref
                              .read(playerProvider.notifier)
                              .seek(widget.lyrics.lines[i].start!),
                    theme: theme,
                    settings: settings,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line. Blank lines keep their height so verses stay apart.
class _LyricLineText extends StatelessWidget {
  const _LyricLineText({
    super.key,
    required this.line,
    required this.active,
    required this.dimmed,
    required this.theme,
    required this.settings,
    this.onTap,
  });

  final LyricLine line;
  final bool active;
  final bool dimmed;
  final ThemeData theme;
  final LyricsSettings settings;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The sung line is bigger as well as brighter. Size alone is what carries
    // at a glance from across a desk, which is the distance a lyrics panel is
    // actually read from.
    final style = theme.textTheme.titleMedium?.copyWith(
      height: 1.5,
      fontSize: active ? settings.activeFontSize : settings.fontSize,
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withValues(alpha: dimmed ? 0.45 : 0.8),
    );

    final Widget content;
    if (active && line.hasWordTimings) {
      content = _ActiveWordHighlightedLine(
        line: line,
        style: style ?? const TextStyle(),
        settings: settings,
        theme: theme,
      );
    } else {
      content = AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: style ?? const TextStyle(),
        textAlign: settings.alignment.textAlign,
        child: Text(line.text.isEmpty ? ' ' : line.text),
      );
    }

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );

    if (onTap == null) return padded;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: padded),
    );
  }
}

class _ActiveWordHighlightedLine extends ConsumerWidget {
  const _ActiveWordHighlightedLine({
    required this.line,
    required this.style,
    required this.settings,
    required this.theme,
  });

  final LyricLine line;
  final TextStyle style;
  final LyricsSettings settings;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playerProvider.select((s) => s.position));
    final activeColor = theme.colorScheme.primary;
    final unreachedColor = theme.colorScheme.primary.withValues(alpha: 0.45);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final word in line.words)
            TextSpan(
              text: word.text,
              style: TextStyle(
                color: (word.start != null && word.start! <= position)
                    ? activeColor
                    : unreachedColor,
                fontWeight: (word.start != null && word.start! <= position)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
        ],
      ),
      textAlign: settings.alignment.textAlign,
    );
  }
}
