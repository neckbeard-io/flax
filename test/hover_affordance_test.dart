import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/widgets/favorite_button.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/shared/widgets/star_rating.dart';

/// Hearts and stars have to announce themselves as buttons.
///
/// A bare [IconButton] does not at this size: its splash is drawn inside its
/// own bounds, and at 18px on a dark surface there is effectively nothing to
/// see. The heart in the mini player read as decoration.

Widget _harness(Widget child) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: Center(child: child)),
    );

/// Puts a mouse pointer over [target] and leaves it there.
Future<void> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}

AnimatedScale _scaleOf(WidgetTester tester, Finder within) =>
    tester.widget<AnimatedScale>(
      find.descendant(of: within, matching: find.byType(AnimatedScale)).first,
    );

Icon _iconOf(WidgetTester tester, Finder within) => tester.widget<Icon>(
      find.descendant(of: within, matching: find.byType(Icon)).first,
    );

void main() {
  group('the favorite heart', () {
    testWidgets('sits still until the pointer arrives', (tester) async {
      await tester.pumpWidget(
        _harness(FavoriteButton(isFavorite: false, onToggle: () {})),
      );
      await tester.pumpAndSettle();

      final heart = find.byType(FavoriteButton);
      expect(_scaleOf(tester, heart).scale, 1.0);
      final backdrop = tester.widget<AnimatedContainer>(
        find.descendant(of: heart, matching: find.byType(AnimatedContainer)),
      );
      expect(
        (backdrop.decoration as BoxDecoration).color,
        Colors.transparent,
      );
    });

    testWidgets('grows, brightens and gains a backdrop under the pointer',
        (tester) async {
      await tester.pumpWidget(
        _harness(FavoriteButton(isFavorite: false, onToggle: () {})),
      );
      await tester.pumpAndSettle();

      final heart = find.byType(FavoriteButton);
      final restingColor = _iconOf(tester, heart).color;

      await _hover(tester, heart);

      expect(_scaleOf(tester, heart).scale, greaterThan(1.0));
      expect(_iconOf(tester, heart).color, isNot(restingColor));

      final backdrop = tester.widget<AnimatedContainer>(
        find.descendant(of: heart, matching: find.byType(AnimatedContainer)),
      );
      final color = (backdrop.decoration as BoxDecoration).color!;
      expect(color.a, greaterThan(0), reason: 'the disc must be visible');
    });

    testWidgets('still toggles when clicked', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        _harness(FavoriteButton(isFavorite: false, onToggle: () => toggled++)),
      );
      await tester.tap(find.byType(FavoriteButton));
      expect(toggled, 1);
    });
  });

  group('the star rating', () {
    testWidgets('previews the rating a click would apply', (tester) async {
      await tester.pumpWidget(
        _harness(StarRating(rating: 1, size: 24, onRatingChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      await _hover(tester, find.byType(HoverIcon).at(2));

      expect(
        find.byIcon(Icons.star_rounded),
        findsNWidgets(3),
        reason: 'hovering the third star should fill three',
      );
    });

    testWidgets('lifts the star under the pointer', (tester) async {
      await tester.pumpWidget(
        _harness(StarRating(rating: 0, size: 24, onRatingChanged: (_) {})),
      );
      await tester.pumpAndSettle();

      final third = find.byType(HoverIcon).at(2);
      expect(_scaleOf(tester, third).scale, 1.0);

      await _hover(tester, third);
      expect(_scaleOf(tester, third).scale, greaterThan(1.0));
      // ...and only that one.
      expect(_scaleOf(tester, find.byType(HoverIcon).at(0)).scale, 1.0);
    });

    testWidgets('a read-only rating offers no affordance at all',
        (tester) async {
      await tester.pumpWidget(_harness(const StarRating(rating: 3)));
      await tester.pumpAndSettle();
      expect(find.byType(HoverIcon), findsNothing);
    });
  });

  testWidgets('hearts and stars share one hover implementation',
      (tester) async {
    // The point of the shared primitive: no call site hand-rolls its own feel,
    // so a heart in the mini player behaves like a heart in a track list.
    await tester.pumpWidget(
      _harness(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarRating(rating: 2, onRatingChanged: (_) {}),
            FavoriteButton(isFavorite: true, onToggle: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Five stars and a heart, every one of them a HoverIcon.
    expect(find.byType(HoverIcon), findsNWidgets(6));

    final scales = tester
        .widgetList<HoverIcon>(find.byType(HoverIcon))
        .map((h) => h.scale)
        .toSet();
    expect(scales, hasLength(1), reason: 'one lift, not two');
  });
}
