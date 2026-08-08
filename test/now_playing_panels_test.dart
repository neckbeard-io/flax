import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/features/player/now_playing_panels.dart';

/// Stand-in for a real panel: fills whatever it is given, so measuring it
/// measures the layout rather than the content.
class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Colors.black12, child: Center(child: Text(label)));
}

Widget _harness({
  required double width,
  bool? artistOpen,
  NowPlayingPanel selected = NowPlayingPanel.lyrics,
  Widget lyrics = const _Stub('lyrics'),
  Widget? leading,
}) {
  final layout = NowPlayingLayout.forWidth(width);
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: NowPlayingPanels(
        leading: leading,
        layout: layout,
        artist: const _Stub('artist'),
        lyrics: lyrics,
        queue: const _Stub('queue'),
        artistOpen: artistOpen ?? layout.artistOpenByDefault,
        onArtistOpenChanged: (_) {},
        selected: selected,
        onSelected: (_) {},
      ),
    ),
  );
}

void _sizeWindow(WidgetTester tester, double width) {
  tester.view.physicalSize = ui.Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

final _artist = find.byKey(NowPlayingPanels.artistKey);
final _lyrics = find.byKey(NowPlayingPanels.lyricsKey);
final _queue = find.byKey(NowPlayingPanels.queueKey);

void main() {
  group('background', () {
    testWidgets('is opaque, so a route underneath cannot show through',
        (tester) async {
      // These panels are the app's only screen that is not a Scaffold — the
      // shell supplies one — so nothing else gives them a background. Without
      // it the outgoing screen stayed visible through the lyrics for the whole
      // push transition.
      _sizeWindow(tester, 1400);
      await tester.pumpWidget(_harness(width: 1400));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(NowPlayingPanels),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(material.color, isNotNull);
      expect(material.color!.a, 1.0);
    });

    testWidgets('takes its color from the theme surface', (tester) async {
      _sizeWindow(tester, 1400);
      await tester.pumpWidget(_harness(width: 1400));

      final context = tester.element(find.byType(NowPlayingPanels));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(NowPlayingPanels),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(material.color, Theme.of(context).colorScheme.surface);
    });
  });

  group('breakpoints', () {
    test('below 700 the panels are not used at all', () {
      expect(NowPlayingLayout.fitsAt(699), isFalse);
      expect(NowPlayingLayout.fitsAt(700), isTrue);
    });

    test('one panel at a time below 1100, three from 1100 up', () {
      expect(NowPlayingLayout.forWidth(1099).singlePanel, isTrue);
      expect(NowPlayingLayout.forWidth(1100).singlePanel, isFalse);
    });

    test('the artist panel starts open only from 1400 up', () {
      expect(NowPlayingLayout.forWidth(1399).artistOpenByDefault, isFalse);
      expect(NowPlayingLayout.forWidth(1400).artistOpenByDefault, isTrue);
    });
  });

  testWidgets('a wide window shows all three panels', (tester) async {
    _sizeWindow(tester, 1500);
    await tester.pumpWidget(_harness(width: 1500));
    await tester.pumpAndSettle();

    expect(_artist, findsOneWidget);
    expect(_lyrics, findsOneWidget);
    expect(_queue, findsOneWidget);

    // Left to right: artist, lyrics, queue.
    expect(tester.getTopLeft(_artist).dx, lessThan(tester.getTopLeft(_lyrics).dx));
    expect(tester.getTopLeft(_lyrics).dx, lessThan(tester.getTopLeft(_queue).dx));
    expect(tester.getSize(_queue).width, kQueuePanelWidth);
  });

  testWidgets('a medium window shows lyrics and queue, artist collapsed',
      (tester) async {
    _sizeWindow(tester, 1200);
    await tester.pumpWidget(_harness(width: 1200));
    await tester.pumpAndSettle();

    expect(_artist, findsNothing);
    expect(_lyrics, findsOneWidget);
    expect(_queue, findsOneWidget);
  });

  testWidgets('a narrow window shows one panel and a switcher', (tester) async {
    _sizeWindow(tester, 900);
    await tester.pumpWidget(_harness(width: 900));
    await tester.pumpAndSettle();

    expect(_lyrics, findsOneWidget);
    expect(_artist, findsNothing);
    expect(_queue, findsNothing);

    // The switcher is the only way to the other two, so it has to be there.
    expect(find.byType(SegmentedButton<NowPlayingPanel>), findsOneWidget);

    // The chosen panel gets the whole width.
    expect(tester.getSize(_lyrics).width, 900);
  });

  testWidgets('the switcher sits in the middle of the window', (tester) async {
    _sizeWindow(tester, 900);
    await tester.pumpWidget(
      _harness(width: 900, leading: const BackButton()),
    );
    await tester.pumpAndSettle();

    // Centered against the window, not against what the controls leave over.
    // The trailing side reserves room for the window buttons and the leading
    // side does not, so a pair of Spacers puts this visibly off center.
    final box = tester.getRect(find.byType(SegmentedButton<NowPlayingPanel>));
    expect(box.center.dx, moreOrLessEquals(450, epsilon: 0.5));
  });

  testWidgets('a cramped switcher drops its labels rather than wrapping them',
      (tester) async {
    // A 700pt panel area leaves the switcher under 400pt once both sides have
    // reserved their width — enough for three icons, not for three icons and
    // their names. SegmentedButton's answer to that was to wrap mid-word
    // ("Artis / t") and overflow the fixed-height header.
    _sizeWindow(tester, 700);
    await tester.pumpWidget(
      _harness(width: 700, leading: const BackButton()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Artist'), findsNothing);
    // The icons stay, so all three panels are still reachable.
    expect(find.byType(SegmentedButton<NowPlayingPanel>), findsOneWidget);
    for (final panel in NowPlayingPanel.values) {
      expect(find.byIcon(panel.icon), findsOneWidget);
    }
  });

  testWidgets('a roomier switcher keeps its labels on one line',
      (tester) async {
    _sizeWindow(tester, 1050);
    await tester.pumpWidget(
      _harness(width: 1050, leading: const BackButton()),
    );
    await tester.pumpAndSettle();

    for (final panel in NowPlayingPanel.values) {
      final label = tester.widget<Text>(find.text(panel.label));
      expect(label.maxLines, 1, reason: '${panel.label} must not wrap');
    }
  });

  testWidgets('the switcher picks which panel fills a narrow window',
      (tester) async {
    _sizeWindow(tester, 900);
    await tester.pumpWidget(
      _harness(width: 900, selected: NowPlayingPanel.queue),
    );
    await tester.pumpAndSettle();

    expect(_queue, findsOneWidget);
    expect(_lyrics, findsNothing);
    expect(tester.getSize(_queue).width, 900);
  });

  testWidgets('collapsing the artist panel hands its width to the lyrics',
      (tester) async {
    _sizeWindow(tester, 1500);

    await tester.pumpWidget(_harness(width: 1500, artistOpen: true));
    await tester.pumpAndSettle();

    final artistWidth = tester.getSize(_artist).width;
    final lyricsOpen = tester.getSize(_lyrics).width;
    // The resize handle sits between the two; measured rather than assumed so
    // the assertion below survives it being restyled.
    final handleWidth =
        tester.getTopLeft(_lyrics).dx - tester.getBottomRight(_artist).dx;
    expect(artistWidth, kArtistPanelDefaultWidth);
    expect(handleWidth, greaterThan(0));

    await tester.pumpWidget(_harness(width: 1500, artistOpen: false));
    await tester.pumpAndSettle();

    expect(_artist, findsNothing);
    // Every pixel the artist column occupied, including its handle, goes to
    // the lyrics — not to a gap where the panel used to be.
    expect(tester.getSize(_lyrics).width, lyricsOpen + artistWidth + handleWidth);
    // And the queue does not move or resize.
    expect(tester.getSize(_queue).width, kQueuePanelWidth);
    expect(tester.getTopLeft(_queue).dx, 1500 - kQueuePanelWidth);
  });

  testWidgets('lyrics arriving late do not move the panels', (tester) async {
    _sizeWindow(tester, 1500);

    // Nothing loaded yet. The placeholder fills its column the way the real
    // loading state does — a message centered in the panel.
    await tester.pumpWidget(
      _harness(width: 1500, lyrics: const Center(child: Text(''))),
    );
    await tester.pumpAndSettle();

    final before = [_artist, _lyrics, _queue].map(tester.getRect).toList();

    // A long sheet lands. The columns must not budge — a 66px shift when data
    // arrived is exactly the kind of thing a screenshot never catches.
    await tester.pumpWidget(
      _harness(
        width: 1500,
        lyrics: ListView(
          children: [
            for (var i = 0; i < 60; i++) Text('a very long lyric line $i'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final after = [_artist, _lyrics, _queue].map(tester.getRect).toList();
    expect(after, before);
  });
}
