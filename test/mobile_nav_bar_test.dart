import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<GoRouter> _pumpMobileApp(WidgetTester tester) async {
  // Mobile width (e.g. 400x800)
  tester.view.physicalSize = const ui.Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [serverListProvider.overrideWith((ref) => _FakeServers())],
  );
  addTearDown(container.dispose);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return router;
}

Finder _navItem(String text) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(text));

void main() {
  testWidgets(
    'mobile layout shows bottom bar with Artists, Albums, Search, and Settings',
    (tester) async {
      final router = await _pumpMobileApp(tester);

      // Sidebar should NOT be rendered on mobile
      expect(find.byType(DesktopSidebar), findsNothing);

      // Bottom NavigationBar should be present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify destinations in bottom bar
      expect(_navItem('Artists'), findsOneWidget);
      expect(_navItem('Albums'), findsOneWidget);
      expect(_navItem('Search'), findsOneWidget);
      expect(_navItem('Settings'), findsOneWidget);
      expect(_navItem('Songs'), findsNothing);

      // Tap Settings
      await tester.tap(_navItem('Settings'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/settings'));

      // Tap Search
      await tester.tap(_navItem('Search'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/search'));

      // Tap Artists
      await tester.tap(_navItem('Artists'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/artists'));

      // Tap Albums
      await tester.tap(_navItem('Albums'));
      await _settle(tester);
      expect(router.state.uri.path, equals('/albums'));
    },
  );
}
