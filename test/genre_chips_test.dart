import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/nav_destinations.dart';
import 'package:flax/app/router.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/features/library/genre_screen.dart';
import 'package:flax/shared/widgets/genre_chips.dart';

/// Genre chips, the album page's genres and the genre page. #134.
const _many = [
  'Soundtrack',
  'Britpop',
  'Electronic',
  'Rock',
  'Techno',
  'House',
  'New Wave',
  'Synth-pop',
  'Ambient',
  'Punk',
  'Post-punk',
  'Dub',
  'Breakbeat',
  'Psychedelic',
];

Widget _box(double width, Widget child) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

int _shownChips(WidgetTester tester) =>
    find.byType(GenreChip).evaluate().length;

String? _moreLabel(WidgetTester tester) {
  final more = find.textContaining(RegExp(r'^\+\d+$'));
  if (more.evaluate().isEmpty) return null;
  return tester.widget<Text>(more).data;
}

void main() {
  group('fitting one line', () {
    double more(int hidden) => 30;

    test('everything fits without a +N', () {
      expect(
        genreChipsThatFit(
          widths: [50, 50],
          maxWidth: 106,
          spacing: 6,
          moreWidth: more,
        ),
        2,
      );
    });

    test('leaves room for +N when some are hidden', () {
      // Two chips fit alone (106), but with a third hidden the +N needs 36
      // more, so only one chip and the +N fit.
      expect(
        genreChipsThatFit(
          widths: [50, 50, 50],
          maxWidth: 120,
          spacing: 6,
          moreWidth: more,
        ),
        1,
      );
    });

    test('always shows at least one', () {
      expect(
        genreChipsThatFit(
          widths: [500, 50],
          maxWidth: 100,
          spacing: 6,
          moreWidth: more,
        ),
        1,
      );
      expect(
        genreChipsThatFit(
          widths: const [],
          maxWidth: 100,
          spacing: 6,
          moreWidth: more,
        ),
        0,
      );
    });
  });

  group('GenreChips', () {
    testWidgets('wrapped, every genre shows', (tester) async {
      await tester.pumpWidget(_box(600, const GenreChips(genres: _many)));
      expect(tester.takeException(), isNull);
      expect(_shownChips(tester), _many.length);
      expect(_moreLabel(tester), isNull);
    });

    for (final width in [358.0, 200.0]) {
      testWidgets('one line at ${width.toInt()}px: whole chips, then +N', (
        tester,
      ) async {
        await tester.pumpWidget(
          _box(
            width,
            const GenreChips(
              genres: _many,
              singleLine: true,
              size: GenreChipSize.touch,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');

        final shown = _shownChips(tester);
        expect(shown, greaterThanOrEqualTo(1));
        expect(_moreLabel(tester), '+${_many.length - shown}');

        final row = tester.getRect(find.byType(GenreChips));
        for (final chip in find.byType(GenreChip).evaluate()) {
          expect(
            tester.getRect(find.byWidget(chip.widget)).right,
            lessThanOrEqualTo(row.left + width + 0.5),
          );
        }
      });
    }

    testWidgets('a single long name ellipsizes rather than overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _box(
          120,
          const GenreChips(
            genres: ['Progressive Electronic Dance Music'],
            singleLine: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_shownChips(tester), 1);
    });

    testWidgets('+N names the hidden genres', (tester) async {
      await tester.pumpWidget(
        _box(
          160,
          const GenreChips(
            genres: ['Rock', 'Electronic', 'Dub', 'Psychedelic'],
            singleLine: true,
            size: GenreChipSize.dense,
          ),
        ),
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      final more = _moreLabel(tester)!;
      expect(
        tooltip.message!.split(', '),
        hasLength(int.parse(more.substring(1))),
      );
    });

    testWidgets('tapping a chip calls back with its name', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _box(
          600,
          GenreChips(
            genres: const ['Rock', 'Dub'],
            onSelected: (g) => selected = g,
          ),
        ),
      );
      await tester.tap(find.text('Dub'));
      expect(selected, 'Dub');
    });

    for (final name in ['Drum & Bass', 'Rock/Pop', 'Hip Hop']) {
      testWidgets('opens the genre page for "$name"', (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(body: GenreChips(genres: [name])),
            ),
            GoRoute(
              path: '/genres/:name',
              builder: (_, state) =>
                  Scaffold(body: Text('page:${state.pathParameters['name']}')),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(find.text('page:$name'), findsOneWidget);
      });
    }
  });

  group('routes', () {
    test('a genre page is a valid route that highlights Albums', () {
      expect(isValidRoute(genreLocation('Drum & Bass')), isTrue);
      expect(isValidRoute('/genres/'), isFalse);
      expect(
        navDestinationIndex('/genres/Rock'),
        navDestinationIndex('/albums'),
      );
      expect(
        navIndexForLocation('/genres/Rock'),
        navIndexForLocation('/albums'),
      );
    });
  });

  group('album page', () {
    const albumId = 'alb-1';

    Album album({List<String>? genres}) => Album(
      id: albumId,
      serverId: 'srv',
      name: 'Trainspotting',
      artistName: 'Various Artists',
      songCount: 3,
      genre: genres?.first,
      genres: genres,
    );

    Song song(int i, {List<String>? genres}) => Song(
      id: 's$i',
      serverId: 'srv',
      albumId: albumId,
      title: 'Track $i',
      track: i,
      genres: genres,
    );

    test('a column only when a known track genre differs', () {
      final rock = album(genres: ['Rock', 'Britpop']);
      expect(
        tracksNeedGenreColumn(rock, [
          song(1, genres: ['britpop', 'rock']),
          song(2, genres: ['Rock', 'Britpop']),
        ]),
        isFalse,
        reason: 'every track matches the album',
      );
      expect(
        tracksNeedGenreColumn(rock, [
          song(1, genres: ['Rock']),
          song(2, genres: ['Rock', 'Britpop']),
        ]),
        isTrue,
      );
      expect(
        tracksNeedGenreColumn(rock, [
          song(1, genres: ['Techno']),
          song(2),
        ]),
        isFalse,
        reason: 'a track still being backfilled',
      );
      expect(
        tracksNeedGenreColumn(album(), [
          song(1, genres: ['Techno']),
        ]),
        isFalse,
        reason: 'the album still being backfilled',
      );
    });

    Future<void> pump(
      WidgetTester tester,
      Album album,
      List<Song> songs,
    ) async {
      tester.view.physicalSize = const ui.Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumDetailProvider(
              albumId,
            ).overrideWith((ref) => Stream.value(album)),
            albumSongsProvider(
              albumId,
            ).overrideWith((ref) => Stream.value(songs)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const MediaQuery(
              data: MediaQueryData(size: Size(1400, 1000)),
              child: AlbumDetailScreen(albumId: albumId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('desktop header lists every genre', (tester) async {
      await pump(tester, album(genres: _many), [
        for (var i = 1; i <= 3; i++) song(i, genres: _many),
      ]);
      for (final g in _many) {
        expect(find.text(g), findsOneWidget, reason: '$g in the header');
      }
      expect(find.text('GENRE'), findsNothing, reason: 'tracks all match');
    });

    testWidgets('a GENRE column when a track differs', (tester) async {
      await pump(tester, album(genres: ['Rock', 'Techno']), [
        song(1, genres: ['Rock']),
        song(2, genres: ['Techno']),
        song(3, genres: ['Rock', 'Techno']),
      ]);
      expect(find.text('GENRE'), findsOneWidget);
    });
  });

  group('genre page', () {
    for (final size in const [Size(390, 844), Size(1400, 900)]) {
      testWidgets(
        'header fits at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: Scaffold(
                body: GenreHeader(
                  genre: 'Progressive Electronic Dance Music',
                  albumCount: 1234,
                  onShuffle: () {},
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('1234 albums'), findsOneWidget);
          final shuffle = tester.getRect(find.byKey(GenreHeader.shuffleKey));
          expect(shuffle.right, lessThanOrEqualTo(size.width));
        },
      );
    }

    testWidgets('screen lists the genre albums', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            genreAlbumsProvider('Britpop').overrideWith(
              (ref) => Stream.value([
                for (final name in ['Parklife', 'Different Class'])
                  Album(id: name, serverId: 'srv', name: name),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const GenreScreen(genre: 'Britpop'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Britpop'), findsOneWidget);
      expect(find.text('2 albums'), findsOneWidget);
      expect(find.text('Parklife'), findsOneWidget);
    });

    testWidgets('an empty genre says so', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            genreAlbumsProvider(
              'Polka',
            ).overrideWith((ref) => Stream.value(const <Album>[])),
          ],
          child: const MaterialApp(home: GenreScreen(genre: 'Polka')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No albums in Polka'), findsOneWidget);
      final shuffle = tester.widget<ButtonStyleButton>(
        find.byKey(GenreHeader.shuffleKey),
      );
      expect(shuffle.onPressed, isNull, reason: 'nothing to shuffle');
    });
  });
}
