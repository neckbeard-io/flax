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
  final double volume;
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
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.buffering = false,
  });

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? queueIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
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
    }
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
    await _player.open(mpv.Media(uri.toString()), play: true);
    _updateNowPlayingForSong(song);
    _debounceSaveQueue();
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
    await _player.open(mpv.Media(uri.toString()), play: true);
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
      // Preamp via mpv's native volume-gain property (dB)
      final preampDb = eq.enabled ? eq.preamp : 0.0;
      await _player.setVolumeGain(preampDb);

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
        'EQ apply: enabled=${eq.enabled}, preamp=${preampDb}dB, '
        'active=$active, autoEq=${profile?.name ?? "none"}, '
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

  // ── Queue manipulation ─────────────────────────────────────────────

  void addToQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    final newQueue = [...state.queue, ...songs];
    state = state.copyWith(queue: newQueue);
    _debounceSaveQueue();
  }

  void replaceQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    state = state.copyWith(queue: songs, queueIndex: 0, currentSong: songs.first);
    final uri = _streamUri(songs.first);
    _player.open(mpv.Media(uri.toString()), play: true);
    _updateNowPlayingForSong(songs.first);
    _debounceSaveQueue();
  }

  // ── Play queue persistence ──────────────────────────────────────────

  static const _prefsKeyQueue = 'flax_play_queue';
  static const _prefsKeyCurrentId = 'flax_play_queue_current';
  static const _prefsKeyPositionMs = 'flax_play_queue_position';

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

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _player.setVolume(clamped * 100);
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
