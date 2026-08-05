import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/settings/equalizer_screen.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';
import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/services/platform/now_playing_service.dart';

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
  });

  /// Attenuation the current fader position corresponds to, in dB, or null at
  /// the very bottom of the fader (true silence, which has no finite dB value).
  double? get volumeDb =>
      volume <= 0 ? null : PlayerNotifier.faderToDb(volume);

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
    );
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final notifier = PlayerNotifier(ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  final mpv.Player _player;
  final NowPlayingService _nowPlaying;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _lastNowPlayingSongId;
  Timer? _saveQueueTimer;
  int _lastSavedPositionSec = -1;
  ProviderSubscription<EqState>? _eqSub;
  ProviderSubscription<AutoEqState>? _autoEqSub;

  PlayerNotifier(this._ref)
      : _player = mpv.Player(),
        _nowPlaying = _ref.read(nowPlayingServiceProvider),
        super(const PlayerState()) {
    _initStreams();
    _initMediaKeys();
    _initEqListener();
    _restoreVolume();
    _restorePlayQueue();
  }

  void _initMediaKeys() {
    _nowPlaying.onPlay = () => play();
    _nowPlaying.onPause = () => pause();
    _nowPlaying.onTogglePlayPause = () => togglePlayPause();
    _nowPlaying.onNext = () => next();
    _nowPlaying.onPrevious = () => previous();
    _nowPlaying.onSeek = (pos) => seek(pos);
  }

  void _initStreams() {
    _subs.add(_player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
        _nowPlaying.updatePlaybackState(
          position: state.position,
          isPlaying: playing,
        );
      }
    }));
    _subs.add(_player.stream.position.listen((pos) {
      if (mounted) {
        state = state.copyWith(position: pos);
        // Save queue position every 10 seconds of playback change
        final currentSec = pos.inSeconds;
        if ((currentSec - _lastSavedPositionSec).abs() >= 10) {
          _lastSavedPositionSec = currentSec;
          _debounceSaveQueue();
        }
      }
    }));
    _subs.add(_player.stream.duration.listen((dur) {
      if (mounted) state = state.copyWith(duration: dur);
    }));
    _subs.add(_player.stream.buffering.listen((buf) {
      if (mounted) state = state.copyWith(buffering: buf);
    }));
    _subs.add(_player.stream.completed.listen((completed) {
      if (mounted && completed) {
        _onTrackCompleted();
      }
    }));
  }

  void _onTrackCompleted() {
    if (state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      play();
      return;
    }
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
      developer.log('Queue-finished reset failed: $e', name: 'PlayerNotifier');
    }
    if (!mounted) return;
    state = state.copyWith(position: Duration.zero, isPlaying: false);
  }

  Uri _streamUri(Song song) {
    final client = _ref.read(subsonicClientProvider);
    if (client == null) {
      throw Exception('No server connected');
    }
    return client.getStreamUri(song.id);
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final song = state.queue[index];
    state = state.copyWith(
      currentSong: song,
      queueIndex: index,
    );
    final uri = _streamUri(song);
    await _openAndPlay(uri);
    _updateNowPlayingForSong(song);
    _debounceSaveQueue();
  }

  /// Loads [uri] and starts it.
  ///
  /// `open(play: true)` already asks mpv to unpause, but the follow-up
  /// [Player.play] is deliberate rather than redundant: it is documented as
  /// idempotent, and it makes "start playing" hold even when the player was
  /// parked somewhere unusual beforehand — the end-of-queue case being the one
  /// that actually bit. Cheap insurance against a load that lands paused.
  Future<void> _openAndPlay(Uri uri) async {
    await _player.open(mpv.Media(uri.toString()), play: true);
    await _player.play();
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    final newQueue = queue ?? [song];
    final newIndex = index ?? 0;
    state = state.copyWith(
      queue: newQueue,
      queueIndex: newIndex,
      currentSong: newQueue[newIndex],
    );
    final uri = _streamUri(newQueue[newIndex]);
    await _openAndPlay(uri);
    _updateNowPlayingForSong(newQueue[newIndex]);
    _debounceSaveQueue();
  }

  void _updateNowPlayingForSong(Song song) {
    if (song.id == _lastNowPlayingSongId) return;
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
      position: Duration.zero,
      duration: state.duration,
      isPlaying: true,
      artUrl: artUrl,
    );
  }

  // ── EQ ────────────────────────────────────────────────────────────

  void _initEqListener() {
    _eqSub = _ref.listen<EqState>(eqProvider, (_, __) {
      _applyEq();
    });
    _autoEqSub = _ref.listen<AutoEqState>(autoEqProvider, (_, __) {
      _applyEq();
    });
    // Apply initial state
    _applyEq();
  }

  Future<void> _applyEq() async {
    final eq = _ref.read(eqProvider);
    final autoEq = _ref.read(autoEqProvider);

    try {
      // Accumulate per-band gain in dB. Our 18 EQ bands are exactly the
      // superequalizer bands, so band i maps to key '${i + 1}b'.
      final gainsDb = List<double>.filled(_superEqBandCount, 0);

      if (eq.enabled) {
        for (var i = 0; i < eq.bands.length && i < _superEqBandCount; i++) {
          gainsDb[i] += eq.bands[i].gain;
        }
      }

      // AutoEQ correction sums on top of the manual curve.
      final profile = autoEq.activeProfile;
      if (profile != null && profile.points.isNotEmpty) {
        for (var i = 0; i < _superEqBandCount; i++) {
          gainsDb[i] += _interpolateGain(
            profile.points,
            _superEqBandFrequencies[i],
          );
        }
      }

      // Headroom. superequalizer amplifies for real, and AutoEQ curves
      // routinely carry bass shelves of +6 dB or more, so a boosted band on
      // already-loud material clips audibly. Pull the whole chain down by the
      // largest boost in the combined curve, which costs loudness but is the
      // only way a positive band can be honoured cleanly. Manual preamp is
      // applied on top, and both go through mpv's volume-gain (dB).
      final maxBoostDb =
          gainsDb.fold<double>(0, (m, g) => g > m ? g : m);
      final preampDb = (eq.enabled ? eq.preamp : 0.0) - maxBoostDb;
      await _player.setVolumeGain(preampDb);

      final active = gainsDb.any((g) => g != 0);

      // superequalizer takes LINEAR multipliers (0..20, 1.0 = 0 dB).
      final params = <String, double>{};
      if (active) {
        for (var i = 0; i < _superEqBandCount; i++) {
          params['${i + 1}b'] =
              math.pow(10.0, gainsDb[i] / 20.0).toDouble().clamp(0.0, 20.0);
        }
      }

      developer.log(
        'EQ apply: enabled=${eq.enabled}, gain=${preampDb.toStringAsFixed(1)}dB '
        '(headroom ${(-maxBoostDb).toStringAsFixed(1)}dB), active=$active, '
        'autoEq=${profile?.name ?? "none"}'
        '${profile != null ? " (${profile.points.length} pts)" : ""}, '
        'gainsDb=${gainsDb.map((g) => g.toStringAsFixed(1)).join(",")}',
        name: 'PlayerEQ',
      );

      await _player.setAudioEffects(
        const mpv.AudioEffects().copyWith(
          superequalizer: mpv.SuperequalizerSettings(
            enabled: active,
            params: params,
          ),
        ),
      );
    } catch (e, st) {
      developer.log('EQ apply FAILED: $e\n$st', name: 'PlayerEQ');
    }
  }

  static const _superEqBandCount = 18;

  /// superequalizer band centre frequencies (Hz).
  static const _superEqBandFrequencies = <double>[
    65, 92, 131, 185, 262, 370, 523, 740, 1047,
    1480, 2093, 2960, 4186, 5920, 8372, 11840, 16744, 20000,
  ];

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

  // ── Rating and favourites for the playing track ────────────────────
  //
  // Applied optimistically and reverted if the server rejects it. The player
  // holds the only copy of the current song that the mini player and
  // now-playing screen read, so the local update has to happen here rather
  // than by invalidating some album provider — the track in the queue is what
  // is on screen.

  /// Sets the star rating (0-5) of the playing track.
  Future<void> rateCurrentSong(int rating) async {
    final song = state.currentSong;
    final client = _ref.read(subsonicClientProvider);
    if (song == null || client == null) return;

    _replaceSongInQueue(song.copyWith(userRating: rating));
    try {
      await client.setRating(song.id, rating);
    } catch (e) {
      developer.log('setRating failed: $e', name: 'PlayerNotifier');
      _replaceSongInQueue(song);
    }
  }

  /// Toggles the favourite (starred) flag of the playing track.
  Future<void> toggleCurrentSongStarred() async {
    final song = state.currentSong;
    final client = _ref.read(subsonicClientProvider);
    if (song == null || client == null) return;

    final next = !song.starred;
    _replaceSongInQueue(song.copyWith(starred: next));
    try {
      if (next) {
        await client.star(id: song.id);
      } else {
        await client.unstar(id: song.id);
      }
    } catch (e) {
      developer.log('star/unstar failed: $e', name: 'PlayerNotifier');
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

  void addToQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    final newQueue = [...state.queue, ...songs];
    state = state.copyWith(queue: newQueue);
    _debounceSaveQueue();
  }

  Future<void> replaceQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    state = state.copyWith(queue: songs, queueIndex: 0, currentSong: songs.first);
    final uri = _streamUri(songs.first);
    await _openAndPlay(uri);
    _updateNowPlayingForSong(songs.first);
    _debounceSaveQueue();
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
      developer.log('No play queue to restore', name: 'PlayerNotifier');
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
      developer.log(
        'Restored from server: ${pq.songs.length} songs, '
        'index=${pq.currentIndex}, position=${pq.positionMs}ms',
        name: 'PlayerNotifier',
      );
      return true;
    } catch (e) {
      developer.log('Server restore failed: $e', name: 'PlayerNotifier');
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
      developer.log(
        'Restored from local: ${songs.length} songs, '
        'index=$idx, position=${positionMs}ms',
        name: 'PlayerNotifier',
      );
      return true;
    } catch (e) {
      developer.log('Local restore failed: $e', name: 'PlayerNotifier');
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

    // Open the track paused at the saved position
    try {
      final uri = _streamUri(song);
      await _player.open(mpv.Media(uri.toString()), play: false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _player.seek(position);
    } catch (e) {
      // Offline — can't open stream, but state is set so UI shows the queue
      developer.log(
        'Could not open stream (offline?): $e',
        name: 'PlayerNotifier',
      );
    }

    _lastNowPlayingSongId = song.id;
    _lastSavedPositionSec = position.inSeconds;
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
      developer.log('Failed to save play queue to server: $e',
          name: 'PlayerNotifier');
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
      developer.log('Failed to save play queue locally: $e',
          name: 'PlayerNotifier');
    }
  }

  Future<void> play() async {
    await _player.play();
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
    return 100 *
        math.pow(clamped, kFaderAmplitudeExponent / 3.0).toDouble();
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
      developer.log('Failed to save volume: $e', name: 'PlayerNotifier');
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
      developer.log('Failed to restore volume: $e', name: 'PlayerNotifier');
    }
  }

  Future<void> toggleShuffle() async {
    final newShuffle = !state.shuffle;
    state = state.copyWith(shuffle: newShuffle);
    await _player.setShuffle(newShuffle);
  }

  void cycleRepeatMode() {
    final modes = RepeatMode.values;
    final nextMode = modes[(state.repeatMode.index + 1) % modes.length];
    state = state.copyWith(repeatMode: nextMode);
    // Loop is managed at the Flax level for queue repeat;
    // single-track repeat uses mpv Loop.one
    switch (nextMode) {
      case RepeatMode.one:
        _player.setLoop(mpv.Loop.file);
      case RepeatMode.off:
      case RepeatMode.all:
        _player.setLoop(mpv.Loop.off);
    }
  }

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
    _player.dispose();
    super.dispose();
  }
}
