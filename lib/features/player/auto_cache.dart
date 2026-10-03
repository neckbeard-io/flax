import 'package:flax/domain/models/models.dart';

/// Decides when a streamed track is saved to the rolling cache: once it is
/// actually playing, and not before.
///
/// Loading a queue is not listening to it. A queue opened paused — restored at
/// launch, or taken from the server because another device changed it — used
/// to cache its current track, so music played elsewhere was downloaded to
/// this device without ever playing here. Following the player's state rather
/// than the calls that load tracks also covers every way playback starts: a
/// button, a media key, Android Auto, a gapless advance.
class AutoCacheTrigger {
  AutoCacheTrigger({
    required this.enabled,
    required this.isCached,
    required this.cache,
  });

  /// Whether Auto-Cache Streamed Music is on.
  final bool Function() enabled;

  /// Whether [song] is already on disk.
  final bool Function(Song song) isCached;

  /// Saves [song] to the rolling cache, completing when that is done or has
  /// failed.
  final Future<void> Function(Song song) cache;

  final Set<String> _inFlight = {};
  String? _lastPlayingId;

  /// Takes every player state. Returns at once unless the playing track has
  /// changed, so position ticks cost nothing.
  void update(Song? current, {required bool playing}) {
    final playingId = playing ? current?.id : null;
    if (playingId == _lastPlayingId) return;
    _lastPlayingId = playingId;
    if (current == null || playingId == null) return;
    if (_inFlight.contains(current.id) || !enabled() || isCached(current)) {
      return;
    }
    _inFlight.add(current.id);
    cache(current).whenComplete(() => _inFlight.remove(current.id)).ignore();
  }
}
