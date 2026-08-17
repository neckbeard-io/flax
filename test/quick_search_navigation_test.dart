import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/library/artist_detail_screen.dart';
import 'package:flax/features/search/quick_search.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

/// Clicking a sidebar quick-search result opens it, through the real router.
///
/// **These do not guard the bug that prompted them, and that was checked rather
/// than assumed** — they still pass with the fix reverted.
///
/// The bug: a `TextField` wraps itself in a `TapRegion` whose default
/// `onTapOutside` unfocuses it. The quick-search panel lives in the `Overlay`,
/// outside that region, so a real click on it unfocused the field — and the
/// sidebar closes the panel when the field loses focus, tearing the overlay down
/// before the row's `onTap` could run. Clicking a result dismissed the popup and
/// went nowhere. The fix is to put the panel in the field's tap-region group.
///
/// `tester.tap` does not reproduce it: it does not drive `TapRegion` resolution
/// the way a real pointer does, so the focus is never stolen and the overlay
/// survives regardless. Verified by hand against a running build instead.
///
/// What these tests are still worth: the wiring from a panel row through `_open`
/// to a pushed route, which had no coverage at all — the existing panel tests
/// build `QuickSearchPanel` directly and only check that it reports taps.
const _server = Server(
  id: 'srv',
  name: 'Test',
  url: 'http://localhost:4533',
  username: 'u',
  tokenHash: 't',
  salt: 's',
  isActive: true,
);

const _artist = Artist(id: 'ar1', serverId: 'srv', name: 'Ayreon');

class _FakeServers extends ServerListNotifier {
  _FakeServers() {
    state = [_server];
  }
}

/// Explicit pumps rather than pumpAndSettle: the screens behind these routes
/// fetch from a server that is not there, and one stuck progress indicator would
/// hang the suite instead of failing it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const ui.Size(1500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      serverListProvider.overrideWith((ref) => _FakeServers()),
      // Fixed results, so the test is about the click and not about searching.
      quickSearchResultsProvider.overrideWith(
        (ref) => Stream.value(const QuickSearchResults(artists: [_artist])),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: container.read(routerProvider),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

/// Types into the sidebar field, which is what opens the panel.
Future<void> _openPanel(WidgetTester tester) async {
  final field = find.descendant(
    of: find.byType(DesktopSidebar),
    matching: find.byType(TextField),
  );
  await tester.tap(field);
  await tester.pump();
  // At least kQuickSearchMinChars, or the panel stays shut.
  await tester.enterText(field, 'ay');
  await _settle(tester);
}

void main() {
  testWidgets('clicking a quick-search result navigates to it', (tester) async {
    await _pumpApp(tester);

    await _openPanel(tester);
    expect(
      find.text('Ayreon'),
      findsOneWidget,
      reason: 'the panel should be open with the overridden result',
    );

    await tester.tap(find.text('Ayreon'));
    await _settle(tester);

    // Asserting on the screen rather than the router's currentConfiguration:
    // `push` is an imperative navigation, and the match list does not report it
    // the way a `go` does.
    expect(
      find.byType(ArtistDetailScreen),
      findsOneWidget,
      reason: 'the tap must open the artist',
    );
  });

  testWidgets('the query is cleared once a result is opened', (tester) async {
    await _pumpApp(tester);
    await _openPanel(tester);

    await tester.tap(find.text('Ayreon'));
    await _settle(tester);

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(DesktopSidebar),
        matching: find.byType(TextField),
      ),
    );
    // A query left behind is the tell-tale of the original bug: it means the
    // dismiss path never ran.
    expect(field.controller?.text, isEmpty);
  });
}
