import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/enums.dart';
import 'package:flax/features/library/album_filter.dart';
import 'package:flax/features/library/albums_screen.dart';

/// The Albums screen's tabs, which replaced the Home screen.
///
/// `AlbumFilterTabs` takes its selection and its callback as plain arguments,
/// so the row can be driven without a server, a client, or a router.
Future<void> _pumpTabs(
  WidgetTester tester, {
  required AlbumFilter selected,
  required ValueChanged<AlbumFilter> onSelected,
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: AlbumFilterTabs(selected: selected, onSelected: onSelected),
      ),
    ),
  );
}

void main() {
  group('the filter set', () {
    test('carries the views Home used to show', () {
      final labels = AlbumFilter.values.map((f) => f.label).toList();
      expect(
        labels,
        containsAll(['Recently Added', 'Random', 'Most Played']),
        reason: 'dropping Home must not drop the content it carried',
      );
    });

    test('keeps favorites and ratings apart', () {
      // The two are separate fields on an album, not two views of one: hearts
      // are the boolean starred flag, stars are the 0-5 userRating.
      expect(AlbumFilter.favorites.listType, AlbumListType.starred);
      expect(AlbumFilter.topRated.listType, AlbumListType.highest);
    });

    test('every tab asks the server for a distinct list', () {
      final types = AlbumFilter.values.map((f) => f.listType).toSet();
      expect(types.length, AlbumFilter.values.length);
    });

    test('opens on the full library', () {
      expect(AlbumFilter.defaultFilter, AlbumFilter.all);
      expect(
        AlbumFilter.all.listType,
        AlbumListType.alphabeticalByName,
      );
    });
  });

  group('the tab row', () {
    testWidgets('shows every filter', (tester) async {
      await _pumpTabs(
        tester,
        selected: AlbumFilter.all,
        onSelected: (_) {},
      );

      for (final filter in AlbumFilter.values) {
        expect(find.text(filter.label), findsOneWidget);
      }
    });

    testWidgets('reports the tab that was tapped', (tester) async {
      AlbumFilter? tapped;
      await _pumpTabs(
        tester,
        selected: AlbumFilter.all,
        onSelected: (f) => tapped = f,
      );

      await tester.tap(find.text('Recently Added'));
      await tester.pump();

      expect(tapped, AlbumFilter.recentlyAdded);
    });

    testWidgets('marks only the open tab', (tester) async {
      await _pumpTabs(
        tester,
        selected: AlbumFilter.favorites,
        onSelected: (_) {},
      );

      Text labelFor(AlbumFilter f) => tester.widget<Text>(find.text(f.label));

      expect(labelFor(AlbumFilter.favorites).style?.fontWeight,
          FontWeight.w600);
      expect(labelFor(AlbumFilter.all).style?.fontWeight, isNot(FontWeight.w600));
    });

    testWidgets('wraps rather than overflowing a narrow window',
        (tester) async {
      // Seven tabs do not fit one line at phone widths, and a horizontally
      // scrolling row across the top of the app's landing screen would make
      // BackSwipeTracker stand down for any swipe that started there.
      await _pumpTabs(
        tester,
        selected: AlbumFilter.all,
        onSelected: (_) {},
        width: 380,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Top Rated'), findsOneWidget);
    });
  });
}
