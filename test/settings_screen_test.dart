import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';

import 'package:flax/app/theme/theme_palette.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/settings/settings_screen.dart';
import 'package:flax/features/settings/theme_settings_screen.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/services/updater/update_models.dart';
import 'package:flax/services/updater/update_provider.dart';
import 'package:flax/shared/widgets/hover_effects.dart';
import 'package:flax/core/providers/platform_offline_policy.dart';

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

    testWidgets('renders Share queue switch tile and toggles state', (
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
        find.text('Share queue between devices'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share queue between devices'), findsOneWidget);
      expect(
        find.text(
          'Queue and position are saved to the server and '
          'picked up by your other devices',
        ),
        findsOneWidget,
      );

      // Tap the switch to disable
      await tester.tap(find.text('Share queue between devices'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "This device's queue is never saved to the server "
          "or replaced by another device's",
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
  group('Android Auto offline option', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      PlatformOfflinePolicy policy,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [platformOfflinePolicyProvider.overrideWithValue(policy)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Offline Mode'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is not offered on desktop', (tester) async {
      await pumpSettings(tester, const MacOsOfflinePolicy());
      expect(find.text('Auto-offline on Android Auto'), findsNothing);
    });

    testWidgets('is offered on Android', (tester) async {
      await pumpSettings(tester, const AndroidOfflinePolicy());
      expect(find.text('Auto-offline on Android Auto'), findsOneWidget);
    });
  });

  // The Theme row once sat beside its title and overflowed a phone in every
  // Latin-script language; tests without the delegates showed "Auto" and fit.
  group('Theme page on a phone', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('fits in ${locale.languageCode}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ThemeSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final segments = find.descendant(
          of: find.byType(SegmentedButton<ThemeModeSetting>),
          matching: find.byType(Text),
        );
        expect(segments, findsNWidgets(3));
        for (final element in segments.evaluate()) {
          expect(
            tester.getRect(find.byWidget(element.widget)).right,
            lessThanOrEqualTo(390),
          );
        }
        final l10n = lookupAppLocalizations(locale);
        expect(
          tester.getRect(find.text(l10n.amoledBlack)).right,
          lessThanOrEqualTo(390),
        );
        for (final palette in ThemePalette.values) {
          final swatch = find.byKey(ValueKey('theme-palette-${palette.name}'));
          await tester.scrollUntilVisible(
            swatch,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.getRect(swatch).right, lessThanOrEqualTo(390));
        }
      });
    }
  });

  testWidgets('Settings keeps theme choices on their own page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      kThemeModePrefKey: 'dark',
      kThemePalettePrefKey: 'nord',
      kAmoledPrefKey: true,
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'settings/theme',
              builder: (context, state) => const ThemeSettingsScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ThemeModeSetting>), findsNothing);
    expect(find.byKey(const ValueKey('theme-palette-nord')), findsNothing);
    expect(find.text('AMOLED Pure Black'), findsNothing);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsScreen), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeModeSetting>), findsOneWidget);
    expect(find.text('AMOLED Pure Black'), findsOneWidget);
  });

  test('the Theme row sums up the choices', () {
    expect(
      themeSummary(
        null,
        mode: ThemeModeSetting.dark,
        palette: ThemePalette.nord,
        amoled: true,
      ),
      'Dark · Nord · AMOLED Pure Black',
    );
    expect(
      themeSummary(
        lookupAppLocalizations(const Locale('de')),
        mode: ThemeModeSetting.light,
        palette: ThemePalette.device,
        amoled: false,
      ),
      'Hell · Gerät',
    );
  });

  group('Share queue switch on a phone', () {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('is translated and fits in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);

        final title = find.text(l10n.shareQueue);
        await tester.scrollUntilVisible(
          title,
          500,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.shareQueueOn), findsOneWidget);

        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final off = find.text(l10n.shareQueueOff);
        expect(off, findsOneWidget);
        expect(tester.getRect(off).right, lessThanOrEqualTo(390));
      });
    }
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
