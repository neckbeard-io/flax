import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/shared/widgets/up_back_button.dart';

Widget _app(GoRouter router) => MaterialApp.router(routerConfig: router);

void main() {
  testWidgets('pops back to where you came from when there is history', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/albums/1'),
              child: const Text('open album'),
            ),
          ),
        ),
        GoRoute(
          path: '/albums/1',
          builder: (context, state) => const Scaffold(
            body: UpBackButton(fallbackLocation: '/artists/9'),
          ),
        ),
        GoRoute(
          path: '/artists/9',
          builder: (context, state) =>
              const Scaffold(body: Text('artist page')),
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.tap(find.text('open album'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UpBackButton));
    await tester.pumpAndSettle();

    // Back means back: an album opened from Home returns to Home, not to the
    // album's artist.
    expect(find.text('open album'), findsOneWidget);
    expect(find.text('artist page'), findsNothing);
  });

  testWidgets('goes up to the parent when there is nothing to pop', (
    tester,
  ) async {
    final router = GoRouter(
      // Straight onto the album, as a deep link or --route launch does.
      initialLocation: '/albums/1',
      routes: [
        GoRoute(
          path: '/albums/1',
          builder: (context, state) => const Scaffold(
            body: UpBackButton(fallbackLocation: '/artists/9'),
          ),
        ),
        GoRoute(
          path: '/artists/9',
          builder: (context, state) =>
              const Scaffold(body: Text('artist page')),
        ),
      ],
    );

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    // The button must be there at all — it used to be hidden in exactly this
    // case, leaving a deep-linked screen with no way out.
    expect(find.byType(UpBackButton), findsOneWidget);

    await tester.tap(find.byType(UpBackButton));
    await tester.pumpAndSettle();

    expect(find.text('artist page'), findsOneWidget);
  });
}
