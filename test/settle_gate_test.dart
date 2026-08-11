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

  testWidgets('rows visible at rest mount immediately', (tester) async {
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

    // The list is stationary on first build, so what is on screen loads at once.
    expect(mounted, isNotEmpty);
    expect(mounted.first, 0);
  });

  testWidgets('a fling mounts far fewer rows than an open gate would', (
    tester,
  ) async {
    // Measured against a zero-delay gate running the identical fling, rather
    // than against a fixed number: what matters is how much the gate withholds,
    // and a hard threshold would just pin Flutter's fling physics in place.
    Future<int> mountsDuringFling(Duration delay) async {
      final mounted = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 2000,
              itemBuilder: (context, i) => SizedBox(
                height: 100,
                child: SettleGate(
                  delay: delay,
                  placeholder: const SizedBox.expand(),
                  child: _RecordMount(index: i, onMount: mounted.add),
                ),
              ),
            ),
          ),
        ),
      );
      final atRest = mounted.length;
      await tester.fling(find.byType(ListView), const Offset(0, -8000), 12000);
      await tester.pumpAndSettle();
      return mounted.length - atRest;
    }

    final open = await mountsDuringFling(Duration.zero);
    final gated = await mountsDuringFling(const Duration(milliseconds: 300));

    expect(
      open,
      greaterThan(50),
      reason: 'the fling has to travel for this test to mean anything',
    );
    // Every withheld mount is a download never queued ahead of the rows the
    // list actually came to rest on.
    expect(
      gated,
      lessThan(open ~/ 2),
      reason: 'the gate must withhold most of what a fling flies past',
    );
  });

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
