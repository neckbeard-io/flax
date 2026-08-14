import 'dart:async';

/// Runs an async action without ever letting two runs overlap, re-running once
/// afterwards if it was asked again while busy.
///
/// For work that pushes current state somewhere slow, where **the last request
/// must win rather than the last completion**. Two overlapping runs each read
/// state at a different moment and finish in whatever order the far end
/// decides, so the value left behind is whichever call happened to land last —
/// which is not necessarily the newest.
///
/// That is not hypothetical. The equalizer applied it to mpv this way and the EQ
/// came up silently off (#35): three applies raced at launch, the earliest of
/// them read the not-yet-loaded "EQ off" default, and it reached mpv last.
///
/// Guarantees:
///
/// - one action at a time, never two in flight;
/// - a request arriving mid-flight causes exactly one more run afterwards,
///   however many arrive — bursts coalesce rather than queueing up;
/// - that final run starts after the previous finished, so an action that reads
///   current state sees the newest.
///
/// It does *not* promise every request gets its own run. Callers wanting that
/// want a queue, not this.
class CoalescingRunner {
  bool _running = false;
  bool _again = false;

  /// True while an action is in flight. Exposed for assertions and tests rather
  /// than for branching on.
  bool get isRunning => _running;

  /// Runs [action], or notes that it should run again if one is already going.
  ///
  /// Returns when this call's work is done: immediately for a coalesced request,
  /// since the run that will cover it belongs to another caller. If [action]
  /// throws, the error propagates and the runner is left usable.
  Future<void> run(Future<void> Function() action) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await action();
      } while (_again);
    } finally {
      _running = false;
      _again = false;
    }
  }
}
