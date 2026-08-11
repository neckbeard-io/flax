import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/albums_screen.dart';
import 'package:flax/shared/widgets/album_context_menu.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

/// Album art is square, and the grid tile has to be laid out so it stays that
/// way.
///
/// The regression: the tile used a fixed `childAspectRatio`, which gave the art
/// whatever height was left after the labels — taller than it was wide — and
/// CoverArtImage's BoxFit.cover then cropped the top and bottom off every
/// sleeve. It read as art that was subtly wrong everywhere else in the app.
List<Album> _albums(int count) => [
  for (var i = 0; i < count; i++)
    Album(
      id: 'alb-$i',
      serverId: 'srv',
      name: 'Album $i',
      artistName: 'Artist $i',
      songCount: 9,
      duration: 2400,
    ),
];

Future<void> _pumpGrid(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = ui.Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: AlbumGrid(albums: _albums(12))),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('artGridTileWidth', () {
    test('splits the row the way the grid delegate does', () {
      // 1176 of usable width fits five 240px tiles with 12px gutters, so each
      // one comes out at (1176 - 4 * 12) / 5.
      expect(artGridTileWidth(1176, 240, 12), closeTo(225.6, 0.01));
    });

    test('never asks for less than one column', () {
      // Narrower than a single tile: one column that simply overflows the
      // nominal maximum beats a division by zero.
      expect(artGridTileWidth(100, 240, 12), 100);
      expect(artGridTileWidth(0, 240, 12), 0);
    });

    test('adds a column only once the row can hold one', () {
      expect(artGridTileWidth(240, 240, 12), 240);
      expect(artGridTileWidth(504, 240, 12), 246);
    });
  });

  group('the album grid', () {
    testWidgets('draws square art', (tester) async {
      await _pumpGrid(tester, width: 1200);

      final art = tester.getSize(find.byType(HoverArtwork).first);
      expect(
        art.width,
        closeTo(art.height, 0.5),
        reason: 'a non-square box makes BoxFit.cover crop the sleeve',
      );
    });

    testWidgets('keeps art square at phone widths too', (tester) async {
      await _pumpGrid(tester, width: 400);

      final art = tester.getSize(find.byType(HoverArtwork).first);
      expect(art.width, closeTo(art.height, 0.5));
    });

    testWidgets('gives the art the tile width and the labels the rest', (
      tester,
    ) async {
      await _pumpGrid(tester, width: 1200);

      final tile = tester.getSize(find.byType(AlbumContextMenu).first);
      final art = tester.getSize(find.byType(HoverArtwork).first);

      expect(art.width, closeTo(tile.width, 0.5));
      expect(
        tile.height - art.height,
        greaterThan(30),
        reason: 'two lines of labels have to fit under the art',
      );
      // No overflow stripe: the label strip is sized for the text, not the
      // other way round.
      expect(tester.takeException(), isNull);
    });
  });
}
