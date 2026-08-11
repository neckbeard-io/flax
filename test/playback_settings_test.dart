import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/playback_settings.dart';

/// Gapless, ReplayGain and the track fade.
///
/// All three used to be in-memory StateProviders the player never read. The
/// rules that decide what each one actually does live in playback_settings.dart
/// precisely so they can be checked without libmpv, a server, or an audio
/// device — none of which a test can have.
void main() {
  group('gapless and fading are mutually exclusive', () {
    test('gapless applies when nothing is fading', () {
      const s = PlaybackSettings(gapless: true, fadeSeconds: 0);
      expect(s.gaplessActive, isTrue);
      expect(s.fading, isFalse);
    });

    test('a fade wins over gapless', () {
      // Not policy — they are contradictory by nature. Gapless means the next
      // track starts on the sample after the last; a fade means the boundary is
      // deliberately seconds long.
      const s = PlaybackSettings(gapless: true, fadeSeconds: 3);
      expect(s.fading, isTrue);
      expect(s.gaplessActive, isFalse);
    });

    test('turning gapless off leaves it off whatever the fade', () {
      expect(
        const PlaybackSettings(gapless: false, fadeSeconds: 0).gaplessActive,
        isFalse,
      );
    });
  });

  group('serverReplayGainDb', () {
    test('off applies nothing', () {
      expect(
        serverReplayGainDb(mode: ReplayGainMode.off, trackGain: -7),
        isNull,
      );
    });

    test('track mode uses the track gain', () {
      expect(
        serverReplayGainDb(mode: ReplayGainMode.track, trackGain: -7.5),
        -7.5,
      );
    });

    test('album mode prefers the album gain', () {
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.album,
          trackGain: -7.5,
          albumGain: -6,
        ),
        -6,
      );
    });

    test('album mode falls back to the track gain', () {
      // A server that only scanned per-track should still normalize, rather
      // than the mode quietly doing nothing across half a library.
      expect(
        serverReplayGainDb(mode: ReplayGainMode.album, trackGain: -7.5),
        -7.5,
      );
    });

    test('no tags means mpv is left to read its own', () {
      // Null is the signal to fall back, not an offset of zero.
      expect(serverReplayGainDb(mode: ReplayGainMode.track), isNull);
    });

    test('a positive gain is held back from clipping', () {
      // Peak 1.0 is already at full scale, so there is no room to boost.
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.track,
          trackGain: 4,
          trackPeak: 1.0,
        ),
        moreOrLessEquals(0, epsilon: 0.001),
      );
    });

    test('a quiet track keeps the headroom its peak allows', () {
      // Peak 0.5 leaves about 6 dB before full scale, so +4 fits.
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.track,
          trackGain: 4,
          trackPeak: 0.5,
        ),
        4,
      );
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.track,
          trackGain: 9,
          trackPeak: 0.5,
        ),
        moreOrLessEquals(6.02, epsilon: 0.01),
      );
    });

    test('attenuation is never limited by the peak', () {
      // Turning a track down cannot clip it, so the peak has no say.
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.track,
          trackGain: -12,
          trackPeak: 1.0,
        ),
        -12,
      );
    });

    test('the preamp moves the whole thing', () {
      expect(
        serverReplayGainDb(
          mode: ReplayGainMode.track,
          trackGain: -7,
          preampDb: 3,
        ),
        -4,
      );
    });
  });

  group('fadeOffsetDb', () {
    const length = Duration(minutes: 4);

    test('costs nothing when no fade is set', () {
      expect(
        fadeOffsetDb(
          position: const Duration(seconds: 1),
          duration: length,
          fadeSeconds: 0,
        ),
        0,
      );
    });

    test('is silent at the very start and full by the end of the ramp', () {
      expect(
        fadeOffsetDb(position: Duration.zero, duration: length, fadeSeconds: 4),
        fadeFloorDb,
      );
      expect(
        fadeOffsetDb(
          position: const Duration(seconds: 4),
          duration: length,
          fadeSeconds: 4,
        ),
        0,
      );
    });

    test('ramps proportionally through the window', () {
      expect(
        fadeOffsetDb(
          position: const Duration(seconds: 2),
          duration: length,
          fadeSeconds: 4,
        ),
        fadeFloorDb / 2,
      );
    });

    test('fades the tail as well as the head', () {
      expect(
        fadeOffsetDb(
          position: length - const Duration(seconds: 2),
          duration: length,
          fadeSeconds: 4,
        ),
        fadeFloorDb / 2,
      );
      expect(
        fadeOffsetDb(position: length, duration: length, fadeSeconds: 4),
        fadeFloorDb,
      );
    });

    test('the middle of a track is untouched', () {
      expect(
        fadeOffsetDb(
          position: const Duration(minutes: 2),
          duration: length,
          fadeSeconds: 4,
        ),
        0,
      );
    });

    test('a fade longer than half the track is clamped', () {
      // Otherwise the head would still be fading in as the tail started fading
      // out, and the track would never reach full level.
      const short = Duration(seconds: 10);
      expect(
        fadeOffsetDb(
          position: const Duration(seconds: 5),
          duration: short,
          fadeSeconds: 12,
        ),
        0,
      );
    });

    test('an unknown duration fades nothing', () {
      // mpv reports the duration a moment after the stream opens. Fading on a
      // zero length would attenuate the start of every track by the floor.
      expect(
        fadeOffsetDb(
          position: Duration.zero,
          duration: Duration.zero,
          fadeSeconds: 4,
        ),
        0,
      );
    });

    test('a position past the end does not ramp back up', () {
      // Streams overrun their reported duration often enough to matter.
      expect(
        fadeOffsetDb(
          position: length + const Duration(seconds: 5),
          duration: length,
          fadeSeconds: 4,
        ),
        fadeFloorDb,
      );
    });
  });

  group('persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to gapless, no levelling, no fade', () {
      const s = PlaybackSettings();
      expect(s.gapless, isTrue);
      expect(s.replayGain, ReplayGainMode.off);
      expect(s.fadeSeconds, 0);
    });

    test('survives a round trip', () {
      const s = PlaybackSettings(
        gapless: false,
        replayGain: ReplayGainMode.album,
        fadeSeconds: 6,
      );
      final back = PlaybackSettings.fromJson(s.toJson());
      expect(back.gapless, isFalse);
      expect(back.replayGain, ReplayGainMode.album);
      expect(back.fadeSeconds, 6);
    });

    test('stores the mode by name, not by index', () {
      // Persisting the ordinal would remap every saved preference the first
      // time a value was added to ReplayGainMode.
      expect(
        const PlaybackSettings(
          replayGain: ReplayGainMode.album,
        ).toJson()['replayGain'],
        'album',
      );
    });

    test('an unrecognized mode falls back rather than throwing', () {
      final s = PlaybackSettings.fromJson({'replayGain': 'loudness-war'});
      expect(s.replayGain, ReplayGainMode.off);
    });

    test('an out-of-range fade is clamped on the way in', () {
      expect(
        PlaybackSettings.fromJson({'fadeSeconds': 900}).fadeSeconds,
        maxFadeSeconds,
      );
      expect(PlaybackSettings.fromJson({'fadeSeconds': -5}).fadeSeconds, 0);
    });

    test('a saved choice is written and read back', () async {
      final notifier = PlaybackSettingsNotifier();
      notifier.setReplayGain(ReplayGainMode.track);
      notifier.setFadeSeconds(5);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PlaybackSettingsNotifier.storageKey), isNotNull);

      final reloaded = PlaybackSettingsNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state.replayGain, ReplayGainMode.track);
      expect(reloaded.state.fadeSeconds, 5);
    });
  });
}
