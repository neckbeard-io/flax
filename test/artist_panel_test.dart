import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/artist_panel.dart';
import 'package:flax/features/player/now_playing_panels.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

Widget _harness({
  required Widget child,
  double width = kArtistPanelDefaultWidth,
  double height = 700,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

void main() {
  const similarArtists = [
    SimilarArtist(id: 'sim-1', name: 'Ayreon', coverArtId: 'art-1'),
    SimilarArtist(id: 'sim-2', name: 'Star One', coverArtId: 'art-2'),
    SimilarArtist(id: 'sim-3', name: 'Guilt Machine', coverArtId: 'art-3'),
  ];

  group('ArtistPanelView presentational behavior', () {
    testWidgets('shows centered artist name when artistId is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: const ArtistPanelView(
            artistName: 'Unknown Artist',
            artistId: null,
          ),
        ),
      );

      expect(find.text('Unknown Artist'), findsOneWidget);
      expect(find.byType(HoverArtwork), findsNothing);
      expect(find.text('Similar Artists'), findsNothing);
    });

    testWidgets('renders hero artwork, name, biography and similar artists', (
      tester,
    ) async {
      final tappedIds = <String>[];

      await tester.pumpWidget(
        _harness(
          child: ArtistPanelView(
            artistName: 'Arjen Anthony Lucassen',
            artistId: 'ar-100',
            biography:
                'Dutch singer and multi-instrumentalist. <a href="...">Read more on Last.fm</a>',
            similarArtists: similarArtists,
            onArtistTap: (id) => tappedIds.add(id),
          ),
        ),
      );

      expect(find.text('Arjen Anthony Lucassen'), findsOneWidget);
      // HTML stripped from bio:
      expect(
        find.text(
          'Dutch singer and multi-instrumentalist. Read more on Last.fm',
        ),
        findsOneWidget,
      );
      expect(find.text('Similar Artists'), findsOneWidget);
      expect(find.text('Ayreon'), findsOneWidget);
      expect(find.text('Star One'), findsOneWidget);

      // Hero HoverArtwork + 3 SimilarArtist HoverArtworks
      expect(find.byType(HoverArtwork), findsNWidgets(4));

      // Tap hero artwork -> navigates to hero artist
      await tester.tap(find.byType(HoverArtwork).first);
      expect(tappedIds, ['ar-100']);

      // Tap similar artist artwork -> navigates to similar artist id
      await tester.tap(find.byType(HoverArtwork).at(1));
      expect(tappedIds, ['ar-100', 'sim-1']);

      // Tap similar artist name -> navigates to similar artist id
      await tester.tap(find.text('Star One'));
      expect(tappedIds, ['ar-100', 'sim-1', 'sim-2']);
    });

    testWidgets('omits similar artists section when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: const ArtistPanelView(
            artistName: 'Solo Artist',
            artistId: 'ar-200',
            biography: 'A great bio.',
            similarArtists: [],
          ),
        ),
      );

      expect(find.text('Solo Artist'), findsOneWidget);
      expect(find.text('A great bio.'), findsOneWidget);
      expect(find.text('Similar Artists'), findsNothing);
      expect(find.byType(HoverArtwork), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow at panel width breakpoints', (
      tester,
    ) async {
      for (final width in [
        kArtistPanelMinWidth,
        kArtistPanelDefaultWidth,
        kArtistPanelMaxWidth,
      ]) {
        await tester.pumpWidget(
          _harness(
            width: width,
            child: const ArtistPanelView(
              artistName:
                  'Very Long Artist Name That Might Wrap To Multiple Lines',
              artistId: 'ar-300',
              biography:
                  'A reasonably long biography describing the artist history and discography over many decades with extensive background.',
              similarArtists: similarArtists,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Similar Artists'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Similar Artists'), findsOneWidget);
      }
    });

    testWidgets('hovering over similar artist artwork activates hover state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ArtistPanelView(
            artistName: 'Ayreon',
            artistId: 'ar-100',
            similarArtists: similarArtists,
            onArtistTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstSimilarArtwork = find.byType(HoverArtwork).at(1);

      // Create mouse gesture and hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(firstSimilarArtwork));
      await tester.pumpAndSettle();

      final animatedScale = tester.widget<AnimatedScale>(
        find
            .descendant(
              of: firstSimilarArtwork,
              matching: find.byType(AnimatedScale),
            )
            .first,
      );
      expect(animatedScale.scale, greaterThan(1.0));
    });
  });
}
