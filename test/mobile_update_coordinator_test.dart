import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/updater/update_button.dart';
import 'package:flax/features/updater/update_dialog.dart';
import 'package:flax/services/updater/mobile_update_coordinator.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/shared/widgets/layout_metrics.dart';

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

class _StubUpdateNotifier extends StateNotifier<UpdateState>
    implements UpdateNotifier {
  _StubUpdateNotifier(super.state);

  @override
  Future<void> checkForUpdates({bool silent = false}) async {}

  @override
  Future<void> downloadUpdate({bool autoInstall = false}) async {}

  @override
  void cancelDownload() {}

  @override
  Future<void> install() async {}

  @override
  Future<void> setChannel(UpdateChannel channel) async {}

  @override
  Future<void> skipVersion(String version) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mobile layout badges Settings icon when update is available', (
    tester,
  ) async {
    tester.view.physicalSize = const ui.Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final availableState = UpdateState(
      currentVersion: '0.4.6',
      stage: UpdateStage.available,
      installMethod: InstallMethod.androidApk,
      latestRelease: ReleaseInfo(
        version: '0.4.7',
        tagName: 'v0.4.7',
        title: 'v0.4.7',
        body: 'Bug fixes',
        htmlUrl: 'https://github.com/neckbeard-io/flax/releases/tag/v0.4.7',
        publishedAt: DateTime.now(),
        isPrerelease: false,
        assets: [],
      ),
    );

    final container = ProviderContainer(
      overrides: [
        serverListProvider.overrideWith((ref) => _FakeServers()),
        updateNotifierProvider.overrideWith(
          (ref) => _StubUpdateNotifier(availableState),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Mobile layout should NOT have UpdateButton in top bar
    expect(find.byType(UpdateButton), findsNothing);

    // Settings icon in bottom NavigationBar should have a Badge
    final settingsNav = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Badge),
    );
    expect(settingsNav, findsWidgets);
  });

  testWidgets('prompts at launch and on resume together open one dialog', (
    tester,
  ) async {
    debugOverrideIsDesktopPlatform = false;
    addTearDown(() => debugOverrideIsDesktopPlatform = null);

    final availableState = UpdateState(
      currentVersion: '0.4.6',
      stage: UpdateStage.available,
      installMethod: InstallMethod.androidApk,
      latestRelease: ReleaseInfo(
        version: '0.4.7',
        tagName: 'v0.4.7',
        title: 'v0.4.7',
        body: 'Bug fixes',
        htmlUrl: '',
        publishedAt: DateTime(2026, 10, 1),
        isPrerelease: false,
        assets: [],
      ),
    );

    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateNotifierProvider.overrideWith(
            (ref) => _StubUpdateNotifier(availableState),
          ),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Consumer(
            builder: (c, r, _) {
              context = c;
              ref = r;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // A screen attaching to a running process asks from both places at once.
    unawaited(MobileUpdateCoordinator.checkAndPrompt(context, ref));
    unawaited(MobileUpdateCoordinator.checkAndPrompt(context, ref));
    await tester.pumpAndSettle();

    expect(find.byType(UpdateDialog), findsOneWidget);
  });
}
