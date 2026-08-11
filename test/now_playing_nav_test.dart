import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/nav_destinations.dart';
import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

const _server = Server(
  id: 'srv',
  name: 'Test',
  url: 'http://localhost:4533',
  username: 'u',
  tokenHash: 't',
  salt: 's',
  isActive: true,
);

class _FakeServers extends ServerListNotifier {
  _FakeServers() {
    state = [_server];
  }
}

/// Explicit pumps, not pumpAndSettle: the screens behind these routes fetch
/// from a server that is not there, and a stuck progress indicator would hang
/// the suite rather than fail it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const ui.Size(1500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [serverListProvider.overrideWith((ref) => _FakeServers())],
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

/// True when the sidebar item carrying [label] is drawn in its selected state.
///
/// Selection is a tinted background rather than a distinct widget, so the check
/// is on the icon actually used: `_SidebarItem` swaps to `selectedIcon`.
bool _isSelected(WidgetTester tester, IconData selectedIcon) => tester.any(
  find.descendant(
    of: find.byType(DesktopSidebar),
    matching: find.byIcon(selectedIcon),
  ),
);

void main() {
  group('navDestinationIndex', () {
    test('finds the listed destinations', () {
      expect(navDestinationIndex('/artists'), 0);
      expect(navDestinationIndex('/artists/abc'), 0);
      expect(navDestinationIndex('/albums'), 1);
    });

    test('answers null for routes that are their own sidebar item', () {
      // Returning 0 here is what left the first destination lit up at the same
      // time as Now Playing or Settings.
      expect(navDestinationIndex('/now-playing'), isNull);
      expect(navDestinationIndex('/settings'), isNull);
      expect(navDestinationIndex('/settings/equalizer'), isNull);
    });

    test('the bottom bar still gets a usable index', () {
      // NavigationBar asserts on an out-of-range selectedIndex, so this one
      // must keep falling back to 0 whatever the route.
      expect(navIndexForLocation('/now-playing'), 0);
      expect(navIndexForLocation('/albums'), 1);
    });

    test('Now Playing is not a bottom-bar destination', () {
      // It would be a sixth entry in the phone bar, where the mini player
      // already sits directly above and opens the same screen.
      expect(navDestinations.any((d) => d.path == '/now-playing'), isFalse);
    });
  });

  group('the sidebar entry', () {
    testWidgets('offers Now Playing, above the library', (tester) async {
      await _pumpApp(tester);

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(DesktopSidebar),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      expect(labels, contains('Now Playing'));
      expect(
        labels.indexOf('Now Playing'),
        lessThan(labels.indexOf('Artists')),
        reason: 'the ticket asks for it above the library destinations',
      );
      expect(labels, isNot(contains('Home')));
    });

    testWidgets('navigates to the now playing screen', (tester) async {
      final container = await _pumpApp(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(DesktopSidebar),
          matching: find.text('Now Playing'),
        ),
      );
      await _settle(tester);

      expect(container.read(routerProvider).state.uri.path, '/now-playing');
    });

    testWidgets('does not leave the landing screen looking selected', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      expect(_isSelected(tester, Icons.album), isTrue);

      container.read(routerProvider).go('/now-playing');
      await _settle(tester);

      expect(
        _isSelected(tester, Icons.play_circle),
        isTrue,
        reason: 'Now Playing must show as selected',
      );
      expect(
        _isSelected(tester, Icons.album),
        isFalse,
        reason: 'Albums must not stay lit while Now Playing is open',
      );
    });
  });
}
