import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

/// An Android tablet is wide enough for the sidebar but, unlike a desktop
/// window, has a status bar and a navigation bar. The sidebar once ran under
/// both, leaving Settings behind the gesture bar.
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

void main() {
  testWidgets('the sidebar keeps clear of the system bars on a tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 48);
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
    // Explicit pumps: the screen behind the route fetches from a server that
    // is not there, and pumpAndSettle would wait on its progress indicator.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final sidebar = find.byType(DesktopSidebar);
    expect(sidebar, findsOneWidget);
    expect(tester.getRect(sidebar).top, greaterThanOrEqualTo(32));
    final settings = find.descendant(
      of: sidebar,
      matching: find.text('Settings'),
    );
    expect(
      tester.getRect(settings).bottom,
      lessThanOrEqualTo(1280 - 48),
      reason: 'Settings must sit above the navigation bar',
    );
  });
}
