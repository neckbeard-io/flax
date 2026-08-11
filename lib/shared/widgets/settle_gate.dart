import 'dart:async';

import 'package:flutter/widgets.dart';

/// Holds [child] back while the list it sits in is moving, so a fast scroll past
/// a thousand rows does not queue a thousand network requests.
///
/// **The problem this exists for.** `flutter_cache_manager` — under
/// `CachedNetworkImage`, and so under `CoverArtImage` — keeps one strict FIFO
/// queue of downloads, runs ten at a time, and cannot cancel a request once it is
/// queued. Disposing the widget that asked does not withdraw it. Race down the
/// artist list and every row built on the way enqueues a thumbnail; when you
/// stop, the rows actually on screen sit at the *back* of that queue, so they
/// appear only after everything you scrolled past has downloaded. The art arrives
/// in the order you flew over rather than the order you need it.
///
/// Since the request cannot be recalled, the fix is to not make it. A scrolling
/// [ListView] disposes children as they leave the viewport, so a child that waits
/// before mounting is never asked for during a fast scroll — the queue only fills
/// with rows the list came to rest on.
///
/// **Two clocks, because one is not enough.** The gate opens when either:
///
/// - the scroll position has not moved for [quiet] — the list has stopped, so
///   whatever survived should load now; or
/// - the row has been alive for [maxWait] regardless — a slow, deliberate drag
///   never goes quiet, and that is exactly when you are reading the rows and most
///   want the art. Waiting only for quiet would starve it forever.
///
/// **Why it watches for movement rather than asking whether it is scrolling.**
/// The obvious check — `position.isScrollingNotifier.value` at build time — is
/// wrong for mouse wheels and discrete trackpad scrolls, and silently so.
/// [ScrollPositionWithSingleContext.pointerScroll] sets that flag true, moves the
/// pixels, then calls `goBallistic(0.0)` which goes idle and sets it back to
/// false — all synchronously, inside the pointer handler, which completes before
/// layout builds the newly revealed rows. Those rows therefore see "not
/// scrolling" and load immediately. Measured, flinging a 2000-row list and
/// counting how many rows flown past still fetched:
///
/// | how                   | isScrollingNotifier | watching for movement |
/// | --------------------- | ------------------- | --------------------- |
/// | touch fling (phone)   | 74% withheld        | 89% withheld          |
/// | mouse wheel           | **0% withheld**     | 100% withheld         |
/// | trackpad two-finger   | 100% withheld       | 100% withheld         |
/// | slow drag             | loads               | loads                 |
///
/// Every input matters: desktop is trackpad or wheel, and a phone is touch drag
/// plus fling. The old check happened to work for two of the four and did nothing
/// at all for the wheel, which is the failure mode that made this worth fixing
/// properly rather than tuning a delay.
///
/// **What this costs.** A gate inside a scrollable cannot tell "at rest since the
/// screen opened" from "a wheel notch moved us a moment ago" — telling those apart
/// needs a record of when the position last moved, and the instantaneous flag that
/// would seem to provide it is the very thing that is wrong for wheels. So rows in
/// a stationary list also wait one [quiet] window. That is 150ms against a cover-art
/// fetch measured at 300–550ms, and it buys correctness for the input that had none.
/// Anything not inside a scrollable — the now-playing art, the mini player — opens
/// immediately and pays nothing.
///
/// [child] is constructed by the caller either way, which is free — a widget is a
/// description. The request begins when the element mounts, which is what this
/// defers.
class SettleGate extends StatefulWidget {
  const SettleGate({
    super.key,
    required this.child,
    required this.placeholder,
    this.quiet = const Duration(milliseconds: 150),
    this.maxWait = const Duration(milliseconds: 900),
    this.bypass = false,
  });

  final Widget child;

  /// Shown while the gate is shut. Should be the same size as [child], or the
  /// list reflows when it opens.
  final Widget placeholder;

  /// How still the list must be before a surviving row may load. Short, because
  /// this is the delay you feel when you stop scrolling — five frames.
  final Duration quiet;

  /// The longest a row waits when the list never goes still, so a continuous slow
  /// drag still fills in. Long enough that a fast scroll disposes rows first.
  final Duration maxWait;

  /// Opens the gate at once, for a [child] that has nothing to wait for.
  ///
  /// The gate exists to stop *network requests* being queued for rows you scroll
  /// past. A child whose image is already decoded in memory makes no request, so
  /// waiting buys nothing and costs a visible stutter every time you scroll back
  /// over art you were just looking at. Callers that can tell cheaply — see
  /// `CoverArtImage` asking [ImageCache] — should say so here.
  final bool bypass;

  @override
  State<SettleGate> createState() => _SettleGateState();
}

class _SettleGateState extends State<SettleGate> {
  bool _open = false;
  Timer? _quietTimer;
  Timer? _maxTimer;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open) return;
    if (widget.bypass) {
      _open = true;
      return;
    }

    final position = Scrollable.maybeOf(context)?.position;
    // Nothing to scroll means nothing to wait for: a static screen must not pay
    // for the list's problem.
    if (position == null) {
      _open = true;
      return;
    }
    if (position == _position) return;

    _position?.removeListener(_onScroll);
    _position = position..addListener(_onScroll);
    _quietTimer = Timer(widget.quiet, _openGate);
    _maxTimer = Timer(widget.maxWait, _openGate);
  }

  /// Any movement means the list is still going, so the quiet clock restarts.
  /// [maxWait] deliberately does not restart — it is the guarantee that a row
  /// which stays on screen eventually loads however long the scrolling lasts.
  void _onScroll() {
    if (_open) return;
    _quietTimer?.cancel();
    _quietTimer = Timer(widget.quiet, _openGate);
  }

  void _openGate() {
    if (_open || !mounted) return;
    _quietTimer?.cancel();
    _maxTimer?.cancel();
    _position?.removeListener(_onScroll);
    setState(() => _open = true);
  }

  @override
  void dispose() {
    _quietTimer?.cancel();
    _maxTimer?.cancel();
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _open ? widget.child : widget.placeholder;
}
