import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/domain/repositories/library_repository.dart';
import 'package:flax/features/player/gapless_probe.dart';
import 'package:flax/features/settings/audio_output_settings.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/features/settings/scrobble_settings.dart';
import 'package:flax/services/audio/audio_handler_provider.dart';
import 'package:flax/services/audio/flax_audio_handler.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/services/cache/audio_cache_service.dart';
import 'package:flax/services/platform/now_playing_service.dart';
import 'package:flax/services/transcoding/transcoding_service.dart';
import 'package:flax/shared/async/coalescing_runner.dart';
import 'package:flax/shared/audio/eq_filter.dart';

class PlayerState {
  final Song? currentSong;
  final List<Song> queue;
  final int queueIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  /// Fader position, 0.0 (silent) to 1.0 (unity gain). This is *not* a linear
  /// amplitude multiplier — see [PlayerNotifier.faderToMpvVolume].
  final double volume;
  final bool muted;
  final bool shuffle;
  final RepeatMode repeatMode;
  final bool buffering;

  /// Active transcoding parameters for the current stream, or null if playing
  /// at original source quality.
  final TranscodeParameters? activeTranscode;

  /// Human-readable error if playback was prevented (e.g. streaming disabled).
  final String? playbackError;

  /// Whether the currently playing track is playing from local offline cache.
  final bool isPlayingCached;

  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.queueIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.muted = false,
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.buffering = false,
    this.activeTranscode,
    this.playbackError,
    this.isPlayingCached = false,
  });

  /// Attenuation the current fader position corresponds to, in dB, or null at
  /// the very bottom of the fader (true silence, which has no finite dB value).
  double? get volumeDb => volume <= 0 ? null : PlayerNotifier.faderToDb(volume);

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? queueIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? muted,
    bool? shuffle,
    RepeatMode? repeatMode,
    bool? buffering,
    TranscodeParameters? activeTranscode,
    bool clearActiveTranscode = false,
    String? playbackError,
    bool clearPlaybackError = false,
    bool? isPlayingCached,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      buffering: buffering ?? this.buffering,
      activeTranscode: clearActiveTranscode
          ? null
          : (activeTranscode ?? this.activeTranscode),
      playbackError: clearPlaybackError
          ? null
          : (playbackError ?? this.playbackError),
      isPlayingCached: isPlayingCached ?? this.isPlayingCached,
    );
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  // No ref.onDispose here: StateNotifierProvider already disposes the notifier
  // it is given, so adding one disposed it twice and threw "Tried to use
  // PlayerNotifier after dispose was called". Invisible in the app, where this
  // provider lives for the whole session and is never disposed — it only
  // surfaces under test, where scopes come and go.
  return PlayerNotifier(ref);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final mpv.Player _player;
  final NowPlayingService _nowPlaying;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _lastNowPlayingSongId;

  /// Track already announced to the server as playing, and track whose play has
  /// already been recorded. Held separately because the two happen at different
  /// moments and only the second one counts as a listen.
  String? _scrobbleAnnouncedId;
  String? _scrobbleSubmittedId;
  Timer? _saveQueueTimer;
  int _lastSavedPositionSec = -1;
  ProviderSubscription<EqState>? _eqSub;
  ProviderSubscription<AutoEqState>? _autoEqSub;
  ProviderSubscription<EqEngine>? _eqEngineSub;
  ProviderSubscription<PlaybackSettings>? _playbackSub;
  ProviderSubscription<AudioOutputSettings>? _audioOutputSub;

  /// Fade attenuation last pushed to mpv, so the ramp only re-applies when it
  /// has actually moved.
  double _lastAppliedFadeDb = 0;

  /// Output gain last pushed to mpv, so an unchanged value is not rewritten.
  double? _lastAppliedGainDb;

  /// Song ids currently loaded into mpv's playlist, in order. Gapless needs the
  /// queue to live in mpv rather than being fed one file at a time, and this is
  /// how we know whether what mpv holds still matches [PlayerState.queue].
  List<String> _mpvQueueIds = const [];
  GaplessProbe? _probe;

  PlayerNotifier(this._ref)
    : _player = mpv.Player(),
      _nowPlaying = _ref.read(nowPlayingServiceProvider),
      super(const PlayerState()) {
    _initProbe();
    _initStreams();
    _initMediaKeys();
    _initEqListener();
    _initPlaybackSettings();
    _initAudioOutputSettings();
    _restoreVolume();
    _restorePlayQueue();
  }

  /// Starts the track-boundary instrumentation, when asked for.
  ///
  /// Before the stream subscriptions, so the probe sees the first transition
  /// rather than joining halfway through it. Raising mpv's own log level is
  /// part of the same opt-in: at debug it is far too chatty to leave on.
  void _initProbe() {
    if (!gaplessProbeEnabled) return;
    _player.setLogLevel(mpv.LogLevel.debug);
    _probe = GaplessProbe(_player)..start();
  }

  void _initMediaKeys() {
    _nowPlaying.onPlay = () => play();
    _nowPlaying.onPause = () => pause();
    _nowPlaying.onTogglePlayPause = () => togglePlayPause();
    _nowPlaying.onNext = () => next();
    _nowPlaying.onPrevious = () => previous();
    _nowPlaying.onSeek = (pos) => seek(pos);
  }

  FlaxAudioHandler? get _audioHandler => _ref.read(audioHandlerProvider);

  void _initStreams() {
    _subs.add(
      _player.stream.playing.listen((playing) {
        if (mounted) {
          state = state.copyWith(isPlaying: playing);
          _nowPlaying.updatePlaybackState(
            position: state.position,
            isPlaying: playing,
          );
          _audioHandler?.updateFromPlayerState(state);
          // Driven off playback actually starting rather than off the calls that
          // load a track, so a queue restored at launch — which opens its track
          // paused and never goes through _playIndex — still announces itself
          // when you press play.
          if (playing) _announceNowPlaying();
        }
      }),
    );
    _subs.add(
      _player.stream.position.listen((pos) {
        if (mounted) {
          state = state.copyWith(position: pos);
          _maybeSubmitScrobble(pos);
          _updateFadeGain();
          // Save queue position every 10 seconds of playback change
          final currentSec = pos.inSeconds;
          if ((currentSec - _lastSavedPositionSec).abs() >= 10) {
            _lastSavedPositionSec = currentSec;
            _debounceSaveQueue();
          }
        }
      }),
    );
    _subs.add(
      _player.stream.duration.listen((dur) {
        if (mounted) state = state.copyWith(duration: dur);
      }),
    );
    _subs.add(
      _player.stream.buffering.listen((buf) {
        if (mounted) state = state.copyWith(buffering: buf);
      }),
    );
    _subs.add(
      _player.stream.completed.listen((completed) {
        if (mounted && completed) {
          _onTrackCompleted();
        }
      }),
    );
    // How a gapless advance reaches us: mpv moves to the next playlist entry on
    // its own, and nothing else reports it.
    _subs.add(
      _player.stream.playlist.listen((playlist) {
        if (mounted) _onMpvPlaylistIndex(playlist.index);
      }),
    );
    _subs.add(
      _player.stream.audioDevices.listen((devices) {
        if (devices.isNotEmpty) {
          _ref.read(audioDevicesProvider.notifier).state = devices;
        }
      }),
    );
    _subs.add(
      _player.stream.error.listen((err) {
        AppLogger.e('Player', 'mpv error: ${err.message}');
        if (mounted) {
          state = state.copyWith(isPlaying: false, playbackError: err.message);
        }
      }),
    );
  }

  void _onTrackCompleted() {
    if (state.repeatMode == RepeatMode.one) {
      // A second time through is a second listen, so this play has to be able
      // to be recorded again.
      _resetScrobble();
      seek(Duration.zero);
      play();
      return;
    }
    // Mid-queue, mpv advances by itself now that it holds the whole playlist,
    // and _onMpvPlaylistIndex picks that up. Calling next() here as well would
    // skip a track on every boundary. Only the end of the queue is ours.
    if (_mpvQueueInSync && state.queueIndex < state.queue.length - 1) return;
    if (state.queueIndex < state.queue.length - 1) {
      next();
    } else if (state.repeatMode == RepeatMode.all && state.queue.isNotEmpty) {
      _playIndex(0);
    } else {
      _onQueueFinished();
    }
  }

  /// The queue ran out with repeat off.
  ///
  /// This used to do nothing, which left mpv wherever its `keep-open` policy
  /// had parked it: paused on the last frame with `eof-reached` set. That is
  /// not an ordinary paused state, and picking another album afterwards
  /// loaded it without starting playback — the album appeared merely queued
  /// and needed a manual press of play, while the same action from a fresh
  /// start played immediately.
  ///
  /// Rewinding clears `eof-reached`, so the transport ends up somewhere both
  /// the play button and the next `open()` behave normally.
  Future<void> _onQueueFinished() async {
    try {
      await _player.seek(Duration.zero);
      await _player.pause();
    } catch (e) {
      AppLogger.w('Player', 'Queue-finished reset failed: $e');
    }
    if (!mounted) return;
    state = state.copyWith(position: Duration.zero, isPlaying: false);
  }

  Future<List<ConnectivityResult>> _getConnectivity() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return [ConnectivityResult.wifi];
    }
  }

  TranscodeParameters? _resolveTranscode(
    List<ConnectivityResult> connectivity,
  ) {
    final server = _ref.read(activeServerProvider);
    if (server == null) return null;
    try {
      return TranscodingService.resolveStreamParameters(
        server: server,
        connectivity: connectivity,
      );
    } on StreamingDisabledException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  String? _findCachedSongPath(Song song) {
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      return song.localPath;
    }
    return AudioCacheService.findCachedSongPathSync(
      song.serverId,
      song.id,
      song.suffix,
    );
  }

  bool _isSongCached(Song? song) {
    if (song == null) return false;
    return _findCachedSongPath(song) != null;
  }

  Uri _streamUri(Song song, [TranscodeParameters? transcode]) {
    final cachedPath = _findCachedSongPath(song);
    if (cachedPath != null) {
      return Uri.file(cachedPath);
    }
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      throw Exception('No server connected');
    }
    return client.getStreamUri(
      song.id,
      maxBitRate: transcode?.maxBitRate,
      format: transcode?.format,
    );
  }

  // ── The queue, as mpv holds it ─────────────────────────────────────
  //
  // The whole queue is loaded into mpv's playlist rather than fed to it one
  // file at a time. That is what makes gapless possible at all: mpv can only
  // prefetch, and hand one track's decoder to the next, across entries of a
  // playlist it already holds. Feeding it a file at a time meant every
  // boundary was a Dart round trip and a fresh network open — a gap by
  // construction, whatever `--gapless-audio` was set to.
  //
  // [PlayerState.queue] stays the source of truth for the UI; [_mpvQueueIds]
  // records what mpv was actually given, so the two can be checked against
  // each other before an index from mpv is believed.

  /// Whether mpv's playlist still holds exactly the queue we think it does.
  bool get _mpvQueueInSync {
    final queue = state.queue;
    if (_mpvQueueIds.length != queue.length) return false;
    for (var i = 0; i < queue.length; i++) {
      if (_mpvQueueIds[i] != queue[i].id) return false;
    }
    return true;
  }

  /// Loads [songs] into mpv as one playlist, starting at [index].
  ///
  /// `openAll(play: true)` already asks mpv to unpause, but the follow-up
  /// [Player.play] is deliberate rather than redundant: it is documented as
  /// idempotent, and it makes "start playing" hold even when the player was
  /// parked somewhere unusual beforehand — the end-of-queue case being the one
  /// that actually bit. Cheap insurance against a load that lands paused.
  Future<void> _openQueue(
    List<Song> songs,
    int index, {
    required bool play,
  }) async {
    final connectivity = await _getConnectivity();
    TranscodeParameters? transcode;
    try {
      transcode = _resolveTranscode(connectivity);
    } on StreamingDisabledException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        queue: songs,
        queueIndex: index,
        currentSong: songs.isNotEmpty && index < songs.length
            ? songs[index]
            : null,
        isPlaying: false,
        clearActiveTranscode: true,
        playbackError: e.message,
      );
      AppLogger.w('Player', 'Streaming disabled: ${e.message}');
      return;
    }

    final medias = [
      for (final song in songs)
        mpv.Media(_streamUri(song, transcode).toString()),
    ];
    _mpvQueueIds = [for (final song in songs) song.id];
    final currentSong = songs.isNotEmpty && index < songs.length
        ? songs[index]
        : null;
    final isCached = _isSongCached(currentSong);

    if (mounted) {
      state = state.copyWith(
        activeTranscode: transcode,
        clearActiveTranscode: transcode == null,
        clearPlaybackError: true,
        isPlayingCached: isCached,
      );
    }
    await _player.openAll(medias, play: play, index: index);
    if (play) await _player.play();

    if (currentSong != null && !isCached) {
      final autoCache = _ref.read(audioCacheConfigProvider).autoCacheStreamed;
      if (autoCache) {
        _ref
            .read(audioCacheServiceProvider)
            .cacheSong(currentSong, isPinned: false);
      }
    }
  }

  /// mpv moved to another entry by itself, which is what a gapless advance
  /// looks like from here — there is no call of ours to hang the state change
  /// off, so the playlist is the only thing that knows.
  void _onMpvPlaylistIndex(int index) {
    // An index is only meaningful while mpv holds the queue we think it does;
    // mid-reload the two disagree and the index would name the wrong song.
    if (!_mpvQueueInSync) return;
    if (index < 0 || index >= state.queue.length) return;
    if (index == state.queueIndex) return;

    final song = state.queue[index];
    final isCached = _isSongCached(song);
    _resetScrobble();
    state = state.copyWith(
      queueIndex: index,
      currentSong: song,
      isPlayingCached: isCached,
    );
    _updateNowPlayingForSong(song);
    // ReplayGain is per track, so the output gain has to be recomputed for the
    // track mpv just moved to.
    _applyVolumeGain();
    _debounceSaveQueue();

    if (!isCached && _ref.read(audioCacheConfigProvider).autoCacheStreamed) {
      _ref.read(audioCacheServiceProvider).cacheSong(song, isPinned: false);
    }
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final song = state.queue[index];
    final isCached = _isSongCached(song);
    _resetScrobble();
    state = state.copyWith(
      currentSong: song,
      queueIndex: index,
      isPlayingCached: isCached,
    );
    // A jump inside the playlist mpv already holds, rather than a fresh load:
    // reloading would throw away the prefetched next entry every time someone
    // pressed skip.
    if (_mpvQueueInSync) {
      await _player.jump(index);
      await _player.play();
    } else {
      await _openQueue(state.queue, index, play: true);
    }
    _updateNowPlayingForSong(song);
    _applyVolumeGain();
    _debounceSaveQueue();

    if (!isCached && _ref.read(audioCacheConfigProvider).autoCacheStreamed) {
      _ref.read(audioCacheServiceProvider).cacheSong(song, isPinned: false);
    }
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    final newQueue = queue ?? [song];
    final newIndex = index ?? 0;
    _resetScrobble();
    state = state.copyWith(
      queue: newQueue,
      queueIndex: newIndex,
      currentSong: newQueue[newIndex],
    );
    await _openQueue(newQueue, newIndex, play: true);
    _updateNowPlayingForSong(newQueue[newIndex]);
    _applyVolumeGain();
    _debounceSaveQueue();
  }

  void _updateNowPlayingForSong(
    Song song, {
    bool? isPlaying,
    Duration? position,
  }) {
    if (song.id == _lastNowPlayingSongId &&
        isPlaying == null &&
        position == null) {
      return;
    }
    _lastNowPlayingSongId = song.id;

    String? artUrl;
    try {
      final client = _ref.read(subsonicClientProvider);
      if (client != null && song.coverArtId != null) {
        artUrl = client.getCoverArtUri(song.coverArtId!, size: 300).toString();
      }
    } catch (_) {}

    _nowPlaying.updateNowPlaying(
      song: song,
      position: position ?? Duration.zero,
      duration: Duration(seconds: song.duration),
      isPlaying: isPlaying ?? true,
      artUrl: artUrl,
    );
    _audioHandler?.updateFromPlayerState(state);
  }

  // ── Scrobbling ─────────────────────────────────────────────────────
  //
  // Reporting plays back to the server, which is the only thing that moves its
  // play counts and play dates — streaming a file does not. Without this,
  // Recently Played and Most Played stay frozen at whatever another client last
  // reported, however much you listen here.
  //
  // Both calls are fire-and-forget. A server that is slow, offline, or refuses
  // the request must never stall or interrupt playback, so failures are logged
  // and dropped.

  /// Forgets what has been reported for the playing track.
  ///
  /// Called when a different track is loaded, and when repeat-one restarts the
  /// same one — the second time through is a second listen, and the id guards
  /// alone would swallow it.
  void _resetScrobble() {
    _scrobbleAnnouncedId = null;
    _scrobbleSubmittedId = null;
  }

  /// Tells the server what is playing, so its now-playing list is right. Not a
  /// play: `submission: false` is explicitly the "started" notification.
  void _announceNowPlaying() {
    final song = state.currentSong;
    if (song == null || song.id == _scrobbleAnnouncedId) return;
    if (!_ref.read(scrobbleEnabledProvider)) return;
    _scrobbleAnnouncedId = song.id;
    _scrobble(song.id, submission: false);
  }

  /// Records the play once the track has run far enough to count.
  ///
  /// Reads the position rather than timing the playback, which means seeking
  /// past the threshold counts the track. That is the same bargain every other
  /// Subsonic client makes, and the alternative — accumulating played time —
  /// buys accuracy in a case nobody hits by accident.
  void _maybeSubmitScrobble(Duration position) {
    final song = state.currentSong;
    if (song == null || song.id == _scrobbleSubmittedId) return;
    if (!_ref.read(scrobbleEnabledProvider)) return;

    // mpv reports the real duration a moment after the stream opens; until it
    // does, the length the server gave us for the track is the better number.
    final length = state.duration > Duration.zero
        ? state.duration
        : Duration(seconds: song.duration);

    final threshold = scrobbleThreshold(length);
    if (threshold == null || position < threshold) return;

    _scrobbleSubmittedId = song.id;
    _scrobble(song.id, submission: true);
  }

  Future<void> _scrobble(String id, {required bool submission}) async {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) return;
    try {
      await client.scrobble(id, submission: submission);
    } catch (e) {
      AppLogger.w('Player', 'scrobble (submission: $submission) failed: $e');
    }
  }

  // ── EQ ────────────────────────────────────────────────────────────

  void _initEqListener() {
    _eqSub = _ref.listen<EqState>(eqProvider, (_, _) {
      _applyEq();
    });
    _autoEqSub = _ref.listen<AutoEqState>(autoEqProvider, (_, _) {
      _applyEq();
    });
    // Switching engine has to rebuild the chain immediately: the point of the
    // control is hearing the difference on the track already playing.
    _eqEngineSub = _ref.listen<EqEngine>(eqEngineProvider, (_, _) {
      _applyEq();
    });
    // Apply initial state
    _applyEq();
  }

  /// Per-band gain in dB for the manual curve plus any AutoEQ correction.
  List<double> _combinedEqGains() {
    final eq = _ref.read(eqProvider);
    final autoEq = _ref.read(autoEqProvider);
    final gainsDb = List<double>.filled(eqBandCount, 0);

    if (eq.enabled) {
      for (var i = 0; i < eq.bands.length && i < eqBandCount; i++) {
        gainsDb[i] += eq.bands[i].gain;
      }
    }

    // AutoEQ correction sums on top of the manual curve.
    final profile = autoEq.activeProfile;
    if (profile != null && profile.points.isNotEmpty) {
      for (var i = 0; i < eqBandCount; i++) {
        gainsDb[i] += _interpolateGain(profile.points, eqBandFrequencies[i]);
      }
    }
    return gainsDb;
  }

  /// The EQ's share of the output gain: manual preamp, less headroom.
  ///
  /// The equalizer amplifies for real, and AutoEQ curves routinely carry bass
  /// shelves of +6 dB or more, so a boosted band on already-loud material clips
  /// audibly. Pull the whole chain down by the largest boost in the combined
  /// curve, which costs loudness but is the only way a positive band can be
  /// honoured cleanly.
  double _eqGainDb(List<double> gainsDb) {
    final eq = _ref.read(eqProvider);
    final maxBoostDb = gainsDb.fold<double>(0, (m, g) => g > m ? g : m);
    return (eq.enabled ? eq.preamp : 0.0) - maxBoostDb;
  }

  /// Serializes EQ applies so the last *request* wins, not the last completion.
  ///
  /// On startup the EQ read as on, with the right preset and engine, and was
  /// audibly not applied (#35). Three applies race at launch — the initial one,
  /// then one each as the stored EQ settings and AutoEQ profile finish loading
  /// from SharedPreferences — and each awaits mpv part-way through. The earliest
  /// ran before the stored settings had loaded, so it carried the default
  /// "EQ off", and it reached mpv last:
  ///
  ///     #1 ENTER enabled=false        (defaults, prefs not loaded yet)
  ///     #2 ENTER enabled=true  -> WRITE active=true
  ///     #3 ENTER enabled=true  -> WRITE active=true  DONE
  ///     #1                        WRITE active=false DONE   <- wins
  ///
  /// mpv keeps whatever landed last, so the filter was off while every provider
  /// the screen reads said it was on. Toggling fixed it because that apply ran
  /// with nothing to race.
  final _eqApply = CoalescingRunner();

  Future<void> _applyEq() => _eqApply.run(_applyEqOnce);

  Future<void> _applyEqOnce() async {
    try {
      await _applyVolumeGain();
      // Read after the await, not before it, so the curve written to mpv is the
      // one that is current at the moment of writing.
      final gainsDb = _combinedEqGains();

      // The same curve, handed to one filter or the other. Both branches see
      // the identical gainsDb, so switching engines cannot change what the EQ
      // is asking for — only how it is realized, which is the whole point of
      // being able to switch.
      final engine = _ref.read(eqEngineProvider);
      final bool active;
      final mpv.AudioEffects effects;

      switch (engine) {
        case EqEngine.parametric:
          final params = anequalizerParams(gainsDb);
          active = params.isNotEmpty;
          effects = const mpv.AudioEffects().copyWith(
            anequalizer: mpv.AnequalizerSettings(
              enabled: active,
              params: params,
            ),
          );
        case EqEngine.graphic:
          final params = superequalizerParams(gainsDb);
          active = params.isNotEmpty;
          effects = const mpv.AudioEffects().copyWith(
            superequalizer: mpv.SuperequalizerSettings(
              enabled: active,
              params: params,
            ),
          );
      }

      AppLogger.d(
        'PlayerEQ',
        () =>
            'EQ apply: engine=${engine.name}, active=$active, '
            'eqGain=${_eqGainDb(gainsDb).toStringAsFixed(1)}dB, '
            'gainsDb=${gainsDb.map((g) => g.toStringAsFixed(1)).join(",")}',
      );

      // A fresh AudioEffects each time, so the engine that is not selected is
      // left disabled rather than lingering in the chain alongside the one that
      // is — both applying the same curve would double it.
      await _player.setAudioEffects(effects);
    } catch (e, st) {
      AppLogger.e('PlayerEQ', 'EQ apply FAILED: $e', error: e, stackTrace: st);
    }
  }

  // ── Output gain, and ReplayGain ────────────────────────────────────
  //
  // mpv has exactly one volume-gain, and the last writer wins. The EQ owned it
  // outright until ReplayGain needed a say, and a second `setVolumeGain` caller
  // would not have layered on top — it would have silently thrown away the EQ's
  // headroom and put a boosted curve straight into clipping. Everything that
  // wants to move the output level goes through this one function.

  /// Applies the EQ's preamp and headroom, the ReplayGain offset for the
  /// playing track, and any fade currently in progress.
  Future<void> _applyVolumeGain() async {
    final total =
        _eqGainDb(_combinedEqGains()) + (_replayGainDb() ?? 0) + _fadeDb();
    _lastAppliedFadeDb = _fadeDb();
    // Nothing to say when nothing moved. This is called on every track change
    // for ReplayGain's sake, and mpv's own log showed the write landing inside
    // the gapless handover — writing a value it already holds is one more thing
    // touching the audio chain at the worst possible moment.
    if (_lastAppliedGainDb != null &&
        (total - _lastAppliedGainDb!).abs() < 0.01) {
      return;
    }
    _lastAppliedGainDb = total;
    await _player.setVolumeGain(total);
  }

  double _fadeDb() => fadeOffsetDb(
    position: state.position,
    duration: state.duration,
    fadeSeconds: _ref.read(playbackSettingsProvider).fadeSeconds,
  );

  /// Rides the output gain while a fade is in progress.
  ///
  /// Called on every position tick, so it re-applies only once the ramp has
  /// actually moved — a property set per frame for a value that has not changed
  /// is pure noise on the mpv side.
  void _updateFadeGain() {
    if (!_ref.read(playbackSettingsProvider).fading) return;
    if ((_fadeDb() - _lastAppliedFadeDb).abs() < 0.5) return;
    _applyVolumeGain();
  }

  /// The ReplayGain offset from the server's tags for the playing track, or
  /// null when the server gave none and mpv's own tag reading is in charge.
  double? _replayGainDb() {
    final song = state.currentSong;
    if (song == null) return null;
    return serverReplayGainDb(
      mode: _ref.read(playbackSettingsProvider).replayGain,
      trackGain: song.replayGainTrackGain,
      trackPeak: song.replayGainTrackPeak,
      albumGain: song.replayGainAlbumGain,
      albumPeak: song.replayGainAlbumPeak,
    );
  }

  // ── Transitions between tracks ─────────────────────────────────────

  void _initPlaybackSettings() {
    _playbackSub = _ref.listen<PlaybackSettings>(
      playbackSettingsProvider,
      (_, next) => _applyPlaybackSettings(next),
    );
    _applyPlaybackSettings(_ref.read(playbackSettingsProvider));
  }

  /// Pushes the transition settings at mpv.
  ///
  /// Prefetch is what actually buys gapless: it opens the next playlist entry
  /// while the current one is still playing, so the boundary is a decoder
  /// handover rather than a network round trip. It is only useful because the
  /// whole queue lives in mpv's playlist — see [_openQueue].
  Future<void> _applyPlaybackSettings(PlaybackSettings settings) async {
    try {
      await _player.setGapless(
        // `weak` rather than `yes`: strict gapless demands identical format,
        // sample rate and channel count across the boundary, and a library of
        // mixed FLAC and Opus does not have that. `weak` keeps the output open
        // when it can and tolerates the switch when it cannot, which is what a
        // mixed queue needs.
        settings.gaplessActive ? mpv.Gapless.weak : mpv.Gapless.no,
      );
      await _player.setPrefetchPlaylist(settings.gaplessActive);

      // mpv's own ReplayGain is the fallback path, used only for tracks the
      // server had no tags for. Where the server did supply them they are
      // already in the volume-gain above, and leaving this set as well would
      // apply the correction twice.
      await _player.setReplayGain(
        mpv.ReplayGainSettings(
          mode: switch (settings.replayGain) {
            ReplayGainMode.off => mpv.ReplayGain.no,
            ReplayGainMode.track => mpv.ReplayGain.track,
            ReplayGainMode.album => mpv.ReplayGain.album,
          },
          // Let mpv hold the level down rather than allowing it to clip; the
          // server-tag path does the same thing with the peak value.
          clip: false,
        ),
      );
      await _applyVolumeGain();
    } catch (e) {
      AppLogger.w('Player', 'Playback settings apply failed: $e');
    }
  }

  void _initAudioOutputSettings() {
    _audioOutputSub = _ref.listen<AudioOutputSettings>(
      audioOutputSettingsProvider,
      (_, next) => _applyAudioOutputSettings(next),
    );
    _applyAudioOutputSettings(_ref.read(audioOutputSettingsProvider));
  }

  Future<void> _applyAudioOutputSettings(AudioOutputSettings settings) async {
    try {
      if (Platform.isLinux) {
        if (settings.engine.aoValue.isNotEmpty) {
          await _player.setRawProperty('ao', settings.engine.aoValue);
        }
        await _player.setAudioMediaRole(true);
      }

      // Output device
      if (settings.deviceName == 'auto') {
        await _player.setAudioDevice(
          const mpv.Device(name: 'auto', description: 'System Default'),
        );
      } else {
        await _player.setAudioDevice(
          mpv.Device(
            name: settings.deviceName,
            description: settings.deviceDescription,
          ),
        );
      }

      // Exclusive mode
      await _player.setAudioExclusive(settings.exclusive);

      // Sample rate: mpv accepts integer Hz or '0' for auto/source rate
      final rateVal = switch (settings.sampleRate) {
        '44.1 kHz' => '44100',
        '48 kHz' => '48000',
        '88.2 kHz' => '88200',
        '96 kHz' => '96000',
        '192 kHz' => '192000',
        _ => '0',
      };
      await _player.setRawProperty('audio-samplerate', rateVal);

      // Bit depth / format: mpv accepts format strings ('s16', 's24', 'float')
      final formatVal = switch (settings.bitDepth) {
        '16-bit' => 's16',
        '24-bit' => 's24',
        '32-bit float' => 'float',
        _ => '',
      };
      if (formatVal.isNotEmpty) {
        await _player.setRawProperty('audio-format', formatVal);
      }
    } catch (e) {
      AppLogger.w('Player', 'Audio output settings apply failed: $e');
    }
  }

  /// Sample an AutoEQ GraphicEQ curve at [freq], interpolating in log-frequency
  /// space between the two surrounding points.
  static double _interpolateGain(List<GraphicEqPoint> pts, double freq) {
    if (pts.isEmpty) return 0;
    if (freq <= pts.first.frequency) return pts.first.gain;
    if (freq >= pts.last.frequency) return pts.last.gain;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (freq >= a.frequency && freq <= b.frequency) {
        final span = math.log(b.frequency) - math.log(a.frequency);
        if (span <= 0) return a.gain;
        final t = (math.log(freq) - math.log(a.frequency)) / span;
        return a.gain + (b.gain - a.gain) * t;
      }
    }
    return pts.last.gain;
  }

  // ── Rating and favorites for the playing track ────────────────────
  //
  // Applied optimistically and reverted if the server rejects it. The player
  // holds the only copy of the current song that the mini player and
  // now-playing screen read, so the local update has to happen here rather
  // than by invalidating some album provider — the track in the queue is what
  // is on screen.

  /// Sets the star rating (0-5) of the playing track.
  ///
  /// The queue is still this notifier's own list of [Song] objects rather than a
  /// view of the database, so the local copy is patched here as well. Once the
  /// queue reads from the database that second step goes away; until then a
  /// repository write alone would update every other screen and not this one.
  Future<void> rateCurrentSong(int rating) async {
    final song = state.currentSong;
    final repo = _ref.read(libraryRepositoryProvider);
    if (song == null || repo == null) return;

    _replaceSongInQueue(song.copyWith(userRating: rating));
    try {
      await repo.setRating(EntityRef(EntityType.song, song.id), rating: rating);
    } catch (e) {
      AppLogger.w('Player', 'setRating failed: $e');
      _replaceSongInQueue(song);
    }
  }

  /// Toggles the favorite (starred) flag of the playing track.
  Future<void> toggleCurrentSongStarred() async {
    final song = state.currentSong;
    final repo = _ref.read(libraryRepositoryProvider);
    if (song == null || repo == null) return;

    final next = !song.starred;
    _replaceSongInQueue(song.copyWith(starred: next));
    try {
      await repo.setFavorite(
        EntityRef(EntityType.song, song.id),
        favorite: next,
      );
    } catch (e) {
      AppLogger.w('Player', 'star/unstar failed: $e');
      _replaceSongInQueue(song);
    }
  }

  /// Swaps the song at the current queue position, keeping queue and
  /// currentSong consistent — they are separate fields and a mismatch shows up
  /// as the UI disagreeing with itself.
  void _replaceSongInQueue(Song song) {
    final queue = [...state.queue];
    final i = state.queueIndex;
    if (i >= 0 && i < queue.length) queue[i] = song;
    state = state.copyWith(currentSong: song, queue: queue);
    _debounceSaveQueue();
  }

  // ── Queue manipulation ─────────────────────────────────────────────

  /// Inserts [songs] directly after the playing track, leaving the rest of the
  /// queue in order — the "play next" of the album header, as distinct from
  /// [addToQueue], which appends to the end.
  void playNext(List<Song> songs) {
    if (songs.isEmpty) return;
    if (state.queue.isEmpty) {
      replaceQueue(songs);
      return;
    }
    final queue = [...state.queue];
    final at = (state.queueIndex + 1).clamp(0, queue.length);
    queue.insertAll(at, songs);
    state = state.copyWith(queue: queue);
    _insertIntoMpvQueue(songs, at);
    _debounceSaveQueue();
  }

  void addToQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    final newQueue = [...state.queue, ...songs];
    state = state.copyWith(queue: newQueue);
    _insertIntoMpvQueue(songs, state.queue.length - songs.length);
    _debounceSaveQueue();
  }

  /// Mirrors a queue insertion into mpv's playlist.
  ///
  /// Appended and then moved into place rather than reloaded: mpv has no
  /// insert, and reloading the playlist to add one track would restart whatever
  /// is playing. Anything that goes wrong here only costs the mirror, which
  /// [_playIndex] rebuilds on the next skip.
  Future<void> _insertIntoMpvQueue(List<Song> songs, int at) async {
    if (_mpvQueueIds.length + songs.length != state.queue.length) {
      // Already out of step with mpv; leave it to be rebuilt wholesale.
      _mpvQueueIds = const [];
      return;
    }
    try {
      final transcode = state.activeTranscode;
      final ids = [..._mpvQueueIds];
      for (var i = 0; i < songs.length; i++) {
        await _player.add(
          mpv.Media(_streamUri(songs[i], transcode).toString()),
        );
        final from = ids.length;
        final to = at + i;
        ids.insert(to, songs[i].id);
        if (from != to) await _player.move(from, to);
      }
      _mpvQueueIds = ids;
    } catch (e) {
      AppLogger.w('Player', 'Queue insert into mpv failed: $e');
      _mpvQueueIds = const [];
    }
  }

  Future<void> playTracks(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _resetScrobble();
    final idx = initialIndex.clamp(0, songs.length - 1);
    state = state.copyWith(
      queue: songs,
      queueIndex: idx,
      currentSong: songs[idx],
    );
    await _openQueue(songs, idx, play: true);
    _updateNowPlayingForSong(songs[idx]);
    _applyVolumeGain();
    _debounceSaveQueue();
    _audioHandler?.updateFromPlayerState(state);
  }

  Future<void> replaceQueue(List<Song> songs) async {
    await playTracks(songs, initialIndex: 0);
  }

  // ── Play queue persistence ──────────────────────────────────────────

  static const _prefsKeyQueue = 'flax_play_queue';
  static const _prefsKeyCurrentId = 'flax_play_queue_current';
  static const _prefsKeyPositionMs = 'flax_play_queue_position';
  static const _prefsKeyVolume = 'flax_volume';
  static const _prefsKeyMuted = 'flax_muted';

  Future<void> _restorePlayQueue() async {
    // Try server first, fall back to local
    final restored = await _restoreFromServer() || await _restoreFromLocal();
    if (!restored) {
      AppLogger.i('Player', 'No play queue to restore');
    }
  }

  Future<bool> _restoreFromServer() async {
    try {
      final client = _ref.read(subsonicClientProvider);
      if (client == null) return false;

      final pq = await client.getPlayQueue();
      if (pq == null || pq.songs.isEmpty) return false;

      await _applyRestoredQueue(pq.songs, pq.currentIndex, pq.positionMs);
      // Also save locally so offline restore works next time
      _saveLocal(pq.songs, pq.songs[pq.currentIndex].id, pq.positionMs);
      AppLogger.i(
        'Player',
        'Restored from server: ${pq.songs.length} songs, '
            'index=${pq.currentIndex}, position=${pq.positionMs}ms',
      );
      return true;
    } catch (e) {
      AppLogger.w('Player', 'Server restore failed: $e');
      return false;
    }
  }

  Future<bool> _restoreFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_prefsKeyQueue);
      if (queueJson == null) return false;

      final List<dynamic> decoded = jsonDecode(queueJson) as List<dynamic>;
      final songs = decoded
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
      if (songs.isEmpty) return false;

      final currentId = prefs.getString(_prefsKeyCurrentId);
      final positionMs = prefs.getInt(_prefsKeyPositionMs) ?? 0;

      int idx = 0;
      if (currentId != null) {
        final found = songs.indexWhere((s) => s.id == currentId);
        if (found >= 0) idx = found;
      }

      await _applyRestoredQueue(songs, idx, positionMs);
      AppLogger.i(
        'Player',
        'Restored from local: ${songs.length} songs, '
            'index=$idx, position=${positionMs}ms',
      );
      return true;
    } catch (e) {
      AppLogger.w('Player', 'Local restore failed: $e');
      return false;
    }
  }

  Future<void> _applyRestoredQueue(
    List<Song> songs,
    int idx,
    int positionMs,
  ) async {
    final song = songs[idx];
    final position = Duration(milliseconds: positionMs);

    state = state.copyWith(
      queue: songs,
      queueIndex: idx,
      currentSong: song,
      position: position,
      duration: Duration(seconds: song.duration),
    );

    // Open the queue paused at the saved position. The whole queue rather than
    // the one track, so pressing play resumes into a playlist mpv can already
    // prefetch from.
    try {
      await _openQueue(songs, idx, play: false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _player.seek(position);
    } catch (e) {
      // Offline — can't open stream, but state is set so UI shows the queue
      AppLogger.w('Player', 'Could not open stream (offline?): $e');
    }

    _lastSavedPositionSec = position.inSeconds;
    _lastNowPlayingSongId = null;
    _updateNowPlayingForSong(song, isPlaying: false, position: position);
  }

  void _debounceSaveQueue() {
    _saveQueueTimer?.cancel();
    _saveQueueTimer = Timer(const Duration(seconds: 2), _saveQueue);
  }

  Future<void> _saveQueue() async {
    final song = state.currentSong;
    if (song == null || state.queue.isEmpty) return;

    // Always save locally
    _saveLocal(state.queue, song.id, state.position.inMilliseconds);

    // Try to save to server
    try {
      final client = _ref.read(subsonicClientProvider);
      if (client == null) return;

      await client.savePlayQueue(
        state.queue.map((s) => s.id).toList(),
        song.id,
        state.position.inMilliseconds,
      );
    } catch (e) {
      AppLogger.w('Player', 'Failed to save play queue to server: $e');
    }
  }

  Future<void> _saveLocal(
    List<Song> songs,
    String currentId,
    int positionMs,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songsJson = jsonEncode(songs.map((s) => s.toJson()).toList());
      await prefs.setString(_prefsKeyQueue, songsJson);
      await prefs.setString(_prefsKeyCurrentId, currentId);
      await prefs.setInt(_prefsKeyPositionMs, positionMs);
    } catch (e) {
      AppLogger.w('Player', 'Failed to save play queue locally: $e');
    }
  }

  Future<void> play() async {
    if (mounted) {
      state = state.copyWith(clearPlaybackError: true);
    }
    if (state.queue.isNotEmpty && !_mpvQueueInSync) {
      await _openQueue(state.queue, state.queueIndex, play: true);
      if (state.position > Duration.zero) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _player.seek(state.position);
      }
    } else {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _saveQueue();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    var nextIndex = state.queueIndex + 1;
    if (nextIndex >= state.queue.length) {
      if (state.repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    await _playIndex(nextIndex);
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    var prevIndex = state.queueIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == RepeatMode.all) {
        prevIndex = state.queue.length - 1;
      } else {
        await seek(Duration.zero);
        return;
      }
    }
    await _playIndex(prevIndex);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // ── Volume ────────────────────────────────────────────────────────────
  //
  // mpv does not treat its `volume` property as a linear amplitude. From
  // mpv's audio_get_gain():
  //
  //     float gain = MPMAX(opts->softvol_volume / 100.0, 0);
  //     gain = pow(gain, 3);
  //     gain *= db_gain(opts->softvol_gain);
  //
  // so the property is *already* cubed on the way to the output. Passing the
  // fader position straight through (the old `setVolume(pos * 100)`) therefore
  // produced gain = pos^3: -18 dB at half travel and -36 dB at a quarter. Every
  // usable listening level was squeezed into the top of the fader and the
  // bottom half was effectively mute, which is what made small adjustments feel
  // by turns useless and drastic.
  //
  // Instead we impose our own taper. A fader that is *linear in dB* is
  // tempting — equal travel would give equal perceived change — but over any
  // range wide enough to reach a late-night level it puts mid-travel absurdly
  // low (-30 dB for a 60 dB range), and stacked on a low OS volume plus an
  // AutoEQ preamp of -6..-12 dB, half the fader is inaudible. Tried it; it
  // reads as "the volume cuts out halfway".
  //
  // So: a square-law taper, amplitude = pos^2, the conventional audio fader
  // curve. Half travel lands at -12 dB (a real, usable level), it still reaches
  // deep attenuation near the bottom, and it approaches silence continuously
  // rather than needing an artificial floor. Solving
  //
  //     (v/100)^3 = pos^kFaderAmplitudeExponent
  //
  // for v gives v = 100 * pos^(exponent/3).
  //
  //     pos 1.00 ->   0.0 dB      pos 0.30 -> -20.9 dB
  //     pos 0.75 ->  -2.5 dB      pos 0.20 -> -28.0 dB
  //     pos 0.50 -> -12.0 dB      pos 0.10 -> -40.0 dB
  //
  // Raise the exponent for a steeper fader, lower it for a flatter one; 2.0 is
  // the usual choice and 3.0 would reproduce mpv's own untreated curve.

  /// Exponent of the amplitude taper. 2.0 = square law.
  static const double kFaderAmplitudeExponent = 2.0;

  /// Fader position below which we snap to true silence, so that stepping down
  /// with the keyboard or scroll wheel can actually reach zero instead of
  /// chasing an asymptote. -60 dB under the square law.
  static const double _faderSilenceThreshold = 0.0316;

  /// Attenuation in dB for a fader position in (0, 1]. Returns null at zero,
  /// which is silence and has no finite dB value.
  static double faderToDb(double pos) {
    final clamped = pos.clamp(0.0, 1.0);
    return 20 * kFaderAmplitudeExponent * math.log(clamped) / math.ln10;
  }

  /// Inverse of [faderToDb]: the fader position that yields [db] attenuation.
  static double dbToFader(double db) =>
      math.pow(10, db / (20 * kFaderAmplitudeExponent)).toDouble();

  /// Fader position (0..1) to the value mpv's `volume` property wants (0..100),
  /// pre-compensated for mpv's internal cubing.
  static double faderToMpvVolume(double pos) {
    final clamped = pos.clamp(0.0, 1.0);
    if (clamped <= 0) return 0;
    return 100 * math.pow(clamped, kFaderAmplitudeExponent / 3.0).toDouble();
  }

  /// Sets the fader position. [volume] is a position in 0..1, not a gain.
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    // Moving the fader off zero is an unmute — matches every OS volume control.
    final unmute = state.muted && clamped > 0;
    state = state.copyWith(volume: clamped, muted: unmute ? false : null);
    if (unmute) await _player.setMute(false);
    await _player.setVolume(faderToMpvVolume(clamped));
    _saveVolume();
  }

  /// Nudges the fader by [deltaDb] decibels, for keyboard and scroll-wheel
  /// adjustment. Stepping in dB rather than in fader percent keeps every step
  /// the same perceived size, even though the fader itself is not dB-linear.
  Future<void> adjustVolumeDb(double deltaDb) async {
    if (state.volume <= 0 && deltaDb <= 0) return;
    // Stepping up from silence starts from the silence threshold rather than
    // from -infinity.
    final currentDb = state.volume <= 0
        ? faderToDb(_faderSilenceThreshold)
        : faderToDb(state.volume);
    final targetDb = math.min(currentDb + deltaDb, 0.0);
    final pos = dbToFader(targetDb);
    // Snap to true silence once stepping down passes the floor.
    await setVolume(pos <= _faderSilenceThreshold ? 0.0 : pos);
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    state = state.copyWith(muted: next);
    await _player.setMute(next);
    _saveVolume();
  }

  Future<void> _saveVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyVolume, state.volume);
      await prefs.setBool(_prefsKeyMuted, state.muted);
    } catch (e) {
      AppLogger.w('Player', 'Failed to save volume: $e');
    }
  }

  /// Volume is restored on launch; without this every start was full-scale
  /// regardless of where the fader was left.
  Future<void> _restoreVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pos = prefs.getDouble(_prefsKeyVolume);
      final muted = prefs.getBool(_prefsKeyMuted) ?? false;
      final clamped = (pos ?? 1.0).clamp(0.0, 1.0);
      state = state.copyWith(volume: clamped, muted: muted);
      await _player.setVolume(faderToMpvVolume(clamped));
      if (muted) await _player.setMute(true);
    } catch (e) {
      AppLogger.w('Player', 'Failed to restore volume: $e');
    }
  }

  /// Toggles the shuffle flag.
  ///
  /// Deliberately does *not* call mpv's own shuffle any more. That call was
  /// harmless while mpv only ever held the one file it was playing, but mpv now
  /// holds the whole queue, and shuffling it server-side would reorder the
  /// playlist out from under [_mpvQueueIds] — every index mpv reported after
  /// that would name the wrong song.
  ///
  /// Shuffle therefore still only sets a flag; ordering by it is unimplemented,
  /// exactly as it was before, and wants its own issue.
  Future<void> toggleShuffle() async {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  void setRepeatMode(RepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
    switch (mode) {
      case RepeatMode.one:
        _player.setLoop(mpv.Loop.file);
      case RepeatMode.off:
      case RepeatMode.all:
        _player.setLoop(mpv.Loop.off);
    }
  }

  void cycleRepeatMode() {
    final modes = RepeatMode.values;
    final nextMode = modes[(state.repeatMode.index + 1) % modes.length];
    setRepeatMode(nextMode);
  }

  Future<void> playTrackAt(int index) => _playIndex(index);

  @override
  void dispose() {
    _saveQueueTimer?.cancel();
    _saveQueue();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _nowPlaying.onPlay = null;
    _nowPlaying.onPause = null;
    _nowPlaying.onTogglePlayPause = null;
    _nowPlaying.onNext = null;
    _nowPlaying.onPrevious = null;
    _nowPlaying.onSeek = null;
    _nowPlaying.clear();
    _eqSub?.close();
    _autoEqSub?.close();
    _eqEngineSub?.close();
    _playbackSub?.close();
    _audioOutputSub?.close();
    _probe?.dispose();
    _player.dispose();
    super.dispose();
  }
}
