import 'package:audio_session/audio_session.dart';
import 'package:flax/features/player/audio_focus_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lostForAWhile = AudioInterruptionEvent(
    true,
    AudioInterruptionType.pause,
  );
  final returned = AudioInterruptionEvent(false, AudioInterruptionType.pause);
  final lostForGood = AudioInterruptionEvent(
    true,
    AudioInterruptionType.unknown,
  );
  final duck = AudioInterruptionEvent(true, AudioInterruptionType.duck);
  final unducked = AudioInterruptionEvent(false, AudioInterruptionType.duck);

  late AudioFocusPolicy policy;
  setUp(() => policy = AudioFocusPolicy());

  test('the Assistant pauses playback and resumes it when done', () {
    expect(
      policy.onInterruption(lostForAWhile, isPlaying: true),
      AudioFocusAction.pause,
    );
    expect(
      policy.onInterruption(returned, isPlaying: false),
      AudioFocusAction.resume,
    );
  });

  test('resumes only once', () {
    policy.onInterruption(lostForAWhile, isPlaying: true);
    policy.onInterruption(returned, isPlaying: false);

    expect(
      policy.onInterruption(returned, isPlaying: false),
      AudioFocusAction.none,
    );
  });

  test('does not start music that was already paused', () {
    expect(
      policy.onInterruption(lostForAWhile, isPlaying: false),
      AudioFocusAction.none,
    );
    expect(
      policy.onInterruption(returned, isPlaying: false),
      AudioFocusAction.none,
    );
  });

  test('a choice made during the interruption stands', () {
    policy.onInterruption(lostForAWhile, isPlaying: true);
    policy.cancel();

    expect(
      policy.onInterruption(returned, isPlaying: false),
      AudioFocusAction.none,
    );
  });

  test('another app taking over pauses with nothing to resume', () {
    policy.onInterruption(lostForAWhile, isPlaying: true);
    expect(
      policy.onInterruption(lostForGood, isPlaying: false),
      AudioFocusAction.none,
    );
    expect(
      policy.onInterruption(lostForGood, isPlaying: true),
      AudioFocusAction.pause,
    );
    expect(
      policy.onInterruption(returned, isPlaying: false),
      AudioFocusAction.none,
    );
  });

  test('navigation prompts leave ducking to Android', () {
    expect(policy.onInterruption(duck, isPlaying: true), AudioFocusAction.none);
    expect(
      policy.onInterruption(unducked, isPlaying: true),
      AudioFocusAction.none,
    );
  });
}
