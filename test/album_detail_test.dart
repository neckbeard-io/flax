import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/album_detail_screen.dart';
import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/star_rating.dart';

const _albumId = 'alb-1';

final _album = Album(
  id: _albumId,
  serverId: 'srv',
  artistId: 'art-1',
  name: 'Fairytale',
  artistName: 'Natasha Beller',
  songCount: 4,
  duration: 761,
  year: 2019,
  genre: 'Trip-Hop',
  starred: true,
  userRating: 2,
);

List<Song> _songs() => [
  for (var i = 1; i <= 4; i++)
    Song(
      id: 'song-$i',
      serverId: 'srv',
      albumId: _albumId,
      title: ['Daniel', 'Jazzix', 'He Was (Clementine)', 'Fairytale'][i - 1],
      artistName: 'Natasha Beller',
      duration: 180 + i,
      track: i,
      starred: i == 1,
      userRating: i == 2 ? 4 : null,
    ),
];

Widget _harness({required Size size}) {
  return ProviderScope(
    overrides: [
      albumDetailProvider(_albumId).overrideWith((ref) => Stream.value(_album)),
      albumSongsProvider(
        _albumId,
      ).overrideWith((ref) => Stream.value(_songs())),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const AlbumDetailScreen(albumId: _albumId),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop layout shows album and per-track rating and favorite', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(1400, 1000)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Header.
    expect(find.text('ALBUM'), findsOneWidget);
    expect(find.text('Fairytale'), findsWidgets);
    expect(find.text('Natasha Beller'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Last'), findsOneWidget);

    // Track table, with a rating and a favorite per row plus the album's own.
    expect(find.text('TITLE'), findsOneWidget);
    expect(find.byType(StarRating), findsNWidgets(1 + 4));
    expect(find.byType(FavoriteButton), findsNWidgets(1 + 4));

    // Every track is listed.
    for (final title in ['Daniel', 'Jazzix', 'He Was (Clementine)']) {
      expect(
        find.text(title),
        findsOneWidget,
        reason: '$title should be listed',
      );
    }
  });

  testWidgets('desktop header has a back button when there is a route to pop', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Pushed rather than used as `home`: replacing the SliverAppBar with a
    // custom header removed the back button it provided for free, and a screen
    // that is the first route can legitimately show none. The regression only
    // appears once something is on the stack beneath it.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumDetailProvider(
            _albumId,
          ).overrideWith((ref) => Stream.value(_album)),
          albumSongsProvider(
            _albumId,
          ).overrideWith((ref) => Stream.value(_songs())),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 1000)),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AlbumDetailScreen(albumId: _albumId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ALBUM'), findsOneWidget, reason: 'album screen is up');
    expect(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
      findsOneWidget,
      reason: 'there must be a way back out of an album',
    );
  });

  testWidgets('phone layout keeps favorites but drops per-track stars', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(size: const Size(400, 900)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Album rating only — five stars per row will not fit a narrow screen, so
    // rows carry just the heart.
    expect(find.byType(StarRating), findsOneWidget);
    expect(find.byType(FavoriteButton), findsNWidgets(1 + 4));
    expect(find.text('TITLE'), findsNothing);
  });

  test('duration formatting', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(61), '1:01');
    expect(formatDuration(761), '12:41');
    expect(formatDuration(3661), '1:01:01');
  });
}
