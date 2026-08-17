import 'dart:math' as math;

/// Smoothed throughput, and an ETA that refuses to guess early.
///
/// Both halves of that matter more here than they normally would, because the
/// bottleneck is someone else's server rather than us. Measured against a real
/// Navidrome while sizing issue #32: cover art fetched at **~20/s** cold, while
/// the server resized each image, and at **~290/s** on a second pass once its
/// own resize cache was warm. That is a 14x change in throughput *during a
/// single job*, driven by state we cannot observe.
///
/// So an ETA computed from the first few samples is not slightly wrong, it is
/// wrong by an order of magnitude — and one computed from late samples was
/// wrong for most of the run. The response is to smooth hard and to say nothing
/// at all until there is something worth saying.
class RateEstimator {
  RateEstimator({
    this.halfLife = const Duration(seconds: 5),
    this.warmup = const Duration(seconds: 10),
  });

  /// How quickly the average forgets. A step change in throughput is half
  /// absorbed after this long.
  final Duration halfLife;

  /// No ETA is offered until the job has been running at least this long.
  /// Rate is still reported during warmup — a live number is honest, a
  /// countdown built on two samples is not.
  final Duration warmup;

  DateTime? _firstAt;
  DateTime? _lastAt;
  int? _lastDone;
  double? _rate;

  /// Feed a cumulative progress reading. [done] is total-so-far, not a delta.
  void sample(int done, DateTime at) {
    _firstAt ??= at;

    final lastAt = _lastAt;
    final lastDone = _lastDone;
    _lastAt = at;
    _lastDone = done;

    if (lastAt == null || lastDone == null) return;

    final elapsed = at.difference(lastAt).inMicroseconds / 1e6;
    // Two readings in the same instant carry no rate information, and dividing
    // by the gap would be a divide by zero.
    if (elapsed <= 0) return;

    // Progress should never go backwards, but a re-enumeration or a retry could
    // make it look like it does. Treat that as no progress rather than as a
    // negative rate that would poison the average.
    final delta = math.max(0, done - lastDone);
    final instant = delta / elapsed;

    final previous = _rate;
    if (previous == null) {
      _rate = instant;
      return;
    }

    // Time-aware exponential smoothing: the weight of the new sample depends on
    // how long it has been, so an irregular reporting cadence (which every one
    // of these jobs has) does not change how fast the average moves.
    final tau = halfLife.inMicroseconds / 1e6 / math.ln2;
    final alpha = 1 - math.exp(-elapsed / tau);
    _rate = previous + alpha * (instant - previous);
  }

  /// Units per second, or null before two readings exist.
  double? get ratePerSecond => _rate;

  /// How long the job has been reporting.
  Duration elapsedSince(DateTime now) {
    final first = _firstAt;
    return first == null ? Duration.zero : now.difference(first);
  }

  /// Time to reach [total], or null when there is nothing trustworthy to say.
  ///
  /// Null during [warmup], null without a rate, null once the rate has decayed
  /// to a standstill — an ETA of "about 4 hours" because the network dropped
  /// for ten seconds is worse than no ETA.
  Duration? etaTo(int total, DateTime now) {
    final rate = _rate;
    final done = _lastDone;
    if (rate == null || done == null) return null;
    if (elapsedSince(now) < warmup) return null;
    if (rate <= 0) return null;

    final remaining = total - done;
    if (remaining <= 0) return Duration.zero;

    final seconds = remaining / rate;
    // Anything past a day is not an estimate, it is a shrug.
    if (seconds > Duration.secondsPerDay) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
