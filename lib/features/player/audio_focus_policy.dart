import 'package:audio_session/audio_session.dart';

/// What the player should do about an audio focus change.
enum AudioFocusAction { none, pause, resume }

/// Decides what to do when another app takes or returns audio focus.
///
/// The Assistant, a phone call or a spoken message takes focus for a while
/// (`pause`): flax pauses and plays again once it is returned. It used to
/// pause and stay paused. Navigation prompts allow ducking (`duck`), which
/// Android does by lowering flax's volume itself. Another music app taking
/// over for good (`unknown`) pauses with nothing to come back to.
class AudioFocusPolicy {
  bool _resumePending = false;

  AudioFocusAction onInterruption(
    AudioInterruptionEvent event, {
    required bool isPlaying,
  }) {
    if (!event.begin) {
      if (event.type != AudioInterruptionType.pause || !_resumePending) {
        return AudioFocusAction.none;
      }
      _resumePending = false;
      return AudioFocusAction.resume;
    }
    switch (event.type) {
      case AudioInterruptionType.duck:
        return AudioFocusAction.none;
      case AudioInterruptionType.pause:
        if (!isPlaying) return AudioFocusAction.none;
        _resumePending = true;
        return AudioFocusAction.pause;
      case AudioInterruptionType.unknown:
        _resumePending = false;
        return isPlaying ? AudioFocusAction.pause : AudioFocusAction.none;
    }
  }

  /// Someone played or paused on purpose during the interruption: whatever
  /// they chose stands when it ends.
  void cancel() => _resumePending = false;
}
