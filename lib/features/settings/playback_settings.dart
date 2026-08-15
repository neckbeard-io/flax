import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loudness normalization mode.
///
/// Deliberately mpv-free: the player maps this onto `ReplayGain` itself, so the
/// rules below can be tested without standing up libmpv.
enum ReplayGainMode {
  off('Off'),
  track('Track'),
  album('Album');

  const ReplayGainMode(this.label);

  final String label;
}

/// Longest fade the slider offers, in seconds.
const double maxFadeSeconds = 12;

/// How tracks are levelled and how one gives way to the next.
///
/// These three used to be plain in-memory StateProviders that the player never
/// read at all — set them and nothing happened, and the choice was gone by the
/// next launch.
class PlaybackSettings {
  /// Whether consecutive tracks run into each other with no re-initialization
  /// of the audio output.
  final bool gapless;

  final ReplayGainMode replayGain;

  /// Seconds of fade between tracks; 0 is off.
  final double fadeSeconds;

  /// Whether to switch to Now Playing screen when playback starts.
  final bool autoSwitchToNowPlaying;

  const PlaybackSettings({
    this.gapless = true,
    this.replayGain = ReplayGainMode.off,
    this.fadeSeconds = 0,
    this.autoSwitchToNowPlaying = false,
  });

  /// Whether a fade is wanted at all.
  bool get fading => fadeSeconds > 0;

  /// Whether gapless actually applies.
  ///
  /// The two are mutually exclusive by nature, not by policy: gapless means the
  /// next track starts on the sample after the last one, and a fade means the
  /// boundary is deliberately several seconds long. Fading wins when both are
  /// asked for, because it is the one the user set to a non-default value.
  bool get gaplessActive => gapless && !fading;

  PlaybackSettings copyWith({
    bool? gapless,
    ReplayGainMode? replayGain,
    double? fadeSeconds,
    bool? autoSwitchToNowPlaying,
  }) => PlaybackSettings(
    gapless: gapless ?? this.gapless,
    replayGain: replayGain ?? this.replayGain,
    fadeSeconds: fadeSeconds ?? this.fadeSeconds,
    autoSwitchToNowPlaying: autoSwitchToNowPlaying ?? this.autoSwitchToNowPlaying,
  );

  Map<String, dynamic> toJson() => {
    'gapless': gapless,
    'replayGain': replayGain.name,
    'fadeSeconds': fadeSeconds,
    'autoSwitchToNowPlaying': autoSwitchToNowPlaying,
  };

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) =>
      PlaybackSettings(
        gapless: json['gapless'] as bool? ?? true,
        replayGain: ReplayGainMode.values.firstWhere(
          (m) => m.name == json['replayGain'],
          orElse: () => ReplayGainMode.off,
        ),
        fadeSeconds: ((json['fadeSeconds'] as num?)?.toDouble() ?? 0).clamp(
          0,
          maxFadeSeconds,
        ),
        autoSwitchToNowPlaying: json['autoSwitchToNowPlaying'] as bool? ?? false,
      );
}

/// dB offset for the current track from the server's own ReplayGain tags, or
/// null when there is nothing to apply.
///
/// **The server wins over mpv's own tag reading.** mpv reads gain tags out of
/// the stream it is decoding, which is only the original file when nothing is
/// transcoded — ask for Opus on a slow connection and the tags are gone, and
/// normalization would silently switch itself off mid-library. Navidrome
/// scanned these values from the source files once and reports them alongside
/// the track, so they survive whatever the stream turns into.
///
/// Returning null is what tells the player to fall back to mpv's own reading
/// for that track, which is the right answer for a server too old to send the
/// OpenSubsonic `replayGain` block at all.
double? serverReplayGainDb({
  required ReplayGainMode mode,
  double? trackGain,
  double? trackPeak,
  double? albumGain,
  double? albumPeak,
  double preampDb = 0,
}) {
  final (double? gain, double? peak) = switch (mode) {
    ReplayGainMode.off => (null, null),
    ReplayGainMode.track => (trackGain, trackPeak),
    // Album mode falls back to the track values rather than to nothing: a
    // server that only scanned per-track should still normalize, and the
    // alternative is the mode quietly doing nothing on half a library.
    ReplayGainMode.album => (albumGain ?? trackGain, albumPeak ?? trackPeak),
  };
  if (gain == null) return null;

  final wanted = gain + preampDb;
  if (peak == null || peak <= 0) return wanted;

  // Never push the loudest sample in the track past full scale. Peak is a
  // linear amplitude where 1.0 is full scale, so the room above it in dB is
  // -20*log10(peak) — zero for a track that already touches the ceiling.
  final headroomDb = -20 * (math.log(peak) / math.ln10);
  return wanted < headroomDb ? wanted : headroomDb;
}

/// How far down a fade pulls the output at its deepest, in dB. Below roughly
/// this the difference stops being audible, so ramping further only wastes the
/// seconds the user asked for.
const double fadeFloorDb = -60;

/// Attenuation in dB for a track fading in at its head or out at its tail.
///
/// Zero outside the fade windows, so the common case costs nothing.
///
/// This is a gain ramp, not ffmpeg's `afade`. mpv exposes a single afade slot
/// and the equalizer already owns the filter chain, and one afade can anchor to
/// one end of a track, not both. Riding the output gain does both ends, cannot
/// collide with the EQ, and needs no filter reinitialization mid-track.
///
/// Ramping linearly in dB rather than in amplitude is deliberate: loudness is
/// perceived roughly logarithmically, so a linear-amplitude fade sounds like it
/// hangs near the top and then drops off a cliff.
double fadeOffsetDb({
  required Duration position,
  required Duration duration,
  required double fadeSeconds,
}) {
  if (fadeSeconds <= 0 || duration <= Duration.zero) return 0;

  // A fade longer than half the track would have the head still fading in as
  // the tail starts fading out, and the track would never reach full level.
  final half = duration.inMilliseconds / 2000;
  final fade = fadeSeconds < half ? fadeSeconds : half;
  if (fade <= 0) return 0;

  final elapsed = position.inMilliseconds / 1000;
  final remaining = (duration - position).inMilliseconds / 1000;
  // Clamped, because a position past the reported duration is not unusual on a
  // stream and would otherwise ramp back up through the floor.
  final edge = (elapsed < remaining ? elapsed : remaining).clamp(0.0, fade);
  if (edge >= fade) return 0;

  return fadeFloorDb * (1 - edge / fade);
}

final playbackSettingsProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>(
      (ref) => PlaybackSettingsNotifier(),
    );

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  static const storageKey = 'flax_playback_settings';

  PlaybackSettingsNotifier() : super(const PlaybackSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      state = PlaybackSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt or unreadable prefs — keep the defaults.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore write failures; the in-memory choice still applies this run.
    }
  }

  void setGapless(bool value) {
    state = state.copyWith(gapless: value);
    _save();
  }

  void setReplayGain(ReplayGainMode mode) {
    state = state.copyWith(replayGain: mode);
    _save();
  }

  void setFadeSeconds(double seconds) {
    state = state.copyWith(fadeSeconds: seconds.clamp(0, maxFadeSeconds));
    _save();
  }

  void setAutoSwitchToNowPlaying(bool value) {
    state = state.copyWith(autoSwitchToNowPlaying: value);
    _save();
  }
}
