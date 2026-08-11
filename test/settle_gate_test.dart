import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/widgets/settle_gate.dart';

/// [SettleGate] stands between a list row and the network request its artwork
/// would make. The download queue under `CachedNetworkImage` is FIFO and cannot
/// be cancelled, so the only way to stop a fling from filling it with rows you
/// have already passed is to never ask in the first place.
///
/// Tested with a plain [Text] rather than a [CoverArtImage], so these run
/// without a server, a client provider, or an image cache — what matters is
/// *when* the child is allowed to mount, which is all the gate decides.
void main() {
  /// Counts mounts, which is what starting a request corresponds to.
  Widget row(int index, List<int> mounted) => SizedBox(
    height: 100,
    child: SettleGate(
      placeholder: const SizedBox.expand(),
      child: _RecordMount(index: index, onMount: mounted.add),
    ),
  );

  testWidgets('a child outside any scrollable mounts immediately', (
    tester,
  ) async {
    final mounted = <int>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: row(0, mounted))));

    // Nothing is scrolling, so there is no reason to wait — a static screen
    // must not pay for the list's problem.
    expect(mounted, [0]);
  });

  testWidgets('rows in a stationary list load after the quiet window', (
    tester,
  ) async {
    final mounted = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 100,
            itemBuilder: (context, i) => row(i, mounted),
          ),
        ),
      ),
    );

    // The accepted cost of watching for movement rather than asking whether the
    // list is scrolling: a gate inside a scrollable cannot tell "at rest since
    // startup" from "a wheel notch moved us a moment ago", so it waits either
    // way. One quiet window against a network fetch of several hundred
    // milliseconds, and it buys correctness for wheel scrolling.
    expect(mounted, isEmpty, reason: 'not before the quiet window elapses');

    await tester.pump(const Duration(milliseconds: 200));
    expect(mounted, isNotEmpty);
    expect(mounted.first, 0);
  });

  /// Scrolls [how] and returns how many rows mounted during it. [gated] false
  /// builds the child directly, which is the honest baseline: a zero-duration
  /// timer still fires late enough to look like withholding.
  Future<int> mountsWhileScrolling(
    WidgetTester tester,
    String how, {
    required bool gated,
  }) async {
    final mounted = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 3000,
            itemBuilder: (context, i) {
              final child = _RecordMount(index: i, onMount: mounted.add);
              return SizedBox(
                height: 100,
                child: gated
                    ? SettleGate(
                        placeholder: const SizedBox.expand(),
                        child: child,
                      )
                    : child,
              );
            },
          ),
        ),
      ),
    );
    final atRest = mounted.length;
    final centre = tester.getCenter(find.byType(ListView));

    switch (how) {
      case 'wheel':
        // A mouse wheel, and a discrete trackpad scroll: PointerScrollEvents.
        // This is the case an `isScrollingNotifier` check silently missed —
        // pointerScroll sets that flag and clears it again inside the pointer
        // handler, before layout builds the rows it just revealed.
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(centre));
        for (var i = 0; i < 60; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 250)));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await tester.pumpAndSettle();
      case 'trackpad':
        // macOS two-finger scrolling arrives as pan/zoom events.
        final pointer = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(pointer.panZoomStart(centre));
        var total = Offset.zero;
        for (var i = 0; i < 60; i++) {
          total += const Offset(0, -250);
          await tester.sendEventToBinding(
            pointer.panZoomUpdate(centre, pan: total),
          );
          await tester.pump(const Duration(milliseconds: 8));
        }
        await tester.sendEventToBinding(pointer.panZoomEnd());
        await tester.pumpAndSettle();
      case 'touchfling':
        // A phone flick: drag plus momentum.
        await tester.fling(
          find.byType(ListView),
          const Offset(0, -8000),
          12000,
        );
        await tester.pumpAndSettle();
    }
    return mounted.length - atRest;
  }

  // Every input, because they take different paths through ScrollPosition and
  // the first version of this gate worked for only two of the three.
  for (final how in ['touchfling', 'wheel', 'trackpad']) {
    testWidgets('$how withholds most of what it scrolls past', (tester) async {
      final open = await mountsWhileScrolling(tester, how, gated: false);
      final gated = await mountsWhileScrolling(tester, how, gated: true);

      expect(
        open,
        greaterThan(50),
        reason: '$how has to actually travel for this to mean anything',
      );
      // Compared against an ungated list rather than a fixed count, so the
      // assertion measures the gate rather than pinning Flutter's scroll physics.
      expect(
        gated,
        lessThan(open ~/ 2),
        reason: 'most rows scrolled past must never have mounted ($how)',
      );
    });
  }

  testWidgets('rows the list comes to rest on do mount', (tester) async {
    final mounted = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 500,
            itemBuilder: (context, i) => row(i, mounted),
          ),
        ),
      ),
    );

    await tester.fling(find.byType(ListView), const Offset(0, -8000), 12000);
    await tester.pumpAndSettle();

    // The point of the whole exercise: whatever is on screen after the fling
    // has loaded, rather than waiting behind the rows that were skipped.
    final onScreen = tester
        .widgetList<_RecordMount>(find.byType(_RecordMount))
        .map((w) => w.index);
    expect(onScreen, isNotEmpty);
    for (final index in onScreen) {
      expect(mounted, contains(index));
    }
  });

  testWidgets('a slow drag still loads, rather than starving', (tester) async {
    final mounted = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 500,
            itemBuilder: (context, i) => row(i, mounted),
          ),
        ),
      ),
    );
    final before = mounted.length;

    // Dragging in small steps keeps the scrollable "scrolling" the whole time,
    // which is the case a wait-for-stop rule would starve. Rows stay on screen
    // longer than the delay, so they must load.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(mounted.length, greaterThan(before));
  });
}

/// Reports the moment it mounts — the stand-in for a request being made.
class _RecordMount extends StatefulWidget {
  const _RecordMount({required this.index, required this.onMount});

  final int index;
  final void Function(int) onMount;

  @override
  State<_RecordMount> createState() => _RecordMountState();
}

class _RecordMountState extends State<_RecordMount> {
  @override
  void initState() {
    super.initState();
    widget.onMount(widget.index);
  }

  @override
  Widget build(BuildContext context) => Text('${widget.index}');
}
