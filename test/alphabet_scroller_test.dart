import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artists_screen.dart';
import 'package:flax/shared/widgets/alphabet_scroller.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

/// A library as the database returns it: ordered by sort name where the
/// server gave one, name otherwise. "The Beatles" sorts as "beatles".
List<Artist> _library({int perLetter = 4}) {
  final artists = <Artist>[
    const Artist(
      id: 'num',
      serverId: 's',
      name: '65daysofstatic',
      sortName: '65daysofstatic',
      albumCount: 1,
    ),
    const Artist(
      id: 'beatles',
      serverId: 's',
      name: 'The Beatles',
      sortName: 'beatles',
      albumCount: 1,
    ),
    for (var c = 0x61; c <= 0x7A; c++)
      for (var i = 0; i < perLetter; i++)
        Artist(
          id: '${String.fromCharCode(c)}$i',
          serverId: 's',
          name: '${String.fromCharCode(c).toUpperCase()}rtist $i',
          sortName: '${String.fromCharCode(c)}rtist $i',
          albumCount: 1,
        ),
  ];
  artists.sort(
    (a, b) => (a.sortName ?? a.name).compareTo(b.sortName ?? b.name),
  );
  return artists;
}

void main() {
  group('the index', () {
    test('files a row under the first letter of what it sorts on', () {
      expect(indexLetterOf('beatles'), 'B');
      expect(indexLetterOf('Mastodon'), 'M');
      expect(indexLetterOf('65daysofstatic'), '#');
      expect(indexLetterOf('!!!'), '#');
      expect(indexLetterOf('Ólafur Arnalds'), '#');
      expect(indexLetterOf(''), '#');
    });

    test('a letter goes to its first row', () {
      final rows = firstRowByLetter(['65days', 'abba', 'acdc', 'beatles']);
      expect(rows, {'#': 0, 'A': 1, 'B': 3});
      expect(rowForLetter('A', rows), 1);
    });

    test('a letter with no rows goes to the next one that has some', () {
      final rows = firstRowByLetter(['abba', 'mastodon', 'opeth']);
      expect(rowForLetter('C', rows), 1, reason: 'C is empty; M is next');
      expect(rowForLetter('#', rows), 0);
      expect(rowForLetter('Z', rows), 2, reason: 'nothing after: previous');
      expect(rowForLetter('M', const {}), isNull);
    });
  });

  group('the strip', () {
    Future<List<String>> pumpStrip(WidgetTester tester) async {
      final letters = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlphabetScroller(
              available: const {'A', 'M'},
              onLetter: letters.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      return letters;
    }

    Offset letterCenter(WidgetTester tester, String letter) => tester.getCenter(
      find.descendant(
        of: find.byType(AlphabetScroller),
        matching: find.text(letter),
      ),
    );

    testWidgets('tapping a letter asks for it', (tester) async {
      final letters = await pumpStrip(tester);
      await tester.tapAt(letterCenter(tester, 'M'));
      await tester.pump();
      expect(letters, ['M']);
    });

    testWidgets('dragging down asks for each letter in turn, once', (
      tester,
    ) async {
      final letters = await pumpStrip(tester);
      final from = letterCenter(tester, 'A');
      final to = letterCenter(tester, 'D');
      final gesture = await tester.startGesture(from);
      await tester.pump();
      // A finger slides; it does not teleport.
      for (var y = from.dy; y <= to.dy; y += 2) {
        await gesture.moveTo(Offset(from.dx, y));
        await tester.pump();
      }

      // The bubble names the letter under the finger.
      expect(find.text('D'), findsNWidgets(2));

      await gesture.up();
      await tester.pump();
      expect(letters, ['A', 'B', 'C', 'D']);
      expect(find.text('D'), findsOneWidget, reason: 'the bubble is gone');
    });

    testWidgets('each letter is a button for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      final letters = await pumpStrip(tester);
      expect(find.bySemanticsLabel('Jump to M'), findsOneWidget);
      expect(find.bySemanticsLabel('Jump to numbers and symbols'), findsOne);
      tester.semantics.tap(find.semantics.byLabel('Jump to Q'));
      expect(letters, ['Q']);
      semantics.dispose();
    });
  });

  group('Artists on a phone', () {
    setUp(() => debugOverrideIsDesktopPlatform = false);
    tearDown(() => debugOverrideIsDesktopPlatform = null);

    Future<void> pumpArtists(WidgetTester tester, List<Artist> artists) async {
      tester.view.physicalSize = const ui.Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            artistsProvider.overrideWith((ref) => Stream.value(artists)),
            isOfflineModeProvider.overrideWithValue(false),
            libraryRepositoryProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: ArtistsScreen()),
        ),
      );
      await tester.pump();
    }

    Finder strip(String letter) => find.descendant(
      of: find.byType(AlphabetScroller),
      matching: find.text(letter),
    );

    Rect tileOf(WidgetTester tester, String name) => tester.getRect(
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    );

    testWidgets('a letter brings its first artist to the top', (tester) async {
      await pumpArtists(tester, _library());
      expect(find.text('Mrtist 0'), findsNothing, reason: 'starts at the top');

      await tester.tap(strip('M'));
      await tester.pump();

      final listTop = tester.getRect(find.byType(ListView)).top;
      expect(tileOf(tester, 'Mrtist 0').top, moreOrLessEquals(listTop));
    });

    testWidgets('"The Beatles" is under B, where it sorts', (tester) async {
      await pumpArtists(tester, _library());
      await tester.tap(strip('B'));
      await tester.pump();

      final listTop = tester.getRect(find.byType(ListView)).top;
      expect(tileOf(tester, 'The Beatles').top, moreOrLessEquals(listTop));
    });

    testWidgets('fits the phone, rows clear of the strip', (tester) async {
      await pumpArtists(tester, _library());
      expect(tester.takeException(), isNull);

      final stripRect = tester.getRect(find.byType(AlphabetScroller));
      expect(stripRect.right, lessThanOrEqualTo(390));
      expect(
        tileOf(tester, '65daysofstatic').right,
        lessThanOrEqualTo(390 - kAlphabetScrollerWidth),
      );
    });

    testWidgets('a short library has no index', (tester) async {
      await pumpArtists(tester, _library(perLetter: 1).take(20).toList());
      expect(find.byType(AlphabetScroller), findsNothing);
    });
  });
}
