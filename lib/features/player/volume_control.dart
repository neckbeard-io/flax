import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/features/player/player_provider.dart';

/// Volume fader for the player chrome: a mute-toggling speaker icon plus a
/// slider, with scroll-wheel support.
///
/// The fader is linear in decibels rather than in amplitude — see the volume
/// section of [PlayerNotifier] for why. That means the readout is a dB
/// attenuation, and keyboard/scroll adjustment steps in dB too, so a step feels
/// the same size wherever you are on the fader.
class VolumeControl extends ConsumerStatefulWidget {
  const VolumeControl({super.key, this.width = 96, this.showLabel = false});

  /// Width of the slider track.
  final double width;

  /// Whether to show the numeric dB readout beside the slider. The mini player
  /// is tight on space, so it opts out and relies on the tooltip.
  final bool showLabel;

  @override
  ConsumerState<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends ConsumerState<VolumeControl> {
  /// One scroll notch. 2 dB is fine enough to land on a comfortable level but
  /// coarse enough that a flick of a trackpad still traverses a useful range.
  static const _scrollStepDb = 2.0;

  /// Trackpad scrolling delivers many small deltas; accumulate them so a slow
  /// two-finger drag doesn't quantise to nothing.
  double _scrollAccum = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);

    final effectivelySilent = state.muted || state.volume <= 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_iconFor(state.volume, state.muted)),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: state.muted ? 'Unmute' : 'Mute',
          onPressed: notifier.toggleMute,
        ),
        Listener(
          onPointerSignal: (signal) {
            if (signal is! PointerScrollEvent) return;
            // Scrolling up (negative dy) should raise the level.
            _scrollAccum += -signal.scrollDelta.dy;
            final steps = (_scrollAccum / 4).truncate();
            if (steps == 0) return;
            _scrollAccum -= steps * 4;
            notifier.adjustVolumeDb(steps * _scrollStepDb);
          },
          child: SizedBox(
            width: widget.width,
            child: Tooltip(
              message: _tooltipFor(state),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  // Dim the whole control while muted so it reads as inactive
                  // without losing the remembered fader position.
                  activeTrackColor: effectivelySilent
                      ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        )
                      : null,
                ),
                child: Slider(
                  value: state.volume,
                  // A fader is continuous; discrete divisions would reintroduce
                  // exactly the coarse stepping this is meant to fix.
                  onChanged: notifier.setVolume,
                ),
              ),
            ),
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 4),
          // Fixed width so the row doesn't reflow as digits change.
          SizedBox(
            width: 52,
            child: Text(
              _labelFor(state),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ],
    );
  }

  IconData _iconFor(double pos, bool muted) {
    if (muted || pos <= 0) return Icons.volume_off_rounded;
    if (pos < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  String _labelFor(PlayerState state) {
    if (state.muted) return 'Muted';
    final db = state.volumeDb;
    if (db == null) return '−∞ dB';
    // At unity there is no attenuation; "0.0 dB" reads oddly next to negatives.
    if (db >= -0.05) return '0 dB';
    return '${db.toStringAsFixed(1)} dB';
  }

  String _tooltipFor(PlayerState state) {
    if (state.muted) return 'Muted (${_dbOnly(state)})';
    return 'Volume ${_dbOnly(state)}';
  }

  String _dbOnly(PlayerState state) {
    final db = state.volumeDb;
    if (db == null) return 'silent';
    if (db >= -0.05) return '0 dB';
    return '${db.toStringAsFixed(1)} dB';
  }
}
