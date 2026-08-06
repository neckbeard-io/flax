import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/player/seek_bar.dart';

const _duration = Duration(minutes: 4); // 240s, so fractions are easy to read.

Future<List<Duration>> _pumpBar(
  WidgetTester tester, {
  Duration position = const Duration(seconds: 30),
  bool inlineLabels = false,
  Duration duration = _duration,
}) async {
  final seeks = <Duration>[];
  tester.view.physicalSize = const ui.Size(800, 200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: SeekBarView(
              position: position,
              duration: duration,
              inlineLabels: inlineLabels,
              onSeek: seeks.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return seeks;
}

void main() {
  testWidgets('shows where the track is', (tester) async {
    await _pumpBar(tester);
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(0.125, 0.001));
  });

  testWidgets('dragging moves the thumb without seeking', (tester) async {
    final seeks = await _pumpBar(tester);

    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    // The thumb follows the finger...
    expect(tester.widget<Slider>(slider).value, greaterThan(0.5));
    // ...but mpv is not asked to re-buffer on every frame of the gesture.
    expect(seeks, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(seeks, hasLength(1), reason: 'one seek, at the end of the drag');
    expect(seeks.single.inSeconds, greaterThan(120));
  });

  testWidgets('the elapsed time follows the drag, not the track', (tester) async {
    await _pumpBar(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    // Reads the position the drag would land on, not the 0:30 still playing.
    expect(find.text('0:30'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a position arriving mid-drag does not move the thumb',
      (tester) async {
    // The exact failure a naive implementation has: the player ticks while you
    // are dragging and yanks the thumb back to the playhead.
    await _pumpBar(tester);
    final slider = find.byType(Slider);

    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    final dragged = tester.widget<Slider>(slider).value;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: SeekBarView(
                position: const Duration(seconds: 31),
                duration: _duration,
                onSeek: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Slider>(slider).value, dragged);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a track of unknown length cannot be dragged', (tester) async {
    await _pumpBar(tester, duration: Duration.zero);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('inline labels put the times either side of the slider',
      (tester) async {
    await _pumpBar(tester, inlineLabels: true);

    final sliderBox = tester.getRect(find.byType(Slider));
    expect(tester.getRect(find.text('0:30')).right,
        lessThanOrEqualTo(sliderBox.left));
    expect(tester.getRect(find.text('4:00')).left,
        greaterThanOrEqualTo(sliderBox.right));
  });
}
