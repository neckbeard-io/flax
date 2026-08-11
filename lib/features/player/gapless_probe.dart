import 'dart:async';
import 'dart:io';

import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;

/// Whether the probe runs. Off unless asked for:
/// `tool/run_flax.sh --probe`, or `--dart-define=FLAX_GAPLESS_PROBE=true`.
const bool gaplessProbeEnabled = bool.fromEnvironment('FLAX_GAPLESS_PROBE');

/// Instrumentation for the boundary between two tracks.
///
/// Gapless is the one thing in this app that cannot be verified by looking at
/// it, and "sounds like a stutter" is not something to tune against. This turns
/// the boundary into three numbers and one yes/no:
///
/// - **the gap** — wall-clock milliseconds between the outgoing track being
///   fully consumed and the incoming one actually producing audio;
/// - **prefetch** — whether mpv reached [MpvPrefetchState.ready] before the
///   boundary and [MpvPrefetchState.used] at it. Anything else means the next
///   track was opened from scratch when playback reached it;
/// - **buffer** — how much audio the output device was holding to cover the
///   handover, which is the thing mpv's own manual says the whole feature
///   relies on;
/// - **reinit** — whether the output format changed across the boundary, which
///   is the only case where `--gapless-audio=weak` closes and reopens the
///   device.
///
/// Everything here is read-only. The probe never sets an mpv property, so a run
/// with it on is the same run with it off, plus logging.
class GaplessProbe {
  GaplessProbe(this._player, {this.log = _defaultLog});

  final mpv.Player _player;

  /// Where lines go. Injectable so the boundary arithmetic can be tested
  /// without libmpv.
  final void Function(String) log;

  /// Straight to stdout, not `developer.log`.
  ///
  /// A macOS Flutter binary run from a terminal shows `print` and raw stdout
  /// but swallows `developer.log`, which goes to the VM service instead — the
  /// rest of this app's logging is invisible when the app is launched the way
  /// you have to launch it to read a log at all.
  static void _defaultLog(String message) =>
      stdout.writeln('[gapless] $message');

  final List<StreamSubscription<dynamic>> _subs = [];

  /// When the current track was last seen still producing audio, and the
  /// position it was at. The pair is what makes a gap measurable: mpv stops
  /// emitting position while nothing is decoding, so the silence shows up as
  /// wall-clock time that the playhead did not account for.
  DateTime? _lastTick;
  Duration _lastPos = Duration.zero;

  int? _index;
  mpv.AudioParams? _outParams;
  mpv.MpvPrefetchState _prefetch = mpv.MpvPrefetchState.idle;
  bool _prefetchOn = false;

  /// mpv's own account of the boundary, kept in a short ring so the lines
  /// printed are the ones around the transition rather than the whole session.
  ///
  /// Timestamped on arrival, because the interesting quantity is not what mpv
  /// said but how long it went quiet between saying two things — the dead time
  /// between "audio EOF reached" on the outgoing track and "starting audio
  /// playback" on the incoming one *is* the stutter, and no Dart-side position
  /// tick is fine-grained enough to see it.
  final List<({DateTime at, String line})> _recentMpvLog = [];
  static const _mpvLogKeep = 120;

  /// How long to keep listening after mpv changes entry before printing.
  ///
  /// The playlist index moves before the new track produces a sample, so
  /// reporting immediately captures the run-up and misses the recovery — which
  /// is the half that says how long the silence lasted.
  static const _settleAfterBoundary = Duration(seconds: 2);
  Timer? _reportTimer;

  /// Subsystems worth keeping. mpv at debug level is far too chatty to print
  /// wholesale, and these are the ones that speak about the handover.
  static const _interestingPrefixes = {
    'ao',
    'ad',
    'cplayer',
    'demux',
    'stream',
    'ffmpeg',
    'af',
  };

