import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/features/player/player_provider.dart';

/// m:ss, the only time format a track needs.
String formatTrackTime(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Draggable position control for the playing track.
///
/// One implementation for both places that need it: the phone now-playing
/// screen, and the mini player — which on desktop *is* the transport, so
/// without this there was no way to seek at all at panel widths.
class TrackSeekBar extends ConsumerWidget {
  const TrackSeekBar({super.key, this.inlineLabels = false});

  /// Times either side of the slider rather than beneath it. The mini player
  /// is one row tall and has no room for a second line.
  final bool inlineLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

    // mpv reports no duration until the track is open, but the queue knows it
    // already — otherwise the bar is dead for the first moment of every track.
    final duration = state.duration.inMilliseconds > 0
        ? state.duration
        : Duration(seconds: state.currentSong?.duration ?? 0);

    return SeekBarView(
      position: state.position,
      duration: duration,
      inlineLabels: inlineLabels,
      onSeek: (to) => ref.read(playerProvider.notifier).seek(to),
    );
  }
}

/// The seek bar without a player behind it.
///
/// Split out so the part that is easy to get wrong — what the thumb does while
/// a drag is in progress — can be tested without standing up mpv or a server.
class SeekBarView extends StatefulWidget {
  const SeekBarView({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.inlineLabels = false,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool inlineLabels;

  @override
  State<SeekBarView> createState() => _SeekBarViewState();
}

class _SeekBarViewState extends State<SeekBarView> {
  /// Where the thumb is while it is being dragged, as a fraction.
  ///
  /// The position stream keeps arriving mid-drag, and following it would pull
  /// the thumb back out from under the pointer several times a second.
  double? _dragging;

  @override
  void didUpdateWidget(SeekBarView old) {
    super.didUpdateWidget(old);
    // A new track mid-drag is not a thing to keep dragging.
    if (old.duration != widget.duration) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = widget.duration.inMilliseconds;

    final position = _dragging != null
        ? Duration(milliseconds: (_dragging! * totalMs).round())
        : widget.position;
    final value = totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    final slider = SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: value,
        // Only the local thumb moves during the drag. Seeking on every frame
        // of it — which the now-playing screen used to do — asks mpv to
        // re-buffer dozens of times for one gesture.
        onChanged: totalMs == 0 ? null : (v) => setState(() => _dragging = v),
        onChangeEnd: (v) {
          setState(() => _dragging = null);
          widget.onSeek(Duration(milliseconds: (v * totalMs).round()));
        },
      ),
    );

    final elapsed = _TimeLabel(text: formatTrackTime(position), theme: theme);
    final total = _TimeLabel(
      text: formatTrackTime(widget.duration),
      theme: theme,
      alignEnd: true,
    );

    if (widget.inlineLabels) {
      return Row(
        children: [elapsed, Expanded(child: slider), total],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [elapsed, total],
          ),
        ),
      ],
    );
  }
}

/// Fixed width, so the slider does not shrink by a few pixels every time the
/// clock rolls from 9:59 to 10:00.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.text,
    required this.theme,
    this.alignEnd = false,
  });

  final String text;
  final ThemeData theme;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
