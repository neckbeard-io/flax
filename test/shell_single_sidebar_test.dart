import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/router.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/shared/widgets/desktop_sidebar.dart';

/// Drives the *real* router rather than a stand-in.
///
/// The bug this guards could not be seen any other way: the now-playing screen
/// wrapped itself in a second ShellScaffold, so opening it left two
/// DesktopSidebars alive at once. Both fed the same FocusNode to a TextField,
/// which a FocusNode cannot survive, and the global "/" shortcut stopped
/// working for the rest of the session. Each screen looked correct on its own.
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

/// Explicit pumps rather than pumpAndSettle: the screens behind these routes
/// fetch from a server that is not there, and one stuck progress indicator
/// would hang the suite instead of failing it. The page transition needs most
/// of a second — checking too early finds the new screen not yet built, which
/// looks exactly like the sidebar not having been duplicated.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const ui.Size(1500, 900);
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

void main() {
  testWidgets('opening now playing does not add a second sidebar', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    expect(find.byType(DesktopSidebar), findsOneWidget);

    router.push('/now-playing');
    await _settle(tester);

    expect(
      find.byType(DesktopSidebar),
      findsOneWidget,
      reason: 'the shell provides the sidebar; the screen must not build one',
    );
  });

  testWidgets('the "/" shortcut can still focus search after now playing', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopSidebar)),
    );

    router.push('/now-playing');
    await _settle(tester);
    router.pop();
    await _settle(tester);

    // What AppChrome's "/" handler does when the key is pressed.
    final node = container.read(searchFieldFocusProvider);
    expect(node.canRequestFocus, isTrue);
    node.requestFocus();
    await tester.pump();

    expect(
      node.hasFocus,
      isTrue,
      reason: '"/" must put the caret in the search field',
    );
  });
}
