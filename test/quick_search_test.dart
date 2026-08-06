import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/search/quick_search.dart';
import 'package:flax/features/search/quick_search_overlay.dart';

Artist _artist(String name) =>
    Artist(id: 'ar-$name', serverId: 'srv', name: name, albumCount: 1);

Album _album(String name, String by) => Album(
      id: 'al-$name',
      serverId: 'srv',
      name: name,
      artistName: by,
      songCount: 1,
      duration: 100,
    );

void main() {
  group('the debounce', () {
    test('a burst of keystrokes searches once, for the last one', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(quickSearchProvider.notifier);

      for (final partial in ['te', 'tes', 'test', 'testa', 'testament']) {
        controller.setQuery(partial);
      }
      // Nothing committed yet — the field has only just stopped moving.
      expect(container.read(quickSearchProvider), '');

      await Future<void>.delayed(kQuickSearchDebounce * 2);
      expect(container.read(quickSearchProvider), 'testament');
    });

    test('one letter is never searched for', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(quickSearchProvider.notifier).setQuery('t');
      await Future<void>.delayed(kQuickSearchDebounce * 2);
      expect(container.read(quickSearchProvider), '');
    });

    test('clearing takes effect at once, not after the debounce', () {
      // Waiting a quarter second to hide results for a query the user has
      // already deleted reads as the popup being stuck.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(quickSearchProvider.notifier);

      controller.setQuery('testament');
      controller.setQuery('');
      expect(container.read(quickSearchProvider), '');
    });

    test('a pending search is dropped when the field is cleared', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(quickSearchProvider.notifier);

      controller.setQuery('testament');
      controller.clear();
      await Future<void>.delayed(kQuickSearchDebounce * 2);
      expect(container.read(quickSearchProvider), '');
    });
  });

  group('results', () {
    test('artists come before albums, and both are capped', () {
      final results = QuickSearchResults(
        artists: [for (var i = 0; i < 5; i++) _artist('artist $i')],
        albums: [for (var i = 0; i < 5; i++) _album('album $i', 'someone')],
      );
      final items = quickSearchItems(results);

      expect(items, hasLength(10));
      expect(items.take(5).every((i) => i.isArtist), isTrue);
      expect(items.skip(5).every((i) => !i.isArtist), isTrue);
      expect(kQuickSearchLimit, 5);
    });

    test('an item knows where it goes', () {
      expect(
        QuickSearchItem.artist(_artist('Testament')).route,
        '/artists/ar-Testament',
      );
      expect(
        QuickSearchItem.album(_album('Demonic', 'Testament')).route,
        '/albums/al-Demonic',
      );
    });
  });

  group('the panel', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<QuickSearchItem> items,
      int highlighted = -1,
      bool loading = false,
      void Function(QuickSearchItem)? onSelected,
      VoidCallback? onSearchEverything,
    }) async {
      await tester.pumpWidget(
        // The rows draw cover art, which reads the server provider.
        ProviderScope(
          child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: QuickSearchPanel(
              items: items,
              highlighted: highlighted,
              query: 'testament',
              loading: loading,
              onSelected: onSelected ?? (_) {},
              onSearchEverything: onSearchEverything ?? () {},
            ),
          ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('groups artists and albums under headings', (tester) async {
      await pump(tester, items: [
        QuickSearchItem.artist(_artist('Testament')),
        QuickSearchItem.album(_album('Demonic', 'Testament')),
      ]);

      expect(find.text('ARTISTS'), findsOneWidget);
      expect(find.text('ALBUMS'), findsOneWidget);
      expect(find.text('Testament'), findsWidgets);
      expect(find.text('Demonic'), findsOneWidget);
    });

    testWidgets('never shows songs', (tester) async {
      // The whole point of the popup over the search screen: a library has far
      // more songs than albums, and they bury what you were reaching for.
      await pump(tester, items: [
        QuickSearchItem.album(_album('Demonic', 'Testament')),
      ]);
      expect(find.text('SONGS'), findsNothing);
    });

    testWidgets('always offers the full search, even with no results',
        (tester) async {
      var searched = false;
      await pump(
        tester,
        items: const [],
        onSearchEverything: () => searched = true,
      );

      expect(find.text('No artists or albums match'), findsOneWidget);
      expect(find.textContaining('Search everything'), findsOneWidget);

      await tester.tap(find.textContaining('Search everything'));
      expect(searched, isTrue);
    });

    testWidgets('says it is working rather than flashing a spinner',
        (tester) async {
      await pump(tester, items: const [], loading: true);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Searching…'), findsOneWidget);
    });

    testWidgets('tapping a row reports it', (tester) async {
      QuickSearchItem? picked;
      await pump(
        tester,
        items: [QuickSearchItem.artist(_artist('Testament'))],
        onSelected: (i) => picked = i,
      );

      await tester.tap(find.text('Testament'));
      expect(picked?.route, '/artists/ar-Testament');
    });

    testWidgets('the highlight is visible without the pointer', (tester) async {
      // "/" is a keyboard entry point, so the keyboard's cursor has to show.
      final items = [
        QuickSearchItem.artist(_artist('Testament')),
        QuickSearchItem.album(_album('Demonic', 'Testament')),
      ];
      await pump(tester, items: items, highlighted: 1);

      final tinted = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => (c.color?.a ?? 0) > 0)
          .toList();
      expect(tinted, isNotEmpty, reason: 'the highlighted row must be tinted');
    });
  });
}
