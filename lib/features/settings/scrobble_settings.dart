import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether plays are reported back to the server.
///
/// On by default, because with it off the server's own history simply stops:
/// Navidrome advances an album's play count and play date only when a client
/// scrobbles — requesting the stream is not a play — so Recently Played and
/// Most Played sit frozen at whatever another client last reported.
///
/// Worth a switch all the same. Scrobbles are per-user state written to a
/// server that may be shared, and Navidrome can forward them on to Last.fm or
/// ListenBrainz, so "do not record what I am listening to" is a real thing to
/// want.
final scrobbleEnabledProvider =
    StateNotifierProvider<ScrobbleEnabledNotifier, bool>(
  (ref) => ScrobbleEnabledNotifier(),
);

class ScrobbleEnabledNotifier extends StateNotifier<bool> {
  static const storageKey = 'flax_scrobble_enabled';

  ScrobbleEnabledNotifier() : super(defaultEnabled) {
    _load();
  }

  static const bool defaultEnabled = true;

  /// Reads the saved choice. Async, so the first frame uses the default and is
  /// replaced once prefs arrive — the same tradeoff every other persisted
  /// setting here makes.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(storageKey);
      if (saved == null) return;
      state = saved;
    } catch (_) {
      // Unreadable prefs — keep the default rather than failing to open.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, enabled);
    } catch (_) {
      // Ignore write failures; the in-memory choice still applies this run.
    }
  }
}

/// Shortest track worth reporting.
const Duration minScrobbleLength = Duration(seconds: 30);

/// Longest a track has to run before it counts, however long it is.
const Duration maxScrobbleThreshold = Duration(minutes: 4);

/// How far into a track of [length] it counts as played, or null if the track
/// is too short to count at all.
///
/// Half the track or four minutes, whichever comes first, and nothing under
/// thirty seconds — the Last.fm rule that Subsonic clients follow. The server
/// does not apply this itself: `scrobble` with `submission=true` records the
/// play the moment it arrives, so deciding *when* is the client's job, and
/// submitting on track start would count every skip as a listen.
///
/// A zero or negative [length] means the duration is not known yet — mpv
/// reports it a moment after the stream opens — and nothing is submitted until
/// it is.
Duration? scrobbleThreshold(Duration length) {
  if (length < minScrobbleLength) return null;
  final half = length ~/ 2;
  return half < maxScrobbleThreshold ? half : maxScrobbleThreshold;
}
