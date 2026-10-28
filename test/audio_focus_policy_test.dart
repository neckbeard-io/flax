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

  group('requestAudioFocus', () {
    late _FocusPlugin plugin;
    setUp(() => plugin = _FocusPlugin());

    test('plays when Android grants focus', () async {
      expect(await requestAudioFocus(plugin.setActive), isTrue);
      expect(plugin.asked, 1);
    });

    test('stays paused while a call holds focus', () async {
      plugin.grant = false;

      expect(await requestAudioFocus(plugin.setActive), isFalse);
    });

    test('asks Android again after a refusal', () async {
      plugin.grant = false;
      await requestAudioFocus(plugin.setActive);

      plugin.grant = true;
      expect(await requestAudioFocus(plugin.setActive), isTrue);
      expect(plugin.asked, 2);
    });

    test('a refusal is not reported granted later', () async {
      plugin.grant = false;
      await requestAudioFocus(plugin.setActive);

      expect(await requestAudioFocus(plugin.setActive), isFalse);
    });
  });
}

/// audio_session's Android focus handling: a request is kept whether or not
/// Android granted it, and while one is kept, asking again reports success
/// without reaching Android. Abandoning clears it.
class _FocusPlugin {
  bool grant = true;
  int asked = 0;
  bool _requestKept = false;

  Future<bool> setActive(bool active) async {
    if (!active) {
      _requestKept = false;
      return true;
    }
    if (_requestKept) return true;
    _requestKept = true;
    asked++;
    return grant;
  }
}
