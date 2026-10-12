import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/features/settings/server_connection_screen.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/shared/widgets/app_chrome.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';
import 'package:flax/shared/widgets/offline_mode_toggle.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// No server: AppChrome's start-up library sync would leave timers running.
class _FakeServers extends ServerListNotifier {
  _FakeServers() : super(initialServers: const []);
}

class _FakeReachability extends StateNotifier<ServerReachability>
    implements ServerReachabilityNotifier {
  _FakeReachability() : super(const ServerReachability(isReachable: true));

  @override
  Future<bool> probeServer({bool silent = false, Duration? timeout}) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdates extends StateNotifier<UpdateState>
    implements UpdateNotifier {
  _FakeUpdates() : super(const UpdateState());

  void offer() => state = UpdateState(
    stage: UpdateStage.available,
    channel: UpdateChannel.dev,
    currentVersion: '0.6.1-dev.12',
    latestRelease: ReleaseInfo(
      tagName: 'v0.6.1-dev.13',
      version: '0.6.1-dev.13',
      title: 'flax v0.6.1-dev.13',
      body: '',
      htmlUrl: 'http://example.com',
      publishedAt: DateTime(2026, 10, 11),
      isPrerelease: true,
      assets: const [],
    ),
  );

  @override
  Future<void> checkForUpdates({bool silent = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps [home] inside AppChrome, as MaterialApp's builder wraps every route.
Future<_FakeUpdates> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final updates = _FakeUpdates();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverListProvider.overrideWith((ref) => _FakeServers()),
        serverReachabilityProvider.overrideWith((ref) => _FakeReachability()),
        updateNotifierProvider.overrideWith((ref) => updates),
      ],
      child: MaterialApp(
        builder: (context, child) => AppChrome(child: child!),
        home: home,
      ),
    ),
  );
  // The width is reported after the frame that laid the controls out.
  await tester.pump();
  await tester.pump();
  return updates;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugOverrideIsDesktopPlatform = null);

  double? inset;
  final probe = Builder(
    builder: (context) {
      inset = WindowControlsInset.of(context);
      return const SizedBox.expand();
    },
  );

  // Everything from the Offline toggle's left edge to the window's right one.
  double controls(WidgetTester tester, double width) =>
      width - tester.getRect(find.byType(OfflineModeToggle)).left;

  testWidgets('screens reserve what the controls really take', (tester) async {
    debugOverrideIsDesktopPlatform = true;
    final updates = await _pump(tester, probe);

    expect(inset, moreOrLessEquals(controls(tester, 1200)));

    // The update button comes and goes; the screens follow it.
    final before = inset!;
    updates.offer();
    await tester.pump();
    await tester.pump();
    expect(inset, moreOrLessEquals(controls(tester, 1200)));
    expect(inset! - before, greaterThan(50));
  });

  testWidgets('nothing is reserved off desktop', (tester) async {
    debugOverrideIsDesktopPlatform = false;
    await _pump(tester, probe, width: 390);
    expect(inset, 0);
  });

  testWidgets('a settings title stops short of the controls', (tester) async {
    debugOverrideIsDesktopPlatform = true;
    // Wide enough for the test font's controls; the title would still run
    // under them if nothing were reserved.
    final updates = await _pump(
      tester,
      const ServerConnectionScreen(),
      width: 900,
    );
    updates.offer();
    await tester.pump();
    await tester.pump();

    final controlsLeft = tester.getRect(find.byType(OfflineModeToggle)).left;
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Server Connection'),
    );
    expect(tester.getRect(title).right, lessThanOrEqualTo(controlsLeft));
  });
}
