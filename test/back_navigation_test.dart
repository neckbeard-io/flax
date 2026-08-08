import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/shared/widgets/app_chrome.dart';

/// Back by mouse button 4 and by trackpad swipe, through the real app.
///
/// Both are wired in AppChrome, which is MaterialApp.router's *builder* and so
/// sits above the InheritedGoRouter — `GoRouter.of(context)` finds nothing
/// there. Only running the real thing catches that.
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
        builder: (context, child) =>
            AppChrome(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  await _settle(tester);
  return router;
}

/// Presses and releases mouse button 4 over the middle of the window.
Future<void> _pressBackButton(WidgetTester tester) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  const at = Offset(750, 450);
  await tester.sendEventToBinding(pointer.down(at, buttons: kBackMouseButton));
  await tester.sendEventToBinding(pointer.up());
  await _settle(tester);
}

/// A two-finger trackpad swipe to the right, in [steps] increments.
Future<void> _swipeBack(
  WidgetTester tester, {
  double dx = 220,
  int steps = 10,
}) async {
  final pointer = TestPointer(2, PointerDeviceKind.trackpad);
  const at = Offset(750, 450);
  await tester.sendEventToBinding(pointer.panZoomStart(at));
  var pan = Offset.zero;
  for (var i = 0; i < steps; i++) {
    pan += Offset(dx / steps, 0);
    await tester.sendEventToBinding(pointer.panZoomUpdate(at, pan: pan));
  }
  await tester.sendEventToBinding(pointer.panZoomEnd());
  await _settle(tester);
}

void main() {
  testWidgets('mouse button 4 goes back', (tester) async {
    final router = await _pumpApp(tester);
    expect(router.state.uri.path, '/albums');

    router.push('/artists');
    await _settle(tester);
    expect(router.state.uri.path, '/artists');

    await _pressBackButton(tester);
    expect(router.state.uri.path, '/albums');
  });

  testWidgets('a trackpad swipe right goes back', (tester) async {
    final router = await _pumpApp(tester);
    router.push('/artists');
    await _settle(tester);

    await _swipeBack(tester);
    expect(router.state.uri.path, '/albums');
  });

  testWidgets('a short swipe does not go back', (tester) async {
    final router = await _pumpApp(tester);
    router.push('/artists');
    await _settle(tester);

    await _swipeBack(tester, dx: 40);
    expect(router.state.uri.path, '/artists');
  });

  testWidgets('going back from the first screen does nothing', (tester) async {
    // Nothing to pop. A browser does nothing here too — and popping the last
    // route would leave the app showing an empty navigator.
    final router = await _pumpApp(tester);
    expect(router.state.uri.path, '/albums');

    await _pressBackButton(tester);
    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/albums');
  });
}
