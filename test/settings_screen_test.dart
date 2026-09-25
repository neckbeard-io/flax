import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Flax',
      packageName: 'io.neckbeard.flax',
      version: '0.5.1',
      buildNumber: '140',
      buildSignature: '',
    );
  });

  group('SettingsScreen & _AboutTile', () {
    testWidgets('renders GitHub repository HoverLink and responds to tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom where About & System lives
      await tester.scrollUntilVisible(
        find.text('About & System'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flax'), findsOneWidget);
      expect(find.text('GPL-3.0-or-later · source at '), findsOneWidget);

      final githubLink = find.byWidgetPredicate(
        (w) => w is HoverLink && w.text == 'github.com/neckbeard-io/flax',
      );
      expect(githubLink, findsOneWidget);

      // Verify tap works cleanly
      await tester.tap(githubLink);
      await tester.pumpAndSettle();
    });

    testWidgets('renders Sync Queue with Server switch tile and toggles state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sync Queue with Server'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync Queue with Server'), findsOneWidget);
      expect(
        find.text(
          'Sync active queue and playback position with the server across devices',
        ),
        findsOneWidget,
      );

      // Tap the switch to disable
      await tester.tap(find.text('Sync Queue with Server'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Keep active queue local to this device; prevents other devices from overwriting playback state',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders Check Now and Update buttons side-by-side on desktop when update is available',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final notifier = _TestUpdateNotifier(
          UpdateState(
            stage: UpdateStage.available,
            channel: UpdateChannel.dev,
            currentVersion: '0.5.7-dev.40',
            latestRelease: ReleaseInfo(
              tagName: 'v0.5.7-dev.41',
              version: '0.5.7-dev.41',
              title: 'flax v0.5.7-dev.41',
              body: 'Improvements',
              htmlUrl: 'http://example.com',
              publishedAt: DateTime.now(),
              isPrerelease: true,
              assets: const [],
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [updateNotifierProvider.overrideWith((ref) => notifier)],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Check for Updates'),
          500,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text('New dev version: v0.5.7-dev.41'), findsOneWidget);
        expect(find.text('Check Now'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);

        // Tap Check Now to trigger recheck
        await tester.tap(find.text('Check Now'));
        await tester.pumpAndSettle();
        expect(notifier.checkCalls, 1);
      },
    );

    testWidgets(
      'renders refresh icon and Update button on mobile without overflow when update is available',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final notifier = _TestUpdateNotifier(
          UpdateState(
            stage: UpdateStage.available,
            channel: UpdateChannel.dev,
            currentVersion: '0.5.7-dev.40',
            latestRelease: ReleaseInfo(
              tagName: 'v0.5.7-dev.41',
              version: '0.5.7-dev.41',
              title: 'flax v0.5.7-dev.41',
              body: 'Improvements',
              htmlUrl: 'http://example.com',
              publishedAt: DateTime.now(),
              isPrerelease: true,
              assets: const [],
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [updateNotifierProvider.overrideWith((ref) => notifier)],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Check for Updates'),
          500,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        expect(find.text('New dev version: v0.5.7-dev.41'), findsOneWidget);
        final refreshButton = find.byTooltip('Check for updates');
        expect(refreshButton, findsOneWidget);
        expect(find.text('Update'), findsOneWidget);

        // Assert controls are within screen bounds
        final rect = tester.getRect(find.text('Update'));
        expect(rect.right, lessThanOrEqualTo(390));

        // Tap refresh icon to trigger recheck
        await tester.tap(refreshButton);
        await tester.pumpAndSettle();
        expect(notifier.checkCalls, 1);
      },
    );
  });
}

class _TestUpdateNotifier extends StateNotifier<UpdateState>
    implements UpdateNotifier {
  _TestUpdateNotifier(super.state);

  int checkCalls = 0;

  @override
  Future<void> checkForUpdates({bool silent = false}) async {
    checkCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