  void start() {
    log('probe started — boundary timing, prefetch state, output format');

    _subs.add(
      _player.stream.position.listen((pos) {
        // Backwards means a seek or a new track, neither of which is a gap.
        if (pos >= _lastPos) {
          _lastTick = DateTime.now();
        }
        _lastPos = pos;
      }),
    );

    _subs.add(
      _player.stream.playlist.listen((playlist) {
        if (playlist.index == _index) return;
        final previous = _index;
        _index = playlist.index;
        if (previous != null) _reportBoundary(previous, playlist.index);
      }),
    );

    _subs.add(
      _player.stream.prefetchState.listen((state) {
        _prefetch = state;
        log('prefetch → ${state.name}');
      }),
    );

    _subs.add(
      _player.stream.prefetchPlaylist.listen((on) {
        _prefetchOn = on;
        log('prefetch-playlist = $on');
      }),
    );

    _subs.add(
      _player.stream.gapless.listen((g) {
        log('gapless-audio = ${g.mpvValue}');
      }),
    );

    _subs.add(
      _player.stream.audioOutParams.listen((params) {
        // The output side, not the decoder side: this is what the device is
        // actually opened with, and a change here is a device reinitialization.
        final previous = _outParams;
        _outParams = params;
        if (previous != null && !_sameFormat(previous, params)) {
          log(
            '!! output format changed: ${_describe(previous)} '
            '→ ${_describe(params)} — the device was reopened',
          );
        }
      }),
    );

    _subs.add(
      _player.stream.log.listen((entry) {
        if (!_interestingPrefixes.contains(entry.prefix)) return;
        _recentMpvLog.add((
          at: DateTime.now(),
          line: '[${entry.prefix}] ${entry.text}',
        ));
        if (_recentMpvLog.length > _mpvLogKeep) _recentMpvLog.removeAt(0);
      }),
    );
  }

  /// Waits for the transition to finish, then prints what it cost.
  void _reportBoundary(int from, int to) {
    final silence = gapSince(_lastTick, DateTime.now());
    _reportTimer?.cancel();
    _reportTimer = Timer(
      _settleAfterBoundary,
      () => _printBoundary(from, to, silence),
    );
  }

  Future<void> _printBoundary(int from, int to, Duration? silence) async {
    // Read rather than remembered: `audio-buffer` does not change, so the
    // property stream never emits it and the remembered value stays zero.
    final buffer = await _player.getRawProperty('audio-buffer') ?? '?';

    log('──── boundary $from → $to ────');
    log(
      'playhead gap ${silence?.inMilliseconds ?? -1}ms '
      '(coarse — position ticks only)',
    );
    log(
      'audio-buffer ${buffer}s, prefetch state=${_prefetch.name} '
      'enabled=$_prefetchOn',
    );
    log('output format: ${_describe(_outParams)}');
    log('mpv, with the pause before each line:');

    DateTime? previous;
    var worst = Duration.zero;
    String? worstLine;
    for (final entry in _recentMpvLog) {
      final delta = previous == null
          ? Duration.zero
          : entry.at.difference(previous);
      previous = entry.at;
      if (delta > worst) {
        worst = delta;
        worstLine = entry.line;
      }
      // Only the pauses are interesting; a burst of lines in the same
      // millisecond is mpv thinking, not mpv waiting.
      final gap = delta.inMilliseconds >= 10
          ? '+${delta.inMilliseconds}ms'.padLeft(9)
          : ' ' * 9;
      log('  $gap ${entry.line}');
    }
    if (worstLine != null) {
      log('longest stall ${worst.inMilliseconds}ms before: $worstLine');
    }
    _recentMpvLog.clear();
    log('──────────────────────────');
  }

  static bool _sameFormat(mpv.AudioParams a, mpv.AudioParams b) =>
      a.format == b.format &&
      a.sampleRate == b.sampleRate &&
      a.channelCount == b.channelCount;

  static String _describe(mpv.AudioParams? p) => p == null
      ? 'unknown'
      : '${p.format?.name ?? "?"} ${p.sampleRate ?? "?"}Hz '
            '${p.channelCount ?? "?"}ch';

  void dispose() {
    _reportTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }
}

/// Wall-clock time since audio was last known to be flowing.
///
/// Null when nothing has played yet. Pulled out as a plain function so the one
/// piece of arithmetic the probe's conclusions rest on can be tested; getting
/// this wrong would mean chasing a gap that was never there.
Duration? gapSince(DateTime? lastTick, DateTime now) {
  if (lastTick == null) return null;
  final elapsed = now.difference(lastTick);
  return elapsed.isNegative ? Duration.zero : elapsed;
}
